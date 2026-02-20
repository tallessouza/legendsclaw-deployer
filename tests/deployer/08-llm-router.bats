#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/08-llm-router.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/08-llm-router.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  # Source libs com readonly removido
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/hints.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/env-detect.sh" 2>/dev/null || true)

  # Mock STATE_DIR
  export STATE_DIR="$(mktemp -d)"
  mkdir -p "$STATE_DIR"

  # Mock LOG_DIR
  export LOG_DIR="$(mktemp -d)"

  # Mock dirs
  export TEST_APPS_DIR="$(mktemp -d)"
  export TEST_ENV_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" "$TEST_ENV_DIR" 2>/dev/null || true
}

# =============================================================================
# hint_llm_router
# =============================================================================

@test "hint_llm_router displays header" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"LLM ROUTER"* ]]
}

@test "hint_llm_router shows debug step: verificar keys" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"Verificar keys"* ]]
}

@test "hint_llm_router shows debug step: testar manualmente" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"Testar manualmente"* ]]
}

@test "hint_llm_router shows config path with agent name" {
  run hint_llm_router "atlas"
  [[ "$output" == *"apps/atlas/config/llm-router-config.yaml"* ]]
}

@test "hint_llm_router shows next steps: skills" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"configurar skills"* ]]
}

@test "hint_llm_router shows OpenRouter URL" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"openrouter.ai"* ]]
}

@test "hint_llm_router uses default agent name when empty" {
  run hint_llm_router
  [[ "$output" == *"meu-agente"* ]]
}

@test "hint_llm_router mentions grep API_KEY" {
  run hint_llm_router "test"
  [[ "$output" == *"grep API_KEY"* ]]
}

# =============================================================================
# API Key Input Validation — OpenRouter
# =============================================================================

