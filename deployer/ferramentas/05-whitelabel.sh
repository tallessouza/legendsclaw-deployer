#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 05: Whitelabel Identity
# Story 3.1: Criar identidade do agente (nome, persona, estrutura apps/)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"
source "${LIB_DIR}/auto.sh"

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "whitelabel"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init 8

# =============================================================================
# STEP 2: LOAD STATE + VERIFICAR DEPENDENCIA OPENCLAW
# =============================================================================
dados
if [[ ! -f "$STATE_DIR/dados_openclaw" ]]; then
  step_fail "OpenClaw nao encontrado (~/dados_vps/dados_openclaw ausente)"
  echo "  Execute primeiro: Ferramenta [05] OpenClaw Gateway"
  exit 1
fi
step_ok "Estado carregado — dados_openclaw encontrado"

# =============================================================================
# STEP 3: INPUT COLLECTION — nome, display name, icone, persona, idioma
# =============================================================================
while true; do
  echo ""

  # Nome do agente (kebab-case)
  while true; do
    input "whitelabel.nome_agente" "Nome tecnico do agente (kebab-case, ex: jarvis, atlas): " nome_agente --required
    if [[ -z "$nome_agente" ]]; then
      echo "  Nome nao pode ser vazio."
      continue
    fi
    if ! [[ "$nome_agente" =~ ^[a-z][a-z0-9-]*$ ]]; then
      echo "  Nome invalido. Use apenas lowercase, numeros e hifen (kebab-case)."
      echo "  Exemplos validos: jarvis, atlas, meu-agente"
      continue
    fi
    break
  done

  # Display name
  input "whitelabel.display_name" "Display name (ex: Jarvis, Atlas): " display_name --required
  if [[ -z "$display_name" ]]; then
    display_name="${nome_agente^}"
  fi

  # Icone
  input "whitelabel.icone" "Icone do agente (emoji, default: 🤖): " icone_input --default=🤖
  icone="${icone_input:-🤖}"

  # Persona/estilo
  input "whitelabel.persona" "Persona/estilo (ex: Pratico, eficiente, orientado a resultados): " persona_estilo --required
  if [[ -z "$persona_estilo" ]]; then
    persona_estilo="Pratico, eficiente, orientado a resultados"
  fi

  # Idioma
  input "whitelabel.idioma" "Idioma principal (default: pt-BR): " idioma_input --default=pt-BR
  idioma="${idioma_input:-pt-BR}"

  # Conferindo as info
  conferindo_as_info \
    "Nome Agente=${nome_agente}" \
    "Display Name=${display_name}" \
    "Icone=${icone}" \
    "Persona=${persona_estilo}" \
    "Idioma=${idioma}"

  auto_confirm "As informacoes estao corretas? (s/n): " confirma
  if [[ "$confirma" =~ ^[Ss]$ ]]; then
    break
  fi
done

step_ok "Inputs coletados"

# =============================================================================
# STEP 4: CHECK EXISTING — verificar se agente ja existe
# =============================================================================
DEPLOYER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPS_DIR="${DEPLOYER_ROOT}/apps/${nome_agente}"
if [[ -d "$APPS_DIR" ]]; then
  step_fail "Agente '${nome_agente}' ja existe em ${APPS_DIR}"
  echo "  Use outro nome ou remova manualmente: rm -rf ${APPS_DIR}"
  exit 1
fi
step_ok "Nome '${nome_agente}' disponivel"

# =============================================================================
# STEP 5: CREATE STRUCTURE — diretorios e arquivos placeholder
# =============================================================================

# Diretorios
mkdir -p "${APPS_DIR}/config"
mkdir -p "${APPS_DIR}/hooks/session-digest"
mkdir -p "${APPS_DIR}/lib"
mkdir -p "${APPS_DIR}/skills/lib"

# config/llm-router-config.yaml
cat > "${APPS_DIR}/config/llm-router-config.yaml" << 'YAML_EOF'
# LLM Router Configuration
# Story 3.2 will configure API keys and test routing

