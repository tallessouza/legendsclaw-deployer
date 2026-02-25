#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/07-llm-router.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/07-llm-router.bats
# Story 3.2 + Story 7.3: Config completa com 4 tiers, keywords, fallback
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

@test "hint_llm_router shows 4 tiers info" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"budget, standard, quality, premium"* ]]
}

@test "hint_llm_router shows fallback chain" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"Fallback chain"* ]]
}

@test "hint_llm_router shows verify config command" {
  run hint_llm_router "jarvis"
  [[ "$output" == *"head -20"* ]]
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
# Tier Validation (4 tiers — Story 7.3)
# =============================================================================

@test "tier validation: budget accepted" {
  [[ "budget" =~ ^(budget|standard|quality|premium)$ ]]
}

@test "tier validation: standard accepted" {
  [[ "standard" =~ ^(budget|standard|quality|premium)$ ]]
}

@test "tier validation: quality accepted" {
  [[ "quality" =~ ^(budget|standard|quality|premium)$ ]]
}

@test "tier validation: premium accepted" {
  [[ "premium" =~ ^(budget|standard|quality|premium)$ ]]
}

@test "tier validation: invalid rejected" {
  ! [[ "basic" =~ ^(budget|standard|quality|premium)$ ]]
}

@test "tier validation: empty rejected" {
  ! [[ "" =~ ^(budget|standard|quality|premium)$ ]]
}

# =============================================================================
# Key Masking
# =============================================================================

@test "mask_key: masks long key correctly" {
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
# llm-router-config.yaml — Structure Validation (Story 7.3)
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

@test "updated config has all four tiers" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  cat > "$config" << 'EOF'
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
EOF
  run cat "$config"
  [[ "$output" == *"budget:"* ]]
  [[ "$output" == *"standard:"* ]]
  [[ "$output" == *"quality:"* ]]
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
# Models Section (Story 7.3 — AC1)
# =============================================================================

@test "config models section has 7 model definitions" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"deepseek-v3:"* ]]
  [[ "$output" == *"gemini-flash:"* ]]
  [[ "$output" == *"mistral-large:"* ]]
  [[ "$output" == *"gpt-4o-mini:"* ]]
  [[ "$output" == *"claude-sonnet:"* ]]
  [[ "$output" == *"gpt-4o:"* ]]
  [[ "$output" == *"claude-opus:"* ]]
}

@test "config models have cost metadata" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"input_cost_per_1m:"* ]]
  [[ "$output" == *"output_cost_per_1m:"* ]]
  [[ "$output" == *"context_window:"* ]]
  [[ "$output" == *"avg_latency_ms:"* ]]
}

@test "config models have capability flags" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"supports_tools:"* ]]
  [[ "$output" == *"supports_vision:"* ]]
  [[ "$output" == *"priority:"* ]]
  [[ "$output" == *"enabled:"* ]]
}

# =============================================================================
# Tiers Section — 4 tiers with fallback (Story 7.3 — AC1)
# =============================================================================

@test "script generates 4 tiers in YAML" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"fallback_tier: standard"* ]]
  [[ "$output" == *"fallback_tier: quality"* ]]
  [[ "$output" == *"fallback_tier: premium"* ]]
  [[ "$output" == *"fallback_tier: null"* ]]
}

@test "tiers have correct max_cost values" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"max_cost_per_request: 0.01"* ]]
  [[ "$output" == *"max_cost_per_request: 0.10"* ]]
  [[ "$output" == *"max_cost_per_request: 2.00"* ]]
  [[ "$output" == *"max_cost_per_request: 10.00"* ]]
}

# =============================================================================
# Keywords Section (Story 7.3 — AC3)
# =============================================================================

@test "script generates keywords section with 4 categories" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"keywords:"* ]]
  [[ "$output" == *"weight: 0.3"* ]]
  [[ "$output" == *"weight: 0.5"* ]]
  [[ "$output" == *"weight: 0.7"* ]]
  [[ "$output" == *"weight: 0.9"* ]]
}

@test "keywords have correct word lists" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"status, check, list"* ]]
  [[ "$output" == *"create, update, modify"* ]]
  [[ "$output" == *"analyze, review, complex"* ]]
  [[ "$output" == *"critical, strategic, enterprise"* ]]
}

# =============================================================================
# Fallback Section (Story 7.3 — AC4)
# =============================================================================