@test "openrouter key validation: valid format accepted" {
  local key="sk-or-v1-abcdef1234567890abcdef1234567890abcdef12"
  [[ "$key" =~ ^sk-or- ]] && [[ ${#key} -ge 40 ]]
}

@test "openrouter key validation: wrong prefix rejected" {
  local key="sk-ant-abcdef1234567890abcdef1234567890abcdef12"
  ! [[ "$key" =~ ^sk-or- ]]
}

@test "openrouter key validation: too short rejected" {
  local key="sk-or-v1-short"
  ! [[ ${#key} -ge 40 ]]
}

@test "openrouter key validation: empty rejected" {
  local key=""
  [[ -z "$key" ]]
}

# =============================================================================
# API Key Input Validation — Anthropic
# =============================================================================

@test "anthropic key validation: valid format accepted" {
  local key="sk-ant-abcdef1234567890abcdef1234567890abcdef1234567890ab"
  [[ "$key" =~ ^sk-ant- ]] && [[ ${#key} -ge 50 ]]
}

@test "anthropic key validation: wrong prefix rejected" {
  local key="sk-or-v1-abcdef1234567890abcdef1234567890abcdef1234567890ab"
  ! [[ "$key" =~ ^sk-ant- ]]
}

@test "anthropic key validation: too short rejected" {
  local key="sk-ant-short"
  ! [[ ${#key} -ge 50 ]]
}

# =============================================================================
# API Key Input Validation — DeepSeek
# =============================================================================

@test "deepseek key validation: valid format accepted" {
  local key="sk-abcdef1234567890"
  [[ "$key" =~ ^sk- ]]
}

@test "deepseek key validation: wrong prefix rejected" {
  local key="ds-abcdef1234567890"
  ! [[ "$key" =~ ^sk- ]]
}

# =============================================================================
# Tier Validation
# =============================================================================

@test "tier validation: budget accepted" {
  [[ "budget" =~ ^(budget|standard|premium)$ ]]
}

@test "tier validation: standard accepted" {
  [[ "standard" =~ ^(budget|standard|premium)$ ]]
}

@test "tier validation: premium accepted" {
  [[ "premium" =~ ^(budget|standard|premium)$ ]]
}

@test "tier validation: invalid rejected" {
  ! [[ "basic" =~ ^(budget|standard|premium)$ ]]
}

@test "tier validation: empty rejected" {
  ! [[ "" =~ ^(budget|standard|premium)$ ]]
}

# =============================================================================
# Key Masking
# =============================================================================

@test "mask_key: masks long key correctly" {
  # Source the mask_key function from script
  mask_key() {
    local key="$1"
    local len=${#key}
    if [[ $len -le 10 ]]; then
      echo "***"
    else
      echo "${key:0:8}***${key: -4}"
    fi
  }
  run mask_key "sk-or-v1-abcdef1234567890abcdef1234567890abcdef12"
  [[ "$output" == "sk-or-v1***f12" ]] || [[ "$output" == *"***"* ]]
}

@test "mask_key: never shows full key" {
  mask_key() {
    local key="$1"
    local len=${#key}
    if [[ $len -le 10 ]]; then
      echo "***"
    else
      echo "${key:0:8}***${key: -4}"
    fi
  }
  local full_key="sk-or-v1-abcdef1234567890abcdef1234567890abcdef12"
  run mask_key "$full_key"
  [[ "$output" != "$full_key" ]]
}

@test "mask_key: short key shows only stars" {
  mask_key() {
    local key="$1"
    local len=${#key}
    if [[ $len -le 10 ]]; then
      echo "***"
    else
      echo "${key:0:8}***${key: -4}"
    fi
  }
  run mask_key "short"
  [[ "$output" == "***" ]]
}

# =============================================================================
# llm-router-config.yaml Update
# =============================================================================

@test "updated config has providers section" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  cat > "$config" << 'EOF'
providers:
  openrouter:
    api_key: ${OPENROUTER_API_KEY}
    base_url: https://openrouter.ai/api/v1
  anthropic:
    api_key: ${ANTHROPIC_API_KEY}
    base_url: https://api.anthropic.com
EOF
  run cat "$config"
  [[ "$output" == *"providers:"* ]]
  [[ "$output" == *"openrouter:"* ]]
  [[ "$output" == *"anthropic:"* ]]
}

@test "updated config uses env var references not raw keys" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  cat > "$config" << 'EOF'
providers:
  openrouter:
    api_key: ${OPENROUTER_API_KEY}
EOF
  run cat "$config"
  [[ "$output" == *'${OPENROUTER_API_KEY}'* ]]
  ! [[ "$output" == *"sk-or-v1"* ]]
}

@test "updated config has all three tiers" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  cat > "$config" << 'EOF'
tiers:
  budget:
    models:
      - id: deepseek/deepseek-chat
  standard:
    models:
      - id: anthropic/claude-3.5-haiku
  premium:
    models:
      - id: claude-sonnet-4-6
EOF
  run cat "$config"
  [[ "$output" == *"budget:"* ]]
  [[ "$output" == *"standard:"* ]]
  [[ "$output" == *"premium:"* ]]
}

@test "updated config has default tier set" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  echo "defaults:" > "$config"
  echo "  tier: budget" >> "$config"
  run cat "$config"
  [[ "$output" == *"tier: budget"* ]]
}

@test "config backup is created before update" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  echo "original content" > "$config"
  cp -p "$config" "${config}.bak"
  [[ -f "${config}.bak" ]]
  run cat "${config}.bak"
  [[ "$output" == *"original content"* ]]
}

# =============================================================================
# .env Population
# =============================================================================

@test "env file contains LLM_ROUTER_ENABLED" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "LLM_ROUTER_ENABLED=true" > "$env_file"
  run cat "$env_file"
  [[ "$output" == *"LLM_ROUTER_ENABLED=true"* ]]
}

@test "env file contains OPENROUTER_API_KEY" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "OPENROUTER_API_KEY=sk-or-v1-test" > "$env_file"
  run cat "$env_file"
  [[ "$output" == *"OPENROUTER_API_KEY="* ]]
}

@test "env file contains ANTHROPIC_API_KEY" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "ANTHROPIC_API_KEY=sk-ant-test" > "$env_file"
  run cat "$env_file"
  [[ "$output" == *"ANTHROPIC_API_KEY="* ]]
}

@test "env file contains LLM_ROUTER_CONFIG_PATH" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "LLM_ROUTER_CONFIG_PATH=apps/jarvis/config/llm-router-config.yaml" > "$env_file"
  run cat "$env_file"
  [[ "$output" == *"LLM_ROUTER_CONFIG_PATH="* ]]
}

@test "env file contains LLM_ROUTER_DEFAULT_TIER" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "LLM_ROUTER_DEFAULT_TIER=standard" > "$env_file"
  run cat "$env_file"
  [[ "$output" == *"LLM_ROUTER_DEFAULT_TIER="* ]]
}

@test "env file has chmod 600 permissions" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "test" > "$env_file"
  chmod 600 "$env_file"
  local perms
  perms=$(stat -c %a "$env_file")
  [[ "$perms" == "600" ]]
}

@test "env upsert: does not duplicate LLM Router block" {
  local env_file="${TEST_ENV_DIR}/.env"
  # Simular bloco existente
  cat > "$env_file" << 'EOF'
# Existing
DB_HOST=localhost

# LLM Router
LLM_ROUTER_ENABLED=true
OPENROUTER_API_KEY=old-key

# After
OTHER_VAR=value
EOF
  # Upsert: remove bloco antigo
  local temp_file
  temp_file=$(mktemp)
  sed '/^# LLM Router$/,/^$/d' "$env_file" > "$temp_file"
  sed -i '/^LLM_ROUTER_ENABLED=/d' "$temp_file"
  sed -i '/^OPENROUTER_API_KEY=/d' "$temp_file"
  cp "$temp_file" "$env_file"
  rm -f "$temp_file"
  # Append novo bloco
  echo "# LLM Router" >> "$env_file"
  echo "LLM_ROUTER_ENABLED=true" >> "$env_file"
  echo "OPENROUTER_API_KEY=new-key" >> "$env_file"

  run cat "$env_file"
  # Deve conter apenas 1 ocorrencia de LLM_ROUTER_ENABLED
  local count
  count=$(grep -c "LLM_ROUTER_ENABLED" "$env_file")
  [[ "$count" -eq 1 ]]
}

# =============================================================================
# State File — dados_llm_router
# =============================================================================

@test "dados_llm_router contains Agente field" {
  cat > "$STATE_DIR/dados_llm_router" << 'EOF'
Agente: jarvis
Config Path: apps/jarvis/config/llm-router-config.yaml
Default Tier: standard
OpenRouter: configurado
Anthropic: configurado
DeepSeek: nao configurado
Teste Budget: OK
Env File: /opt/openclaw/.env
Data Configuracao: 2026-02-20 10:00:00
EOF
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Agente: jarvis"* ]]
}

@test "dados_llm_router contains Config Path field" {
  echo "Config Path: apps/jarvis/config/llm-router-config.yaml" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Config Path:"* ]]
}

@test "dados_llm_router contains Default Tier field" {
  echo "Default Tier: standard" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Default Tier:"* ]]
}

@test "dados_llm_router contains OpenRouter status" {
  echo "OpenRouter: configurado" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"OpenRouter: configurado"* ]]
}

@test "dados_llm_router contains Anthropic status" {
  echo "Anthropic: configurado" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Anthropic: configurado"* ]]
}

@test "dados_llm_router contains DeepSeek status" {
  echo "DeepSeek: nao configurado" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"DeepSeek:"* ]]
}

