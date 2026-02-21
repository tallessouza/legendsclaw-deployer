#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 07: LLM Router
# Story 3.2 + Story 7.3: Config completa com 4 tiers, keywords, fallback
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
log_init "llm-router"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init 10

# =============================================================================
# STEP 2: LOAD STATE + VERIFICAR DEPENDENCIA WHITELABEL
# =============================================================================
dados
if [[ ! -f "$STATE_DIR/dados_whitelabel" ]]; then
  step_fail "Whitelabel nao encontrado (~/dados_vps/dados_whitelabel ausente)"
  echo "  Execute primeiro: Ferramenta [05] Whitelabel — Identidade do Agente"
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
  echo "  Execute a Ferramenta [05] Whitelabel primeiro"
  exit 1
fi

# Ler Install Path do OpenClaw para saber onde fica o .env
OPENCLAW_DIR=$(grep "Install Path:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}')
OPENCLAW_DIR="${OPENCLAW_DIR:-/opt/openclaw}"
step_ok "Dependencias verificadas — config e OpenClaw (${OPENCLAW_DIR})"

# =============================================================================
# STEP 4: EXIBIR TABELA DE CUSTOS (4 tiers, 7 modelos)
# =============================================================================
echo ""
echo -e "${UI_BOLD:-\033[1m}=============================================="
echo "  LLM ROUTER — TABELA DE CUSTOS (4 TIERS)"
echo -e "==============================================${UI_NC:-\033[0m}"
echo ""
echo "  Tier       Modelo                  Input/1M    Output/1M   Uso"
echo "  --------   ---------------------   ---------   ---------   -------------------"
echo "  budget     deepseek-chat           \$0.14       \$0.28       status, health"
echo "  budget     gemini-2.0-flash        \$0.10       \$0.40       queries simples"
echo "  standard   mistral-large-2411      \$2.00       \$6.00       ClickUp, N8N"
echo "  standard   gpt-4o-mini             \$0.15       \$0.60       workflows"
echo "  quality    claude-sonnet-4         \$3.00       \$15.00      analises, review"
echo "  quality    gpt-4o                  \$2.50       \$10.00      documentos"
echo "  premium    claude-opus-4-5         \$15.00      \$75.00      decisoes criticas"
echo ""
echo "=============================================="
echo ""
step_ok "Tabela de custos exibida (4 tiers, 7 modelos)"

# =============================================================================
# STEP 5: INPUT COLLECTION — API keys + tier padrao + metrics
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
    input "llm_router.openrouter_key" "OpenRouter API Key (sk-or-v1-...): " openrouter_key --secret --required
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
    input "llm_router.anthropic_key" "Anthropic API Key (sk-ant-...): " anthropic_key --secret --required
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
  input "llm_router.deepseek_key" "DeepSeek API Key (opcional, Enter para pular): " deepseek_key --secret

  if [[ -n "$deepseek_key" ]]; then
    if ! [[ "$deepseek_key" =~ ^sk- ]]; then
      echo "  Formato invalido. DeepSeek keys comecam com 'sk-'."
      deepseek_key=""
    fi
  fi

  # Tier padrao (agora com quality)
  while true; do
    input "llm_router.tier_padrao" "Tier padrao (budget/standard/quality/premium, default: standard): " tier_padrao_input --default=standard
    tier_padrao="${tier_padrao_input:-standard}"
    if [[ "$tier_padrao" =~ ^(budget|standard|quality|premium)$ ]]; then
      break
    fi
    echo "  Opcoes validas: budget, standard, quality, premium"
  done

  # Metricas (opcional)
  input "llm_router.metrics" "Habilitar metricas? (s/n, default: n): " metrics_input --default=n
  if [[ "$metrics_input" =~ ^[Ss]$ ]]; then
    metrics_enabled="true"
  else
    metrics_enabled="false"
  fi

  # Conferindo as info (keys mascaradas)
  conferindo_as_info \
    "OpenRouter Key=$(mask_key "$openrouter_key")" \
    "Anthropic Key=$(mask_key "$anthropic_key")" \
    "DeepSeek Key=$(if [[ -n "$deepseek_key" ]]; then mask_key "$deepseek_key"; else echo "nao configurado"; fi)" \
    "Tier Padrao=${tier_padrao}" \
    "Metricas=${metrics_enabled}"

  auto_confirm "As informacoes estao corretas? (s/n): " confirma
  if [[ "$confirma" =~ ^[Ss]$ ]]; then
    break
  fi
done

step_ok "Inputs coletados"

# =============================================================================
# STEP 6: BACKUP + UPDATE llm-router-config.yaml (YAML completo)
# =============================================================================
cp -p "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Determinar DeepSeek enabled
deepseek_enabled="true"
if [[ -z "$deepseek_key" ]]; then
  deepseek_enabled="false"
fi

# Gerar skill_mapping dinamico ou default
generate_skill_mapping() {
  if [[ -f "$STATE_DIR/dados_skills" ]]; then
    local skills_ativas
    skills_ativas=$(grep "Skills Ativas:" "$STATE_DIR/dados_skills" 2>/dev/null | awk -F': ' '{print $2}')
    if [[ -n "$skills_ativas" ]]; then
      # Mapear skills dinamicamente
      IFS=',' read -ra SKILLS <<< "$skills_ativas"
      for skill in "${SKILLS[@]}"; do
        skill=$(echo "$skill" | xargs) # trim
        local tier="standard"
        case "$skill" in
          *status*|*health*|*ping*|*check*) tier="budget" ;;
          *ops*|*trigger*|*query*|*message*|*send*|*fetch*) tier="standard" ;;
          *analyzer*|*review*|*creator*|*analysis*) tier="quality" ;;
          *strategic*|*complex*|*critical*) tier="premium" ;;
        esac
        echo "  ${skill}: ${tier}"
      done
      return
    fi
  fi
  # Default 14 mappings do stack de referencia
  cat << 'MAPPING'
  allos-status: budget
  n8n-trigger: budget
  supabase-query: budget
  health-check: budget
  clickup-ops: standard
  slack-message: standard
  email-draft: standard
  data-lookup: standard
  briefing-analyzer: quality
  skill-creator: quality
  code-review: quality
  document-analysis: quality
  strategic-planning: premium
  complex-reasoning: premium