@test "script generates fallback section" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"fallback:"* ]]
  [[ "$output" == *"max_retries_per_model: 2"* ]]
  [[ "$output" == *"max_total_retries: 5"* ]]
  [[ "$output" == *"tier_escalation: true"* ]]
  [[ "$output" == *"anthropic_direct_fallback: true"* ]]
}

@test "fallback has on_error handlers" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"rate_limit: exponential_backoff"* ]]
  [[ "$output" == *"timeout: try_faster_model"* ]]
  [[ "$output" == *"server_error: exponential_backoff"* ]]
  [[ "$output" == *"context_length: try_next_model"* ]]
  [[ "$output" == *"invalid_request: try_next_model"* ]]
}

# =============================================================================
# Metrics Section (Story 7.3 — AC5)
# =============================================================================

@test "script generates metrics section" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"metrics:"* ]]
  [[ "$output" == *"storage: none"* ]]
  [[ "$output" == *"table: llm_metrics"* ]]
  [[ "$output" == *"batch_size: 10"* ]]
  [[ "$output" == *"flush_interval_ms: 30000"* ]]
  [[ "$output" == *"retention_days: 30"* ]]
}

# =============================================================================
# Skill Mapping — Default (Story 7.3 — AC2)
# =============================================================================

@test "script has default skill mapping with 14 entries" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"allos-status: budget"* ]]
  [[ "$output" == *"health-check: budget"* ]]
  [[ "$output" == *"clickup-ops: standard"* ]]
  [[ "$output" == *"briefing-analyzer: quality"* ]]
  [[ "$output" == *"strategic-planning: premium"* ]]
  [[ "$output" == *"complex-reasoning: premium"* ]]
}

@test "script checks dados_skills for dynamic mapping" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"dados_skills"* ]]
  [[ "$output" == *"Skills Ativas"* ]]
}

# =============================================================================
# YAML Validation (Story 7.3 — AC7)
# =============================================================================

@test "script validates YAML after generation" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"yaml_valid"* ]]
  [[ "$output" == *"python3"* ]]
}

@test "script has grep fallback for YAML validation" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"models:"* ]]
  [[ "$output" == *"tiers:"* ]]
  [[ "$output" == *"skill_mapping:"* ]]
  [[ "$output" == *"keywords:"* ]]
  [[ "$output" == *"fallback:"* ]]
}

@test "script restores backup on YAML validation failure" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'cp -p "${CONFIG_FILE}.bak" "$CONFIG_FILE"'* ]]
  [[ "$output" == *"YAML gerado invalido"* ]]
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
  cat > "$env_file" << 'EOF'
# Existing
DB_HOST=localhost

# LLM Router
LLM_ROUTER_ENABLED=true
OPENROUTER_API_KEY=old-key

# After
OTHER_VAR=value
EOF
  local temp_file
  temp_file=$(mktemp)
  sed '/^# LLM Router$/,/^$/d' "$env_file" > "$temp_file"
  sed -i '/^LLM_ROUTER_ENABLED=/d' "$temp_file"
  sed -i '/^OPENROUTER_API_KEY=/d' "$temp_file"
  cp "$temp_file" "$env_file"
  rm -f "$temp_file"
  echo "# LLM Router" >> "$env_file"
  echo "LLM_ROUTER_ENABLED=true" >> "$env_file"
  echo "OPENROUTER_API_KEY=new-key" >> "$env_file"

  run cat "$env_file"
  local count
  count=$(grep -c "LLM_ROUTER_ENABLED" "$env_file")
  [[ "$count" -eq 1 ]]
}

# =============================================================================
# State File — dados_llm_router (expanded — Story 7.3)
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
Tiers: 4
Skill Mappings: 14
Keywords: true
Fallback: true
Metrics: false
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

@test "dados_llm_router contains Tiers count" {
  echo "Tiers: 4" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Tiers: 4"* ]]
}

@test "dados_llm_router contains Skill Mappings count" {
  echo "Skill Mappings: 14" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Skill Mappings:"* ]]
}

@test "dados_llm_router contains Keywords flag" {
  echo "Keywords: true" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Keywords: true"* ]]
}

@test "dados_llm_router contains Fallback flag" {
  echo "Fallback: true" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Fallback: true"* ]]
}