defaults:
  tier: standard
  max_retries: 3
  timeout_ms: 30000

tiers:
  budget:
    models:
      - id: deepseek/deepseek-chat
        provider: openrouter
    max_cost_per_request: 0.01
    use_for: status, health checks, queries simples

  standard:
    models:
      - id: anthropic/claude-3.5-haiku
        provider: openrouter
    max_cost_per_request: 0.05
    use_for: operacoes ClickUp, N8N triggers, analises

  premium:
    models:
      - id: claude-sonnet-4-6
        provider: anthropic
    max_cost_per_request: 0.20
    use_for: decisoes complexas, analise de dados

skill_mapping:
  status: budget
  clickup-ops: standard
  n8n-trigger: standard
  supabase-query: standard
  memory: budget
  alerts: budget
YAML_EOF

# hooks/session-digest/ — 7 placeholder files
for file in handler.js index.js ingester.js scorer.js templates.js types.js; do
  cat > "${APPS_DIR}/hooks/session-digest/${file}" << EOF
// TODO: Implement session-digest ${file%.js}
// See: docs/architecture/legendsclaw-architecture.md#7
module.exports = {};
EOF
done

cat > "${APPS_DIR}/hooks/session-digest/hook.yml" << 'EOF'
# Session Digest Hook Configuration
# TODO: Configure hook triggers and behavior
name: session-digest
trigger: SessionEnd
enabled: false
EOF

# lib/ — 4 placeholder files
for file in llm-router.js metrics-alerts.js metrics-collector.js metrics-queries.js; do
  cat > "${APPS_DIR}/lib/${file}" << EOF
// TODO: Implement ${file%.js}
// See: docs/architecture/legendsclaw-architecture.md#7
module.exports = {};
EOF
done

# skills/index.js
cat > "${APPS_DIR}/skills/index.js" << EOF
// Skills Registry for ${display_name}
// Register active skills here
module.exports = {
  skills: [],
  getSkill: (name) => null,
};
EOF

# skills/package.json
cat > "${APPS_DIR}/skills/package.json" << EOF
{
  "name": "@legendsclaw/${nome_agente}-skills",
  "version": "0.1.0",
  "description": "Skills for ${display_name} agent",
  "main": "index.js",
  "dependencies": {}
}
EOF

# skills/lib/blocklist.yaml
cat > "${APPS_DIR}/skills/lib/blocklist.yaml" << 'EOF'
# Command Safety — Blocked Commands
# Layer 1 security: prevent dangerous operations