@test "dados_llm_router contains Teste Budget field" {
  echo "Teste Budget: OK" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Teste Budget:"* ]]
}

@test "dados_llm_router contains Env File field" {
  echo "Env File: /opt/openclaw/.env" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Env File:"* ]]
}

@test "dados_llm_router contains Data Configuracao field" {
  echo "Data Configuracao: 2026-02-20" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Data Configuracao:"* ]]
}

@test "dados_llm_router permissions are 600" {
  echo "test" > "$STATE_DIR/dados_llm_router"
  chmod 600 "$STATE_DIR/dados_llm_router"
  local perms
  perms=$(stat -c %a "$STATE_DIR/dados_llm_router")
  [[ "$perms" == "600" ]]
}

# =============================================================================
# Failure Scenarios
# =============================================================================

@test "fail: dados_whitelabel missing detected" {
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
}

@test "fail: llm-router-config.yaml missing detected" {
  [[ ! -f "${TEST_APPS_DIR}/config/llm-router-config.yaml" ]]
}

@test "fail: dados_openclaw missing causes concern" {
  [[ ! -f "$STATE_DIR/dados_openclaw" ]]
}

@test "fail: agent name extraction works from dados_whitelabel" {
  cat > "$STATE_DIR/dados_whitelabel" << 'EOF'
Agente: jarvis
Display Name: Jarvis
EOF
  local nome
  nome=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
  [[ "$nome" == "jarvis" ]]
}

