#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 08: Skills Base
# Story 4.1: Configurar skills existentes para a instancia whitelabel
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/auto.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# SKILLS DEFINITIONS
# =============================================================================
readonly SKILL_NAMES=("clickup-ops" "n8n-trigger" "supabase-query" "allos-status" "alerts" "memory")
readonly SKILL_DESCS=(
  "Integrar com ClickUp (tasks)"
  "Disparar workflows N8N"
  "Queries ao Supabase"
  "Health check de servicos"
  "Alertas via Slack webhook"
  "Persistencia de contexto"
)
readonly SKILL_DEPS=(
  "CLICKUP_API_KEY"
  "N8N_API_KEY, N8N_URL"
  "SUPABASE_URL, KEYS"
  "AGENT_GATEWAY_URL"
  "SLACK_WEBHOOK_URL"
  "Nenhuma (local)"
)

# Mascarar key para exibicao segura
mask_key() {
  local key="$1"
  local len=${#key}
  if [[ $len -le 10 ]]; then
    echo "***"
  else
    echo "${key:0:8}***${key: -4}"
  fi
}

# =============================================================================
# STEP 1: LOGGING + STEP INIT (dinamico — sera recalculado apos selecao)
# =============================================================================
log_init "skills"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
# Temporario — sera recalculado apos selecao
step_init 14

# =============================================================================
# STEP 2: LOAD STATE + VERIFICAR DEPENDENCIAS
# =============================================================================
dados
if [[ ! -f "$STATE_DIR/dados_whitelabel" ]]; then
  step_fail "Whitelabel nao encontrado (~/dados_vps/dados_whitelabel ausente)"
  echo "  Execute primeiro: Ferramenta [07] Whitelabel — Identidade do Agente"
  exit 1
fi
nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
if [[ -z "$nome_agente" ]]; then
  step_fail "Nome do agente nao encontrado em dados_whitelabel"
  exit 1
fi

# LLM Router — opcional (WARNING, nao bloqueia)
if [[ -f "$STATE_DIR/dados_llm_router" ]]; then
  step_ok "Estado carregado — agente '${nome_agente}', LLM Router configurado"
else
  step_ok "Estado carregado — agente '${nome_agente}'"
  echo -e "  ${UI_YELLOW}WARNING: LLM Router nao configurado — skills funcionarao mas sem roteamento LLM otimizado${UI_NC}"
fi

# =============================================================================
# STEP 3: CHECK DEPENDENCIES — skills/ existe
# =============================================================================
APPS_DIR="apps/${nome_agente}"
SKILLS_DIR="${APPS_DIR}/skills"

if [[ ! -d "$SKILLS_DIR" ]]; then
  step_fail "Diretorio skills nao encontrado: ${SKILLS_DIR}"
  echo "  Execute a Ferramenta [07] Whitelabel primeiro"
  exit 1
fi

# Ler Install Path do OpenClaw para saber onde fica o .env
OPENCLAW_DIR=$(grep "Install Path:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}')
OPENCLAW_DIR="${OPENCLAW_DIR:-/opt/openclaw}"
step_ok "Dependencias verificadas — skills/ e OpenClaw (${OPENCLAW_DIR})"

# =============================================================================
# STEP 4: EXIBIR TABELA DE SKILLS
# =============================================================================
echo ""
echo -e "${UI_BOLD}=============================================="
echo "  SKILLS DISPONIVEIS"
echo -e "==============================================${UI_NC}"
echo ""
printf "  %-4s %-16s %-34s %s\n" "#" "Skill" "Descricao" "Dependencias"
printf "  %-4s %-16s %-34s %s\n" "---" "---------------" "---------------------------------" "--------------------"
for i in "${!SKILL_NAMES[@]}"; do
  printf "  %-4s %-16s %-34s %s\n" "$((i+1))" "${SKILL_NAMES[$i]}" "${SKILL_DESCS[$i]}" "${SKILL_DEPS[$i]}"
done
echo ""
echo "  Dica: digite 'all' para selecionar todas"
echo ""
echo "=============================================="
echo ""
step_ok "Tabela de skills exibida"

# =============================================================================
# STEP 5: SELECAO DE SKILLS
# =============================================================================
selected_skills=()

while true; do
  input "skills.selecao" "Selecione skills (numeros separados por virgula/espaco, ou 'all'): " selecao_input

  if [[ "$selecao_input" == "all" ]]; then
    selected_skills=("${SKILL_NAMES[@]}")
    break
  fi

  # Parse numeros — aceitar virgula ou espaco como separador
  local_input="${selecao_input//,/ }"
  selected_skills=()
  valid=true

  for num in $local_input; do
    if ! [[ "$num" =~ ^[1-6]$ ]]; then
      echo "  Numero invalido: ${num} (validos: 1-6)"
      valid=false
      break
    fi
    selected_skills+=("${SKILL_NAMES[$((num-1))]}")
  done

  if [[ "$valid" == true && ${#selected_skills[@]} -gt 0 ]]; then
    # Remover duplicatas
    mapfile -t selected_skills < <(printf '%s\n' "${selected_skills[@]}" | sort -u)
    break
  fi

  if [[ "${AUTO_MODE:-false}" == "true" ]]; then
    step_fail "Config invalido: skills.selecao='${selecao_input}'"
    exit 1
  fi

  if [[ ${#selected_skills[@]} -eq 0 ]]; then
    echo "  Selecione pelo menos uma skill."
  fi
done

num_skills=${#selected_skills[@]}
echo ""
echo "  Skills selecionadas (${num_skills}):"
for s in "${selected_skills[@]}"; do
  echo "    - ${s}"
done
step_ok "${num_skills} skills selecionadas"

# Recalcular step_total dinamicamente:
# Steps fixos: load(1) + deps(1) + tabela(1) + selecao(1) + inputs(1) + conferindo(1)
#   + create_dirs(1) + config(1) + index(1) + env(1) + npm(1) + health(1) + save(1) + hints(1) = 14
STEP_TOTAL=14

# =============================================================================
# STEP 6: COLETA DE INPUTS POR SKILL
# =============================================================================

# Variaveis para inputs coletados
declare -A skill_vars

is_skill_selected() {
  local name="$1"
  for s in "${selected_skills[@]}"; do
    [[ "$s" == "$name" ]] && return 0
  done
  return 1
}

while true; do
  echo ""

  # clickup-ops
  if is_skill_selected "clickup-ops"; then
    echo -e "  ${UI_BOLD}--- clickup-ops ---${UI_NC}"
    while true; do
      input "skills.clickup_api_key" "  ClickUp API Key (pk_*): " clickup_api_key --secret --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Obter em: Settings > Apps > API Token"
      if [[ -z "$clickup_api_key" ]]; then
        echo "    ClickUp API Key e obrigatoria."
        continue
      fi
      if ! [[ "$clickup_api_key" =~ ^pk_ ]]; then
        echo "    Formato invalido. ClickUp keys comecam com 'pk_'."
        continue
      fi
      break
    done
    skill_vars[CLICKUP_API_KEY]="$clickup_api_key"

    while true; do
      input "skills.clickup_team_id" "  ClickUp Team ID (numerico): " clickup_team_id --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Obter em: Settings > Spaces > copiar Team ID da URL"
      if [[ -z "$clickup_team_id" ]]; then
        echo "    Team ID e obrigatorio."
        continue
      fi
      if ! [[ "$clickup_team_id" =~ ^[0-9]+$ ]]; then
        echo "    Team ID deve ser numerico."
        continue
      fi
      break
    done
    skill_vars[CLICKUP_TEAM_ID]="$clickup_team_id"
  fi

  # n8n-trigger
  if is_skill_selected "n8n-trigger"; then
    echo -e "  ${UI_BOLD}--- n8n-trigger ---${UI_NC}"
    while true; do
      input "skills.n8n_api_key" "  N8N API Key: " n8n_api_key --secret --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Obter em: Settings > API > Create API Key"
      if [[ -z "$n8n_api_key" ]]; then
        echo "    N8N API Key e obrigatoria."
        continue
      fi
      break
    done
    skill_vars[N8N_API_KEY]="$n8n_api_key"

    while true; do
      input "skills.n8n_webhook_url" "  N8N Webhook URL (https://...): " n8n_webhook_url --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: URL base do webhook N8N"
      if [[ -z "$n8n_webhook_url" ]]; then
        echo "    N8N Webhook URL e obrigatoria."
        continue
      fi
      if ! [[ "$n8n_webhook_url" =~ ^https?:// ]]; then
        echo "    URL deve comecar com http:// ou https://"
        continue
      fi
      break
    done
    skill_vars[N8N_WEBHOOK_URL]="$n8n_webhook_url"
  fi

  # supabase-query
  if is_skill_selected "supabase-query"; then
    echo -e "  ${UI_BOLD}--- supabase-query ---${UI_NC}"
    while true; do
      input "skills.supabase_url" "  Supabase URL (https://*.supabase.co): " supabase_url --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Obter em: Project Settings > API > URL"
      if [[ -z "$supabase_url" ]]; then
        echo "    Supabase URL e obrigatoria."
        continue
      fi
      if ! [[ "$supabase_url" =~ ^https://.+\.supabase\.co$ ]]; then
        echo "    Formato: https://SEU_PROJECT.supabase.co"
        continue
      fi
      break
    done
    skill_vars[SUPABASE_URL]="$supabase_url"

    while true; do
      input "skills.supabase_anon_key" "  Supabase Anon Key (eyJ...): " supabase_anon_key --secret --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Project Settings > API > anon key"
      if [[ -z "$supabase_anon_key" ]]; then
        echo "    Anon Key e obrigatoria."
        continue
      fi
      if ! [[ "$supabase_anon_key" =~ ^eyJ ]]; then
        echo "    Formato invalido. Supabase keys comecam com 'eyJ'."
        continue
      fi
      break
    done
    skill_vars[SUPABASE_ANON_KEY]="$supabase_anon_key"

    while true; do
      input "skills.supabase_service_role_key" "  Supabase Service Role Key (eyJ...): " supabase_service_role_key --secret --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Project Settings > API > service_role key"
      if [[ -z "$supabase_service_role_key" ]]; then
        echo "    Service Role Key e obrigatoria."
        continue
      fi
      if ! [[ "$supabase_service_role_key" =~ ^eyJ ]]; then
        echo "    Formato invalido. Supabase keys comecam com 'eyJ'."
        continue
      fi
      break
    done
    skill_vars[SUPABASE_SERVICE_ROLE_KEY]="$supabase_service_role_key"
  fi

  # allos-status
  if is_skill_selected "allos-status"; then
    echo -e "  ${UI_BOLD}--- allos-status ---${UI_NC}"
    while true; do
      input "skills.agent_gateway_url" "  Agent Gateway URL (http*): " agent_gateway_url --required
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: URL do OpenClaw Gateway — ver dados_openclaw"
      if [[ -z "$agent_gateway_url" ]]; then
        echo "    Gateway URL e obrigatoria."
        continue
      fi
      if ! [[ "$agent_gateway_url" =~ ^https?:// ]]; then
        echo "    URL deve comecar com http:// ou https://"
        continue
      fi
      break
    done
    skill_vars[AGENT_GATEWAY_URL]="$agent_gateway_url"
  fi

  # alerts
  if is_skill_selected "alerts"; then
    echo -e "  ${UI_BOLD}--- alerts ---${UI_NC}"
    while true; do
      input "skills.slack_webhook_url" "  Slack Webhook URL (https://hooks.slack.com/...): " slack_webhook_url --secret
      [[ "${AUTO_MODE:-false}" == "true" ]] && break
      echo "    Hint: Criar em: Slack > Apps > Incoming Webhooks"
      if [[ -z "$slack_webhook_url" ]]; then
        echo "    Slack Webhook URL e obrigatoria."
        continue
      fi
      if ! [[ "$slack_webhook_url" =~ ^https://hooks\.slack\.com/ ]]; then
        echo "    Formato: https://hooks.slack.com/services/..."
        continue
      fi
      break
    done
    skill_vars[SLACK_ALERTS_WEBHOOK_URL]="$slack_webhook_url"
  fi

  # memory — nenhum input
  if is_skill_selected "memory"; then
    echo -e "  ${UI_BOLD}--- memory ---${UI_NC}"
    echo "    Nenhum input necessario (usa filesystem local ~/.clawd/memory/)"
  fi

  # =============================================================================
  # STEP 7: CONFERINDO AS INFO
  # =============================================================================
  echo ""
  conferindo_args=()
  for key in "${!skill_vars[@]}"; do
    conferindo_args+=("${key}=$(mask_key "${skill_vars[$key]}")")
  done
  conferindo_args+=("Skills Selecionadas=$(IFS=', '; echo "${selected_skills[*]}")")

  conferindo_as_info "${conferindo_args[@]}"

  auto_confirm "As informacoes estao corretas? (s/n): " confirma
  if [[ "$confirma" =~ ^[Ss]$ ]]; then
    break
  fi
  # Limpar para recoletar
  declare -A skill_vars
done

step_ok "Inputs coletados e confirmados"

# =============================================================================
# STEP 8: CRIAR SUBDIRETORIOS DE SKILLS SELECIONADAS
# =============================================================================
for skill_name in "${selected_skills[@]}"; do
  skill_dir="${SKILLS_DIR}/${skill_name}"

  if [[ -d "$skill_dir" ]]; then
    step_skip "${skill_name}/ ja existe"
    continue
  fi

  mkdir -p "$skill_dir"

  # Determinar descricao e tier
  case "$skill_name" in
    clickup-ops)
      skill_desc="ClickUp integration — task management, workspace queries"
      skill_tier="standard"
      skill_env_vars="CLICKUP_API_KEY, CLICKUP_TEAM_ID"
      skill_health_cmd='curl -s -o /dev/null -w "%{http_code}" -H "Authorization: ${CLICKUP_API_KEY}" https://api.clickup.com/api/v2/team'
      ;;
    n8n-trigger)
      skill_desc="N8N workflow trigger — dispatch automation workflows"
      skill_tier="standard"
      skill_env_vars="N8N_API_KEY, N8N_WEBHOOK_URL"
      skill_health_cmd='curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: ${N8N_API_KEY}" ${N8N_WEBHOOK_URL}/healthz'
      ;;
    supabase-query)
      skill_desc="Supabase query — database operations via REST API"
      skill_tier="standard"
      skill_env_vars="SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY"
      skill_health_cmd='curl -s -o /dev/null -w "%{http_code}" -H "apikey: ${SUPABASE_ANON_KEY}" ${SUPABASE_URL}/rest/v1/'
      ;;
    allos-status)
      skill_desc="Service health check — monitor OpenClaw gateway and services"
      skill_tier="budget"
      skill_env_vars="AGENT_GATEWAY_URL"
      skill_health_cmd='curl -s -o /dev/null -w "%{http_code}" ${AGENT_GATEWAY_URL}/health'
      ;;
    alerts)
      skill_desc="Slack alerts — send notifications via webhook"
      skill_tier="budget"
      skill_env_vars="SLACK_ALERTS_WEBHOOK_URL"
      skill_health_cmd='curl -s -X POST ${SLACK_ALERTS_WEBHOOK_URL} -d '"'"'{"text":"health check"}'"'"''
      ;;
    memory)
      skill_desc="Context persistence — local filesystem memory"
      skill_tier="budget"
      skill_env_vars="None (uses ~/.clawd/memory/)"
      skill_health_cmd=""
      ;;
  esac

  # index.js — funcional com health check real
  cat > "${skill_dir}/index.js" << JSEOF
// Skill: ${skill_name}
// Generated by Legendsclaw Deployer (Story 4.1)

const config = require('../config');

module.exports = {
  name: '${skill_name}',
  description: '${skill_desc}',
  tier: '${skill_tier}',

  handler: async (input) => {
    // TODO: Implement ${skill_name} handler
    throw new Error('${skill_name} handler not implemented');
  },

  health: async () => {
    try {
JSEOF

  # Health check body depends on skill
  case "$skill_name" in
    clickup-ops)
      cat >> "${skill_dir}/index.js" << 'JSEOF'
      const https = require('https');
      return new Promise((resolve) => {
        const req = https.get('https://api.clickup.com/api/v2/team', {
          headers: { 'Authorization': process.env.CLICKUP_API_KEY || '' }
        }, (res) => {
          resolve({ ok: res.statusCode === 200, status: res.statusCode });
        });
        req.on('error', (err) => resolve({ ok: false, error: err.message }));
        req.setTimeout(5000, () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
      });
JSEOF
      ;;
    n8n-trigger)
      cat >> "${skill_dir}/index.js" << 'JSEOF'
      const https = require('https');
      const url = new URL((process.env.N8N_WEBHOOK_URL || '') + '/healthz');
      const mod = url.protocol === 'https:' ? require('https') : require('http');
      return new Promise((resolve) => {
        const req = mod.get(url, {
          headers: { 'X-N8N-API-KEY': process.env.N8N_API_KEY || '' }
        }, (res) => {
          resolve({ ok: res.statusCode === 200, status: res.statusCode });
        });
        req.on('error', (err) => resolve({ ok: false, error: err.message }));
        req.setTimeout(5000, () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
      });
JSEOF
      ;;
    supabase-query)
      cat >> "${skill_dir}/index.js" << 'JSEOF'
      const https = require('https');
      const url = new URL((process.env.SUPABASE_URL || '') + '/rest/v1/');
      return new Promise((resolve) => {
        const req = https.get(url, {
          headers: { 'apikey': process.env.SUPABASE_ANON_KEY || '' }
        }, (res) => {
          resolve({ ok: res.statusCode === 200, status: res.statusCode });
        });
        req.on('error', (err) => resolve({ ok: false, error: err.message }));
        req.setTimeout(5000, () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
      });
JSEOF
      ;;
    allos-status)
      cat >> "${skill_dir}/index.js" << 'JSEOF'
      const url = new URL((process.env.AGENT_GATEWAY_URL || 'http://localhost:18789') + '/health');
      const mod = url.protocol === 'https:' ? require('https') : require('http');
      return new Promise((resolve) => {
        const req = mod.get(url, (res) => {
          resolve({ ok: res.statusCode === 200, status: res.statusCode });
        });
        req.on('error', (err) => resolve({ ok: false, error: err.message }));
        req.setTimeout(5000, () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
      });
JSEOF
      ;;
    alerts)
      cat >> "${skill_dir}/index.js" << 'JSEOF'
      const https = require('https');
      const url = new URL(process.env.SLACK_ALERTS_WEBHOOK_URL || '');
      const data = JSON.stringify({ text: 'health check' });
      return new Promise((resolve) => {
        const req = https.request(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Content-Length': data.length }
        }, (res) => {
          let body = '';
          res.on('data', (d) => { body += d; });
          res.on('end', () => resolve({ ok: body === 'ok', status: res.statusCode }));
        });
        req.on('error', (err) => resolve({ ok: false, error: err.message }));
        req.setTimeout(5000, () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
        req.write(data);
        req.end();
      });
JSEOF
      ;;
    memory)
      cat >> "${skill_dir}/index.js" << 'JSEOF'
      const fs = require('fs');
      const path = require('path');
      const memDir = path.join(process.env.HOME || '/root', '.clawd', 'memory');
      if (!fs.existsSync(memDir)) {
        fs.mkdirSync(memDir, { recursive: true });
      }
      return { ok: fs.existsSync(memDir), path: memDir };
JSEOF
      ;;
  esac

  # Close health function and module
  cat >> "${skill_dir}/index.js" << 'JSEOF'
    } catch (err) {
      return { ok: false, error: err.message };
    }
  },
};
JSEOF

  # SKILL.md
  cat > "${skill_dir}/SKILL.md" << MDEOF
# ${skill_name}

## Description
${skill_desc}

## Environment Variables
${skill_env_vars}

## LLM Tier
${skill_tier}

## Usage
\`\`\`javascript
const skill = require('./${skill_name}');
const result = await skill.handler({ /* input */ });
const health = await skill.health();
\`\`\`
MDEOF

done

step_ok "${num_skills} subdiretorios de skills criados/verificados"

# =============================================================================
# STEP 9: ATUALIZAR CONFIG.JS
# =============================================================================
CONFIG_FILE="${SKILLS_DIR}/config.js"

if [[ -f "$CONFIG_FILE" ]]; then
  cp -p "$CONFIG_FILE" "${CONFIG_FILE}.bak"
fi

# Ler identidade existente do config.js backup
existing_agent_name=$(grep "AGENT_NAME:" "${CONFIG_FILE}.bak" 2>/dev/null | sed "s/.*'\(.*\)'.*/\1/" || echo "$nome_agente")
existing_display_name=$(grep "DISPLAY_NAME:" "${CONFIG_FILE}.bak" 2>/dev/null | sed "s/.*'\(.*\)'.*/\1/" || echo "$nome_agente")
existing_icon=$(grep "ICON:" "${CONFIG_FILE}.bak" 2>/dev/null | sed "s/.*'\(.*\)'.*/\1/" || echo "🤖")
existing_language=$(grep "LANGUAGE:" "${CONFIG_FILE}.bak" 2>/dev/null | sed "s/.*'\(.*\)'.*/\1/" || echo "pt-BR")

cat > "$CONFIG_FILE" << JSEOF
// ${existing_display_name} — Skills Configuration
// Updated by Legendsclaw Deployer (Story 4.1)
// Date: $(date '+%Y-%m-%d %H:%M:%S')
//
// Credentials loaded from environment variables

module.exports = {
  // Agent Identity
  AGENT_NAME: '${existing_agent_name}',
  DISPLAY_NAME: '${existing_display_name}',
  ICON: '${existing_icon}',
  LANGUAGE: '${existing_language}',

JSEOF

# Adicionar secoes por skill selecionada
if is_skill_selected "clickup-ops"; then
  cat >> "$CONFIG_FILE" << 'JSEOF'
  // ClickUp
  CLICKUP_API_KEY: process.env.CLICKUP_API_KEY,
  CLICKUP_TEAM_ID: process.env.CLICKUP_TEAM_ID,

JSEOF
fi

if is_skill_selected "n8n-trigger"; then
  cat >> "$CONFIG_FILE" << 'JSEOF'
  // N8N
  N8N_API_KEY: process.env.N8N_API_KEY,
  N8N_WEBHOOK_BASE: process.env.N8N_WEBHOOK_URL,
  WORKFLOWS: {},

JSEOF
fi

if is_skill_selected "supabase-query"; then
  cat >> "$CONFIG_FILE" << 'JSEOF'
  // Supabase
  SUPABASE_URL: process.env.SUPABASE_URL,
  SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,

JSEOF
fi

if is_skill_selected "allos-status"; then
  cat >> "$CONFIG_FILE" << 'JSEOF'
  // Gateway
  AGENT_GATEWAY_URL: process.env.AGENT_GATEWAY_URL,

JSEOF
fi

if is_skill_selected "alerts"; then
  cat >> "$CONFIG_FILE" << 'JSEOF'
  // Alerts
  SLACK_ALERTS_WEBHOOK_URL: process.env.SLACK_ALERTS_WEBHOOK_URL,
  SLACK_CHANNEL: process.env.SLACK_CHANNEL || '#alertas',

JSEOF
fi

if is_skill_selected "memory"; then
  cat >> "$CONFIG_FILE" << JSEOF
  // Memory
  MEMORY_BASE_PATH: process.env.MEMORY_PATH || '~/.${nome_agente}/',

JSEOF
fi

# Secoes preservadas (nao-skill)
cat >> "$CONFIG_FILE" << 'JSEOF'
  // Services
  SERVICES: {
    API: process.env.API_URL,
    N8N: process.env.N8N_URL,
    WORKER: process.env.WORKER_URL,
  },

  // WhatsApp
  WHATSAPP_JID: process.env.WHATSAPP_JID,
};
JSEOF

step_ok "config.js atualizado com ${num_skills} skills (backup em .bak)"

# =============================================================================
# STEP 10: ATUALIZAR INDEX.JS
# =============================================================================
INDEX_FILE="${SKILLS_DIR}/index.js"

if [[ -f "$INDEX_FILE" ]]; then
  cp -p "$INDEX_FILE" "${INDEX_FILE}.bak"
fi

{
  echo "// Skills Registry for ${existing_display_name}"
  echo "// Updated by Legendsclaw Deployer (Story 4.1)"
  echo "// Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # Requires
  for skill_name in "${selected_skills[@]}"; do
    var_name=$(echo "$skill_name" | sed 's/-/_/g')
    echo "const ${var_name} = require('./${skill_name}');"
  done

  echo ""
  echo "const skills = ["

  for skill_name in "${selected_skills[@]}"; do
    var_name=$(echo "$skill_name" | sed 's/-/_/g')
    echo "  ${var_name},"
  done

  echo "];"
  echo ""
  echo "module.exports = {"
  echo "  skills,"
  echo "  getSkill: (name) => skills.find((s) => s.name === name) || null,"
  echo "};"
} > "$INDEX_FILE"

step_ok "index.js atualizado — ${num_skills} skills registradas (backup em .bak)"

# =============================================================================
# STEP 11: POPULAR .ENV COM KEYS DAS SKILLS
# =============================================================================
ENV_FILE="${OPENCLAW_DIR}/.env"

upsert_skills_env_block() {
  local env_file="$1"

  if [[ -f "$env_file" ]]; then
    # Remover bloco Skills Config existente
    local temp_file
    temp_file=$(mktemp)
    sed '/^# Skills Config$/,/^$/d' "$env_file" > "$temp_file" 2>/dev/null || cp "$env_file" "$temp_file"
    # Remover variaveis individuais se existirem fora do bloco
    for var_name in CLICKUP_API_KEY CLICKUP_TEAM_ID N8N_API_KEY N8N_WEBHOOK_URL SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY AGENT_GATEWAY_URL SLACK_ALERTS_WEBHOOK_URL; do
      sed -i "/^${var_name}=/d" "$temp_file" 2>/dev/null || true
    done
    cp "$temp_file" "$env_file"
    rm -f "$temp_file"
  fi

  # Append novo bloco — somente skills selecionadas
  {
    echo ""
    echo "# Skills Config"

    if is_skill_selected "clickup-ops"; then
      echo "CLICKUP_API_KEY=${skill_vars[CLICKUP_API_KEY]:-}"
      echo "CLICKUP_TEAM_ID=${skill_vars[CLICKUP_TEAM_ID]:-}"
    fi

    if is_skill_selected "n8n-trigger"; then
      echo "N8N_API_KEY=${skill_vars[N8N_API_KEY]:-}"
      echo "N8N_WEBHOOK_URL=${skill_vars[N8N_WEBHOOK_URL]:-}"
    fi

    if is_skill_selected "supabase-query"; then
      echo "SUPABASE_URL=${skill_vars[SUPABASE_URL]:-}"
      echo "SUPABASE_ANON_KEY=${skill_vars[SUPABASE_ANON_KEY]:-}"
      echo "SUPABASE_SERVICE_ROLE_KEY=${skill_vars[SUPABASE_SERVICE_ROLE_KEY]:-}"
    fi

    if is_skill_selected "allos-status"; then
      echo "AGENT_GATEWAY_URL=${skill_vars[AGENT_GATEWAY_URL]:-}"
    fi

    if is_skill_selected "alerts"; then
      echo "SLACK_ALERTS_WEBHOOK_URL=${skill_vars[SLACK_ALERTS_WEBHOOK_URL]:-}"
    fi

    echo ""
  } >> "$env_file"
}

mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"
upsert_skills_env_block "$ENV_FILE"
chmod 600 "$ENV_FILE"

step_ok ".env atualizado com keys das skills em ${OPENCLAW_DIR}"

# =============================================================================
# STEP 12: NPM INSTALL
# =============================================================================
if [[ -f "${SKILLS_DIR}/package.json" ]]; then
  echo ""
  echo "  Executando npm install..."
  if (cd "$SKILLS_DIR" && npm install --production 2>&1); then
    step_ok "npm install concluido"
  else
    step_fail "npm install falhou (nao-bloqueante)"
  fi
else
  step_skip "package.json nao encontrado"
fi

# =============================================================================
# STEP 13: HEALTH CHECK POR SKILL
# =============================================================================
echo ""
echo "  Testando health check por skill..."
health_ok=0
health_total=0

for skill_name in "${selected_skills[@]}"; do
  health_total=$((health_total + 1))

  case "$skill_name" in
    clickup-ops)
      response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "Authorization: ${skill_vars[CLICKUP_API_KEY]:-}" \
        https://api.clickup.com/api/v2/team 2>/dev/null) || response="000"
      if [[ "$response" == "200" ]]; then
        echo -e "    ${UI_GREEN}OK${UI_NC} clickup-ops (HTTP ${response})"
        health_ok=$((health_ok + 1))
      else
        echo -e "    ${UI_RED}FAIL${UI_NC} clickup-ops (HTTP ${response})"
      fi
      ;;
    n8n-trigger)
      response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "X-N8N-API-KEY: ${skill_vars[N8N_API_KEY]:-}" \
        "${skill_vars[N8N_WEBHOOK_URL]:-http://localhost}/healthz" 2>/dev/null) || response="000"
      if [[ "$response" == "200" ]]; then
        echo -e "    ${UI_GREEN}OK${UI_NC} n8n-trigger (HTTP ${response})"
        health_ok=$((health_ok + 1))
      else
        echo -e "    ${UI_RED}FAIL${UI_NC} n8n-trigger (HTTP ${response})"
      fi
      ;;
    supabase-query)
      response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "apikey: ${skill_vars[SUPABASE_ANON_KEY]:-}" \
        "${skill_vars[SUPABASE_URL]:-http://localhost}/rest/v1/" 2>/dev/null) || response="000"
      if [[ "$response" == "200" ]]; then
        echo -e "    ${UI_GREEN}OK${UI_NC} supabase-query (HTTP ${response})"
        health_ok=$((health_ok + 1))
      else
        echo -e "    ${UI_RED}FAIL${UI_NC} supabase-query (HTTP ${response})"
      fi
      ;;
    allos-status)
      response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        "${skill_vars[AGENT_GATEWAY_URL]:-http://localhost:18789}/health" 2>/dev/null) || response="000"
      if [[ "$response" == "200" ]]; then
        echo -e "    ${UI_GREEN}OK${UI_NC} allos-status (HTTP ${response})"
        health_ok=$((health_ok + 1))
      else
        echo -e "    ${UI_RED}FAIL${UI_NC} allos-status (HTTP ${response})"
      fi
      ;;
    alerts)
      slack_body=$(curl -s --max-time 10 \
        -X POST "${skill_vars[SLACK_ALERTS_WEBHOOK_URL]:-http://localhost}" \
        -d '{"text":"Legendsclaw health check"}' 2>/dev/null) || slack_body=""
      if [[ "$slack_body" == "ok" ]]; then
        echo -e "    ${UI_GREEN}OK${UI_NC} alerts (Slack: ok)"
        health_ok=$((health_ok + 1))
      else
        echo -e "    ${UI_RED}FAIL${UI_NC} alerts (Slack: ${slack_body:-timeout})"
      fi
      ;;
    memory)
      memory_dir="$HOME/.clawd/memory"
      mkdir -p "$memory_dir" 2>/dev/null || true
      if [[ -d "$memory_dir" ]]; then
        echo -e "    ${UI_GREEN}OK${UI_NC} memory (${memory_dir})"
        health_ok=$((health_ok + 1))
      else
        echo -e "    ${UI_RED}FAIL${UI_NC} memory (nao conseguiu criar ${memory_dir})"
      fi
      ;;
  esac
done

echo ""
echo "  Health check: ${health_ok}/${health_total} OK"
step_ok "Health check concluido (${health_ok}/${health_total} OK)"

# =============================================================================
# STEP 14: SAVE STATE + RESUMO + HINTS
# =============================================================================
mkdir -p "$STATE_DIR"

# Gerar lista de skills e status
skills_list=$(IFS=', '; echo "${selected_skills[*]}")

cat > "$STATE_DIR/dados_skills" << EOF
Agente: ${nome_agente}
Skills Ativas: ${skills_list}
Config Path: ${CONFIG_FILE}
Index Path: ${INDEX_FILE}
ClickUp: $(is_skill_selected "clickup-ops" && echo "configurado" || echo "nao configurado")
N8N: $(is_skill_selected "n8n-trigger" && echo "configurado" || echo "nao configurado")
Supabase: $(is_skill_selected "supabase-query" && echo "configurado" || echo "nao configurado")
Status: $(is_skill_selected "allos-status" && echo "configurado" || echo "nao configurado")
Alerts: $(is_skill_selected "alerts" && echo "configurado" || echo "nao configurado")
Memory: $(is_skill_selected "memory" && echo "configurado" || echo "nao configurado")
Health Check: ${health_ok}/${health_total} OK
Env File: ${ENV_FILE}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_skills"

step_ok "Estado salvo em ~/dados_vps/dados_skills"

# Resumo final
resumo_final

echo -e "${UI_BOLD}  Skills Base — ${nome_agente}${UI_NC}"
echo ""
echo "  Agente:        ${nome_agente}"
echo "  Skills (${num_skills}):  ${skills_list}"
echo "  Health:        ${health_ok}/${health_total} OK"
echo ""
echo "  Config:        ${CONFIG_FILE}"
echo "  Index:         ${INDEX_FILE}"
echo "  Env:           ${ENV_FILE}"
echo "  Estado:        ~/dados_vps/dados_skills"
echo "  Log:           ${LOG_FILE}"
echo ""

hint_skills "${nome_agente}" "${selected_skills[@]}"

log_finish