MAPPING
}

# Contar skill mappings
skill_mapping_content=$(generate_skill_mapping)
skill_mapping_count=$(echo "$skill_mapping_content" | grep -c ':' || echo "0")

cat > "$CONFIG_FILE" << YAML_EOF
# ============================================
# LLM Router Configuration — ${nome_agente}
# ============================================
# Generated by Legendsclaw Deployer (Story 7.3)
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# API keys stored in .env (never in this file)

version: "1.0"

defaults:
  tier: ${tier_padrao}
  max_retries: 3
  timeout_ms: 30000

models:
  deepseek-v3:
    id: "deepseek/deepseek-chat"
    tier: budget
    input_cost_per_1m: 0.14
    output_cost_per_1m: 0.28
    context_window: 64000
    supports_tools: true
    supports_vision: false
    avg_latency_ms: 800
    priority: 1
    enabled: ${deepseek_enabled}

  gemini-flash:
    id: "google/gemini-2.0-flash-001"
    tier: budget
    input_cost_per_1m: 0.10
    output_cost_per_1m: 0.40
    context_window: 1000000
    supports_tools: true
    supports_vision: true
    avg_latency_ms: 600
    priority: 2
    enabled: true

  mistral-large:
    id: "mistral/mistral-large-2411"
    tier: standard
    input_cost_per_1m: 2.00
    output_cost_per_1m: 6.00
    context_window: 128000
    supports_tools: true
    supports_vision: false
    avg_latency_ms: 1200
    priority: 1
    enabled: true

  gpt-4o-mini:
    id: "openai/gpt-4o-mini"
    tier: standard
    input_cost_per_1m: 0.15
    output_cost_per_1m: 0.60
    context_window: 128000
    supports_tools: true
    supports_vision: true
    avg_latency_ms: 1000
    priority: 2
    enabled: true

  claude-sonnet:
    id: "anthropic/claude-sonnet-4"
    tier: quality
    input_cost_per_1m: 3.00
    output_cost_per_1m: 15.00
    context_window: 200000
    supports_tools: true
    supports_vision: true
    avg_latency_ms: 1500
    priority: 1
    enabled: true

  gpt-4o:
    id: "openai/gpt-4o"
    tier: quality
    input_cost_per_1m: 2.50
    output_cost_per_1m: 10.00
    context_window: 128000
    supports_tools: true
    supports_vision: true
    avg_latency_ms: 1800
    priority: 2
    enabled: true

  claude-opus:
    id: "anthropic/claude-opus-4-5"
    tier: premium
    input_cost_per_1m: 15.00
    output_cost_per_1m: 75.00
    context_window: 200000
    supports_tools: true
    supports_vision: true
    avg_latency_ms: 2500
    priority: 1
    enabled: true

