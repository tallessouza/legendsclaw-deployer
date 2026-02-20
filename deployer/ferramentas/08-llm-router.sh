#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 08: LLM Router
# Story 3.2: Configurar tiers de custo e API keys
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "llm-router"
setup_trap
step_init 10

# =============================================================================
# STEP 2: LOAD STATE + VERIFICAR DEPENDENCIA WHITELABEL
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
step_ok "Estado carregado — agente '${nome_agente}' encontrado"

# =============================================================================
# STEP 3: CHECK DEPENDENCIES — llm-router-config.yaml existe
# =============================================================================
CONFIG_FILE="apps/${nome_agente}/config/llm-router-config.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
  step_fail "Config LLM Router nao encontrado: ${CONFIG_FILE}"
  echo "  Execute a Ferramenta [07] Whitelabel primeiro"
  exit 1
fi

# Ler Install Path do OpenClaw para saber onde fica o .env
OPENCLAW_DIR=$(grep "Install Path:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}')
OPENCLAW_DIR="${OPENCLAW_DIR:-/opt/openclaw}"
step_ok "Dependencias verificadas — config e OpenClaw (${OPENCLAW_DIR})"

# =============================================================================
# STEP 4: EXIBIR TABELA DE CUSTOS
# =============================================================================
echo ""
echo -e "${UI_BOLD:-\033[1m}=============================================="
echo "  LLM ROUTER — TABELA DE CUSTOS"
echo -e "==============================================${UI_NC:-\033[0m}"
echo ""
echo "  Tier       Modelo                 Custo/req    Custo/1M tok  Uso"
echo "  --------   --------------------   ----------   -----------   -------------------"
echo "  budget     deepseek-chat          ~\$0.01       ~\$0.14       status, health"
echo "  standard   claude-3.5-haiku       ~\$0.05       ~\$0.80       ClickUp, N8N"
echo "  premium    claude-sonnet-4-6      ~\$0.20       ~\$15.00      decisoes complexas"
echo ""
echo "=============================================="
echo ""
step_ok "Tabela de custos exibida"

# =============================================================================
# STEP 5: INPUT COLLECTION — API keys + tier padrao
# =============================================================================

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

while true; do
  echo ""

  # OpenRouter key (obrigatorio)
  while true; do
    read -rp "OpenRouter API Key (sk-or-v1-...): " openrouter_key
    if [[ -z "$openrouter_key" ]]; then
      echo "  OpenRouter key e obrigatoria."
      continue
    fi
    if [[ ${#openrouter_key} -lt 40 ]]; then
      echo "  Key muito curta (minimo 40 caracteres)."
      continue
    fi
    if ! [[ "$openrouter_key" =~ ^sk-or- ]]; then
      echo "  Formato invalido. OpenRouter keys comecam com 'sk-or-'."
      continue
    fi
    break
  done

  # Anthropic key (obrigatorio)
  while true; do
    read -rp "Anthropic API Key (sk-ant-...): " anthropic_key
    if [[ -z "$anthropic_key" ]]; then
      echo "  Anthropic key e obrigatoria."
      continue
    fi
    if [[ ${#anthropic_key} -lt 50 ]]; then
      echo "  Key muito curta (minimo 50 caracteres)."
      continue
    fi
    if ! [[ "$anthropic_key" =~ ^sk-ant- ]]; then
      echo "  Formato invalido. Anthropic keys comecam com 'sk-ant-'."
      continue
    fi
    break
  done

  # DeepSeek key (opcional)
  read -rp "DeepSeek API Key (opcional, Enter para pular): " deepseek_key

  if [[ -n "$deepseek_key" ]]; then
    if ! [[ "$deepseek_key" =~ ^sk- ]]; then
      echo "  Formato invalido. DeepSeek keys comecam com 'sk-'."
      deepseek_key=""
    fi
  fi

  # Tier padrao
  while true; do
    read -rp "Tier padrao (budget/standard/premium, default: standard): " tier_padrao_input
    tier_padrao="${tier_padrao_input:-standard}"
    if [[ "$tier_padrao" =~ ^(budget|standard|premium)$ ]]; then
      break
    fi
    echo "  Opcoes validas: budget, standard, premium"
  done

  # Conferindo as info (keys mascaradas)
  conferindo_as_info \
    "OpenRouter Key=$(mask_key "$openrouter_key")" \
    "Anthropic Key=$(mask_key "$anthropic_key")" \
    "DeepSeek Key=$(if [[ -n "$deepseek_key" ]]; then mask_key "$deepseek_key"; else echo "nao configurado"; fi)" \
    "Tier Padrao=${tier_padrao}"

  read -rp "As informacoes estao corretas? (s/n): " confirma
  if [[ "$confirma" =~ ^[Ss]$ ]]; then
    break
  fi
done

step_ok "Inputs coletados"

# =============================================================================
# STEP 6: BACKUP + UPDATE llm-router-config.yaml
# =============================================================================
cp -p "$CONFIG_FILE" "${CONFIG_FILE}.bak"

cat > "$CONFIG_FILE" << YAML_EOF
# LLM Router Configuration — ${nome_agente}
# Generated by Legendsclaw Deployer (Story 3.2)
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# API keys stored in .env (never in this file)

defaults:
  tier: ${tier_padrao}
  max_retries: 3
  timeout_ms: 30000

providers:
  openrouter:
    api_key: \${OPENROUTER_API_KEY}
    base_url: https://openrouter.ai/api/v1
  anthropic:
    api_key: \${ANTHROPIC_API_KEY}
    base_url: https://api.anthropic.com

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

step_ok "llm-router-config.yaml atualizado (backup em .bak)"

# =============================================================================
# STEP 7: POPULAR .ENV NO VPS
# =============================================================================
ENV_FILE="${OPENCLAW_DIR}/.env"

# Funcao upsert: remove bloco existente e adiciona novo
upsert_env_block() {
  local env_file="$1"

  if [[ -f "$env_file" ]]; then
    # Remover bloco LLM Router existente (entre marcadores)
    local temp_file
    temp_file=$(mktemp)
    sed '/^# LLM Router$/,/^$/d' "$env_file" > "$temp_file" 2>/dev/null || cp "$env_file" "$temp_file"
    # Remover variaveis individuais se existirem fora do bloco
    sed -i '/^LLM_ROUTER_ENABLED=/d' "$temp_file" 2>/dev/null || true
    sed -i '/^LLM_ROUTER_CONFIG_PATH=/d' "$temp_file" 2>/dev/null || true
    sed -i '/^LLM_ROUTER_DEFAULT_TIER=/d' "$temp_file" 2>/dev/null || true
    sed -i '/^OPENROUTER_API_KEY=/d' "$temp_file" 2>/dev/null || true
    sed -i '/^ANTHROPIC_API_KEY=/d' "$temp_file" 2>/dev/null || true
    sed -i '/^DEEPSEEK_API_KEY=/d' "$temp_file" 2>/dev/null || true
    sed -i '/^# DEEPSEEK_API_KEY=/d' "$temp_file" 2>/dev/null || true
    cp "$temp_file" "$env_file"
    rm -f "$temp_file"
  fi

  # Append novo bloco
  {
    echo ""
    echo "# LLM Router"
    echo "LLM_ROUTER_ENABLED=true"
    echo "LLM_ROUTER_CONFIG_PATH=apps/${nome_agente}/config/llm-router-config.yaml"
    echo "LLM_ROUTER_DEFAULT_TIER=${tier_padrao}"
    echo "OPENROUTER_API_KEY=${openrouter_key}"
    echo "ANTHROPIC_API_KEY=${anthropic_key}"
    if [[ -n "$deepseek_key" ]]; then
      echo "DEEPSEEK_API_KEY=${deepseek_key}"
    else
      echo "# DEEPSEEK_API_KEY=  # Opcional — atualmente via OpenRouter"
    fi
    echo ""
  } >> "$env_file"
}

mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"
upsert_env_block "$ENV_FILE"
chmod 600 "$ENV_FILE"

step_ok ".env atualizado com keys do LLM Router em ${OPENCLAW_DIR}"

# =============================================================================
# STEP 8: TESTAR ROUTING — curl ao OpenRouter tier budget
# =============================================================================
echo ""
echo "  Testando conectividade com OpenRouter (tier budget)..."
teste_resultado="FAIL"

response=$(curl -s -w "\n%{http_code}" --max-time 15 \
  https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer ${openrouter_key}" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek/deepseek-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":5}' \
  2>/dev/null) || true

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" == "200" ]] && echo "$body" | grep -q '"choices"'; then
  step_ok "Teste budget tier: OK (HTTP ${http_code})"
  echo "  Custo estimado do teste: ~\$0.001"
  teste_resultado="OK"
else
  step_fail "Teste budget tier: FAIL (HTTP ${http_code:-timeout})"
  if [[ -n "$body" ]]; then
    echo "  Resposta: $(echo "$body" | head -c 200)"
  fi
  echo "  (Nao bloqueante — keys podem estar corretas mas rate-limited)"
fi

# Teste Anthropic — skip por padrao
step_skip "Teste Anthropic: skip (manual)"

# =============================================================================
# STEP 9: SAVE STATE — dados_llm_router
# =============================================================================
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/dados_llm_router" << EOF
Agente: ${nome_agente}
Config Path: apps/${nome_agente}/config/llm-router-config.yaml
Default Tier: ${tier_padrao}
OpenRouter: configurado
Anthropic: configurado
DeepSeek: $(if [[ -n "$deepseek_key" ]]; then echo "configurado"; else echo "nao configurado"; fi)
Teste Budget: ${teste_resultado}
Env File: ${ENV_FILE}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_llm_router"

step_ok "Estado salvo em ~/dados_vps/dados_llm_router"

# =============================================================================
# STEP 10: RESUMO + HINTS
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  LLM Router — ${nome_agente}${UI_NC}"
echo ""
echo "  Agente:        ${nome_agente}"
echo "  Tier padrao:   ${tier_padrao}"
echo "  OpenRouter:    $(mask_key "$openrouter_key")"
echo "  Anthropic:     $(mask_key "$anthropic_key")"
echo "  DeepSeek:      $(if [[ -n "$deepseek_key" ]]; then mask_key "$deepseek_key"; else echo "nao configurado"; fi)"
echo "  Teste budget:  ${teste_resultado}"
echo ""
echo "  Config:        ${CONFIG_FILE}"
echo "  Env:           ${ENV_FILE}"
echo "  Estado:        ~/dados_vps/dados_llm_router"
echo "  Log:           ${LOG_FILE}"
echo ""

hint_llm_router "${nome_agente}"

log_finish