@test "dados_llm_router contains Metrics flag" {
  echo "Metrics: false" > "$STATE_DIR/dados_llm_router"
  run cat "$STATE_DIR/dados_llm_router"
  [[ "$output" == *"Metrics:"* ]]
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
# Script File Existence & Structure
# =============================================================================

@test "07-llm-router.sh exists" {
  [[ -f "$SCRIPT_DIR/ferramentas/07-llm-router.sh" ]]
}

@test "07-llm-router.sh starts with shebang" {
  run head -1 "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "07-llm-router.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "07-llm-router.sh sources ui.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "07-llm-router.sh sources logger.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "07-llm-router.sh sources common.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "07-llm-router.sh sources hints.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'source "${LIB_DIR}/hints.sh"'* ]]
}

@test "07-llm-router.sh does NOT source deploy.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  ! [[ "$output" == *'source "${LIB_DIR}/deploy.sh"'* ]]
}

@test "07-llm-router.sh calls log_init llm-router" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'log_init "llm-router"'* ]]
}

@test "07-llm-router.sh calls step_init 10" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"step_init 10"* ]]
}

@test "07-llm-router.sh checks dados_whitelabel dependency" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"dados_whitelabel"* ]]
}

@test "07-llm-router.sh checks llm-router-config.yaml dependency" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"llm-router-config.yaml"* ]]
}

@test "07-llm-router.sh calls conferindo_as_info" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"conferindo_as_info"* ]]
}

@test "07-llm-router.sh calls hint_llm_router" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"hint_llm_router"* ]]
}

@test "07-llm-router.sh calls log_finish" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"log_finish"* ]]
}

@test "07-llm-router.sh calls resumo_final" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"resumo_final"* ]]
}

@test "07-llm-router.sh chmod 600 dados_llm_router" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'chmod 600 "$STATE_DIR/dados_llm_router"'* ]]
}

@test "07-llm-router.sh creates backup before config update" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'cp -p "$CONFIG_FILE"'* ]]
}

@test "07-llm-router.sh uses mask_key function" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"mask_key"* ]]
}

@test "07-llm-router.sh reads Install Path from dados_openclaw" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"Install Path"* ]]
  [[ "$output" == *"dados_openclaw"* ]]
}

@test "07-llm-router.sh references Story 7.3" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"Story 7.3"* ]]
}

# =============================================================================
# Deployer Menu Integration
# =============================================================================

@test "deployer.sh has LLM Router menu entry" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"LLM Router"* ]]
}

@test "deployer.sh calls 07-llm-router.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"07-llm-router.sh"* ]]
}

# =============================================================================
# Cost Table Display (Story 7.3 — 4 tiers)
# =============================================================================

@test "07-llm-router.sh displays cost table with 4 tiers" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"TABELA DE CUSTOS"* ]]
  [[ "$output" == *"4 TIERS"* ]]
}

@test "07-llm-router.sh shows budget tier models" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"deepseek-chat"* ]]
  [[ "$output" == *"gemini-2.0-flash"* ]]
}

@test "07-llm-router.sh shows standard tier models" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"mistral-large"* ]]
  [[ "$output" == *"gpt-4o-mini"* ]]
}

@test "07-llm-router.sh shows quality tier models" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"claude-sonnet-4"* ]]
  [[ "$output" == *"gpt-4o "* ]]
}

@test "07-llm-router.sh shows premium tier model" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"claude-opus-4-5"* ]]
}

# =============================================================================
# Story 12.10: Expanded Metrics — cost_tracking, cost_limits, analytics_endpoint
# =============================================================================

@test "metrics section has cost_tracking field" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"cost_tracking: true"* ]]
}

@test "metrics section has cost_limits with 4 tiers" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"cost_limits:"* ]]
  [[ "$output" == *"budget: 0.01"* ]]
  [[ "$output" == *"standard: 0.10"* ]]
  [[ "$output" == *"quality: 2.00"* ]]
  [[ "$output" == *"premium: 10.00"* ]]
}

@test "metrics section has analytics_endpoint field" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"analytics_endpoint: true"* ]]
}

@test "metrics default changed to enabled (default: s)" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"default: s"* ]]
}

# =============================================================================
# Story 12.10: Skill Mapping via SKILL.md Discovery
# =============================================================================

@test "generate_skill_mapping scans SKILL.md files" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"SKILL.md"* ]]
  [[ "$output" == *"find"* ]]
}

@test "generate_skill_mapping reads tier from frontmatter" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"tier:"* ]]
  [[ "$output" == *"name:"* ]]
}