tiers:
  budget:
    max_cost_per_request: 0.01
    models: [deepseek-v3, gemini-flash]
    fallback_tier: standard
  standard:
    max_cost_per_request: 0.10
    models: [mistral-large, gpt-4o-mini]
    fallback_tier: quality
  quality:
    max_cost_per_request: 2.00
    models: [claude-sonnet, gpt-4o]
    fallback_tier: premium
  premium:
    max_cost_per_request: 10.00
    models: [claude-opus]
    fallback_tier: null

skill_mapping:
${skill_mapping_content}

keywords:
  budget:
    words: [status, check, list, simple, quick, health, ping]
    weight: 0.3
  standard:
    words: [create, update, modify, send, fetch, trigger, workflow]
    weight: 0.5
  quality:
    words: [analyze, review, complex, detailed, comprehensive, briefing, document]
    weight: 0.7
  premium:
    words: [critical, strategic, enterprise, production, mission-critical]
    weight: 0.9

fallback:
  max_retries_per_model: 2
  max_total_retries: 5
  timeout_ms: 30000
  tier_escalation: true
  anthropic_direct_fallback: true
  on_error:
    rate_limit: exponential_backoff
    timeout: try_faster_model
    server_error: exponential_backoff
    context_length: try_next_model
    invalid_request: try_next_model

metrics:
  enabled: ${metrics_enabled}
  storage: none
  table: llm_metrics
  batch_size: 10
  flush_interval_ms: 30000
  retention_days: 30
YAML_EOF

# Validacao do YAML gerado
yaml_valid="false"
yaml_lines=$(wc -l < "$CONFIG_FILE")

if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
  if python3 -c "import yaml; yaml.safe_load(open('${CONFIG_FILE}'))" 2>/dev/null; then
    yaml_valid="true"
  fi
else
  # Fallback: verificar secoes obrigatorias com grep
  local_valid="true"
  for section in "models:" "tiers:" "skill_mapping:" "keywords:" "fallback:" "metrics:"; do
    if ! grep -q "^${section}" "$CONFIG_FILE" 2>/dev/null; then
      local_valid="false"
      break
    fi
  done
  yaml_valid="$local_valid"
fi

if [[ "$yaml_valid" == "true" ]]; then
  step_ok "llm-router-config.yaml atualizado (${yaml_lines} linhas, backup em .bak)"
else
  # Restaurar backup
  cp -p "${CONFIG_FILE}.bak" "$CONFIG_FILE"
  step_fail "YAML gerado invalido — backup restaurado"
  echo "  Verifique: cat ${CONFIG_FILE}.bak"
  exit 1
fi

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
# STEP 9: SAVE STATE — dados_llm_router (expandido)
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
Tiers: 4
Skill Mappings: ${skill_mapping_count}
Keywords: true
Fallback: true
Metrics: ${metrics_enabled}
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
echo "  Tiers:         4 (budget, standard, quality, premium)"
echo "  Modelos:       7"
echo "  Skill maps:    ${skill_mapping_count}"
echo "  Keywords:      4 categorias"
echo "  Fallback:      tier_escalation + on_error handlers"
echo "  Metricas:      ${metrics_enabled}"
echo "  OpenRouter:    $(mask_key "$openrouter_key")"
echo "  Anthropic:     $(mask_key "$anthropic_key")"
echo "  DeepSeek:      $(if [[ -n "$deepseek_key" ]]; then mask_key "$deepseek_key"; else echo "nao configurado"; fi)"
echo "  Teste budget:  ${teste_resultado}"
echo ""
echo "  Config:        ${CONFIG_FILE} (${yaml_lines} linhas)"
echo "  Env:           ${ENV_FILE}"
echo "  Estado:        ~/dados_vps/dados_llm_router"
echo "  Log:           ${LOG_FILE}"
echo ""

hint_llm_router "${nome_agente}"

# Reload gateway se estiver rodando
if reload_gateway; then
  echo -e "  Gateway reiniciado — novas rotas LLM ativas"
elif [[ $? -eq 2 ]]; then
  echo "  INFO: Gateway nao encontrado (sera aplicado ao iniciar)"
fi

log_finish