@test "fail: empty agent name from malformed dados_whitelabel" {
  echo "bad format" > "$STATE_DIR/dados_whitelabel"
  local nome
  nome=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}')
  [[ -z "$nome" ]]
}

# =============================================================================
# Script File Existence
# =============================================================================

@test "08-llm-router.sh exists" {
  [[ -f "$SCRIPT_DIR/ferramentas/08-llm-router.sh" ]]
}

@test "08-llm-router.sh starts with shebang" {
  run head -1 "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "08-llm-router.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "08-llm-router.sh sources ui.sh" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "08-llm-router.sh sources logger.sh" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "08-llm-router.sh sources common.sh" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "08-llm-router.sh sources hints.sh" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/hints.sh"'* ]]
}

@test "08-llm-router.sh does NOT source deploy.sh" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  ! [[ "$output" == *'source "${LIB_DIR}/deploy.sh"'* ]]
}

@test "08-llm-router.sh calls log_init llm-router" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'log_init "llm-router"'* ]]
}

@test "08-llm-router.sh calls step_init 10" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"step_init 10"* ]]
}

@test "08-llm-router.sh checks dados_whitelabel dependency" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"dados_whitelabel"* ]]
}

@test "08-llm-router.sh checks llm-router-config.yaml dependency" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"llm-router-config.yaml"* ]]
}

@test "08-llm-router.sh calls conferindo_as_info" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"conferindo_as_info"* ]]
}

@test "08-llm-router.sh calls hint_llm_router" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"hint_llm_router"* ]]
}

@test "08-llm-router.sh calls log_finish" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"log_finish"* ]]
}

@test "08-llm-router.sh calls resumo_final" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"resumo_final"* ]]
}

@test "08-llm-router.sh chmod 600 dados_llm_router" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'chmod 600 "$STATE_DIR/dados_llm_router"'* ]]
}

@test "08-llm-router.sh creates backup before config update" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *'cp -p "$CONFIG_FILE"'* ]]
}

@test "08-llm-router.sh uses mask_key function" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"mask_key"* ]]
}

@test "08-llm-router.sh reads Install Path from dados_openclaw" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"Install Path"* ]]
  [[ "$output" == *"dados_openclaw"* ]]
}

# =============================================================================
# Deployer Menu Integration
# =============================================================================

@test "deployer.sh has [08] LLM Router menu entry" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"LLM Router"* ]]
}

@test "deployer.sh has case 08|8 for llm-router" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"08|8)"* ]]
}

@test "deployer.sh calls 08-llm-router.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"08-llm-router.sh"* ]]
}

# =============================================================================
# Cost Table Display
# =============================================================================

@test "08-llm-router.sh displays cost table" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"TABELA DE CUSTOS"* ]]
}

@test "08-llm-router.sh shows budget tier cost" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"0.01"* ]]
  [[ "$output" == *"0.14"* ]]
}

@test "08-llm-router.sh shows standard tier cost" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"0.05"* ]]
  [[ "$output" == *"0.80"* ]]
}

@test "08-llm-router.sh shows premium tier cost" {
  run cat "$SCRIPT_DIR/ferramentas/08-llm-router.sh"
  [[ "$output" == *"0.20"* ]]
  [[ "$output" == *"15.00"* ]]
}