blocked_commands:
  - rm -rf /
  - rm -rf /*
  - sudo su
  - dd if=
  - mkfs
  - iptables -F
  - shutdown
  - reboot
  - kill -9 1

validation:
  mode: regex
  log_blocked: true
  whitelist_per_skill: true
EOF

# skills/lib/command-safety.js
cat > "${APPS_DIR}/skills/lib/command-safety.js" << 'EOF'
// TODO: Implement command safety validation
// See: docs/architecture/legendsclaw-architecture.md#10
module.exports = {
  validate: (command) => ({ safe: true, reason: null }),
};
EOF

# skills/lib/errors.js
cat > "${APPS_DIR}/skills/lib/errors.js" << 'EOF'
// TODO: Implement error handling utilities
module.exports = {
  SkillError: class SkillError extends Error {
    constructor(message, code) {
      super(message);
      this.code = code;
    }
  },
};
EOF

# skills/lib/logger.js
cat > "${APPS_DIR}/skills/lib/logger.js" << 'EOF'
// TODO: Implement skill logger
module.exports = {
  log: (level, message) => console.log(`[${level}] ${message}`),
  info: (message) => console.log(`[INFO] ${message}`),
  error: (message) => console.error(`[ERROR] ${message}`),
};
EOF

step_ok "Estrutura apps/${nome_agente}/ criada (config, hooks, lib, skills)"

# =============================================================================
# STEP 6: GENERATE CONFIG.JS — placeholders para servicos
# =============================================================================
cat > "${APPS_DIR}/skills/config.js" << EOF
// ${display_name} — Skills Configuration
// Generated by Legendsclaw Deployer (Story 3.1)
//
// IMPORTANT: Replace placeholder values with your actual credentials
// Use environment variables for sensitive data

module.exports = {
  // Agent Identity
  AGENT_NAME: '${nome_agente}',
  DISPLAY_NAME: '${display_name}',
  ICON: '${icone}',
  LANGUAGE: '${idioma}',

  // ClickUp
  CLICKUP_TEAM_ID: process.env.CLICKUP_TEAM_ID || 'SEU_TEAM_ID',

  // N8N Webhooks
  N8N_WEBHOOK_BASE: process.env.N8N_WEBHOOK_URL || 'https://SEU-N8N.exemplo.com',
  WORKFLOWS: {
    // Map your workflow IDs here
    // 'workflow-name': 'WEBHOOK_ID',
  },

  // Supabase
  SUPABASE_URL: process.env.SUPABASE_URL || 'https://SEU_PROJECT.supabase.co',

  // Services — replace with your domains
  SERVICES: {
    API: process.env.API_URL || 'https://api.SEU-DOMINIO.com',
    N8N: process.env.N8N_URL || 'https://n8n.SEU-DOMINIO.com',
    WORKER: process.env.WORKER_URL || 'https://worker.SEU-DOMINIO.com',
  },

  // WhatsApp
  WHATSAPP_JID: process.env.WHATSAPP_JID || 'SEU_NUMERO@s.whatsapp.net',

  // Slack
  SLACK_CHANNEL: process.env.SLACK_CHANNEL || '#seu-canal-alertas',

  // Memory
  MEMORY_BASE_PATH: process.env.MEMORY_PATH || '~/.${nome_agente}/',
};
EOF

step_ok "config.js gerado com placeholders"

# =============================================================================
# STEP 7: SAVE STATE — dados_whitelabel
# =============================================================================
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/dados_whitelabel" << EOF
Agente: ${nome_agente}
Display Name: ${display_name}
Icone: ${icone}
Persona: ${persona_estilo}
Idioma: ${idioma}
Apps Path: apps/${nome_agente}
Config: apps/${nome_agente}/skills/config.js
Data Criacao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_whitelabel"

step_ok "Estado salvo em ~/dados_vps/dados_whitelabel"

# =============================================================================
# STEP 8: RESUMO + HINTS
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  Whitelabel Identity — ${display_name}${UI_NC}"
echo ""
echo "  Agente:      ${nome_agente}"
echo "  Display:     ${display_name} ${icone}"
echo "  Persona:     ${persona_estilo}"
echo "  Idioma:      ${idioma}"
echo ""
echo "  Arquivos criados:"
echo "    apps/${nome_agente}/config/llm-router-config.yaml"
echo "    apps/${nome_agente}/hooks/session-digest/ (7 arquivos)"
echo "    apps/${nome_agente}/lib/ (4 arquivos)"
echo "    apps/${nome_agente}/skills/config.js"
echo "    apps/${nome_agente}/skills/index.js"
echo "    apps/${nome_agente}/skills/package.json"
echo "    apps/${nome_agente}/skills/lib/ (4 arquivos)"
echo ""
echo "  Estado:      ~/dados_vps/dados_whitelabel"
echo "  Log:         ${LOG_FILE}"
echo ""

hint_whitelabel "${nome_agente}"

# Reload gateway se estiver rodando
if reload_gateway; then
  echo -e "  ${UI_GREEN}Gateway reiniciado — mudancas aplicadas${UI_NC}"
elif [[ $? -eq 2 ]]; then
  echo "  INFO: Gateway nao encontrado (sera aplicado ao iniciar)"
fi

log_finish