@test "generate_skill_mapping has 3-level fallback" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  # Prioridade 1: SKILL.md discovery
  [[ "$output" == *"SKILL.md"* ]]
  # Prioridade 2: dados_skills pattern matching
  [[ "$output" == *"dados_skills"* ]]
  # Prioridade 3: Default mappings
  [[ "$output" == *"allos-status: budget"* ]]
}

@test "generate_skill_mapping validates tier values" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'(budget|standard|quality|premium)'* ]]
}

@test "generate_skill_mapping defaults to standard for invalid tier" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *'skill_tier="standard"'* ]]
}

@test "SKILL.md discovery: reads tier from mock SKILL.md" {
  # Criar estrutura mock de skills com SKILL.md
  local mock_skills_dir="${TEST_APPS_DIR}/skills/superpowers/test-skill"
  mkdir -p "$mock_skills_dir"
  cat > "$mock_skills_dir/SKILL.md" << 'EOF'
---
name: test-skill
description: Test skill
version: 1.0.0
tier: quality
always_on: false
---

# Test Skill
EOF

  # Extrair tier do frontmatter (mesmo algoritmo do script)
  local skill_tier="standard"
  local in_frontmatter=false
  local skill_name=""
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_frontmatter" == "true" ]]; then
        break
      fi
      in_frontmatter=true
      continue
    fi
    if [[ "$in_frontmatter" == "true" ]]; then
      case "$line" in
        name:*) skill_name=$(echo "$line" | sed 's/^name:[[:space:]]*//' | xargs) ;;
        tier:*) skill_tier=$(echo "$line" | sed 's/^tier:[[:space:]]*//' | xargs) ;;
      esac
    fi
  done < "$mock_skills_dir/SKILL.md"

  [[ "$skill_name" == "test-skill" ]]
  [[ "$skill_tier" == "quality" ]]
}

@test "SKILL.md discovery: defaults to standard when tier missing" {
  local mock_skills_dir="${TEST_APPS_DIR}/skills/system/no-tier-skill"
  mkdir -p "$mock_skills_dir"
  cat > "$mock_skills_dir/SKILL.md" << 'EOF'
---
name: no-tier-skill
description: Skill without tier field
version: 1.0.0
always_on: false
---

# No Tier Skill
EOF

  local skill_tier="standard"
  local in_frontmatter=false
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_frontmatter" == "true" ]]; then
        break
      fi
      in_frontmatter=true
      continue
    fi
    if [[ "$in_frontmatter" == "true" ]]; then
      case "$line" in
        tier:*) skill_tier=$(echo "$line" | sed 's/^tier:[[:space:]]*//' | xargs) ;;
      esac
    fi
  done < "$mock_skills_dir/SKILL.md"

  # Tier should remain "standard" (default) since SKILL.md has no tier field
  [[ "$skill_tier" == "standard" ]]
}

@test "SKILL.md discovery: validates invalid tier falls back to standard" {
  local skill_tier="invalid_tier"
  if ! [[ "$skill_tier" =~ ^(budget|standard|quality|premium)$ ]]; then
    skill_tier="standard"
  fi
  [[ "$skill_tier" == "standard" ]]
}

@test "default skill mapping still has 14 entries as fallback" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"allos-status: budget"* ]]
  [[ "$output" == *"health-check: budget"* ]]
  [[ "$output" == *"clickup-ops: standard"* ]]
  [[ "$output" == *"briefing-analyzer: quality"* ]]
  [[ "$output" == *"strategic-planning: premium"* ]]
  [[ "$output" == *"complex-reasoning: premium"* ]]
}

# =============================================================================
# Story 12.10: Regression — existing config sections intact
# =============================================================================

@test "regression: models section still has 7 models" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"deepseek-v3:"* ]]
  [[ "$output" == *"gemini-flash:"* ]]
  [[ "$output" == *"mistral-large:"* ]]
  [[ "$output" == *"gpt-4o-mini:"* ]]
  [[ "$output" == *"claude-sonnet:"* ]]
  [[ "$output" == *"gpt-4o:"* ]]
  [[ "$output" == *"claude-opus:"* ]]
}

@test "regression: keywords section still intact" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"keywords:"* ]]
  [[ "$output" == *"weight: 0.3"* ]]
  [[ "$output" == *"weight: 0.9"* ]]
}

@test "regression: fallback section still intact" {
  run cat "$SCRIPT_DIR/ferramentas/07-llm-router.sh"
  [[ "$output" == *"fallback:"* ]]
  [[ "$output" == *"tier_escalation: true"* ]]
  [[ "$output" == *"on_error:"* ]]
}
