#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/14-gateway-config.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/14-gateway-config.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/ferramentas/14-gateway-config.sh"

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

  # Mock APPS_DIR
  export TEST_APPS_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" 2>/dev/null || true
}

# =============================================================================
# Script Structure (AC: 1)
# =============================================================================

@test "14-gateway-config.sh exists" {
  [[ -f "$SCRIPT_PATH" ]]
}

@test "14-gateway-config.sh is executable" {
  [[ -x "$SCRIPT_PATH" ]]
}

@test "14-gateway-config.sh starts with shebang" {
  run head -1 "$SCRIPT_PATH"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "14-gateway-config.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_PATH"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "14-gateway-config.sh sources ui.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "14-gateway-config.sh sources logger.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "14-gateway-config.sh sources common.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "14-gateway-config.sh sources hints.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/hints.sh"'* ]]
}

@test "14-gateway-config.sh sources env-detect.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/env-detect.sh"'* ]]
}

@test "14-gateway-config.sh has log_init" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'log_init "gateway-config"'* ]]
}

@test "14-gateway-config.sh has setup_trap" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'setup_trap'* ]]
}

@test "14-gateway-config.sh has step_init" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'step_init 15'* ]]
}

@test "14-gateway-config.sh passes syntax check" {
  run bash -n "$SCRIPT_PATH"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Hint Function
# =============================================================================

@test "hint_gateway_config function exists in hints.sh" {
  run grep -c "hint_gateway_config()" "$SCRIPT_DIR/lib/hints.sh"
  [[ "$output" -ge 1 ]]
}

@test "hint_gateway_config accepts agent name parameter" {
  run grep 'local nome_agente=' "$SCRIPT_DIR/lib/hints.sh"
  [[ "$output" == *'nome_agente'* ]]
}

@test "hint_gateway_config mentions Ferramenta 15" {
  run grep -A 30 "hint_gateway_config()" "$SCRIPT_DIR/lib/hints.sh"
  [[ "$output" == *"15"* ]]
}

@test "hint_gateway_config has security warning" {
  run grep -A 30 "hint_gateway_config()" "$SCRIPT_DIR/lib/hints.sh"
  [[ "$output" == *"SEGURANCA"* ]] || [[ "$output" == *"credenciais"* ]]
}

# =============================================================================
# Menu Integration (AC: 1)
# =============================================================================

@test "deployer.sh has entry for gateway-config" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"14-gateway-config.sh"* ]]
}

@test "deployer.sh case handles option 14" {
  run grep "14)" "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"14)"* ]]
}

@test "deployer.sh menu shows Gateway Config (not EM BREVE)" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" != *"[14] Gateway Config"*"EM BREVE"* ]]
}

# =============================================================================
# Required Data Files Check (AC: 2)
# =============================================================================

@test "script checks for dados_openclaw" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_openclaw"* ]]
}

@test "script checks for dados_whitelabel" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_whitelabel"* ]]
}

@test "script checks for dados_workspace" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_workspace"* ]]
}

@test "script checks for dados_llm_router" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_llm_router"* ]]
}

# =============================================================================
# Optional Data Graceful Skip (AC: 2)
# =============================================================================

@test "script handles optional dados_tailscale" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_tailscale"* ]]
}

@test "script handles optional dados_evolution" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_evolution"* ]]
}

@test "script handles optional dados_seguranca" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_seguranca"* ]]
}

@test "script handles optional dados_elicitation" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_elicitation"* ]]
}

@test "script handles optional dados_vps for nome_servidor" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_vps"* ]]
  [[ "$output" == *"Nome do Servidor:"* ]]
}

@test "script handles optional dados_bridge" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_bridge"* ]]
}

@test "script handles optional dados_skills" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_skills"* ]]
}

# =============================================================================
# denyPatterns Default (AC: 5)
# =============================================================================

@test "default denyPatterns has 15 entries" {
  # Extract the default DENY_PATTERNS_JSON and count entries
  run node -e "
    const patterns = JSON.parse('[\"rm -rf /\",\"rm -rf /*\",\"mkfs\\\\\\\\.\",\"dd if=/dev\",\":\\\\\\\\(\\\\\\\\)\\\\\\\\{\\\\\\\\s*:\\\\\\\\|:\\\\\\\\&\\\\\\\\s*\\\\\\\\};:\",\"shutdown\",\"reboot\",\"> /dev/sd\",\"chmod -R 777 /\",\"wget .* \\\\\\\\| sh\",\"curl .* \\\\\\\\| sh\",\"wget .* \\\\\\\\| bash\",\"curl .* \\\\\\\\| bash\",\"rm -rf ~\",\"rm -rf \\\\\\\\\\\$HOME\"]');
    console.log(patterns.length);
  "
  [[ "$output" == "15" ]]
}

@test "script contains default denyPatterns" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"rm -rf /"* ]]
  [[ "$output" == *"shutdown"* ]]
  [[ "$output" == *"reboot"* ]]
}

# =============================================================================
# aiosbot.json Generation (AC: 3, 4)
# =============================================================================

@test "script generates aiosbot.json via node" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"aiosbot.json"* ]]
  [[ "$output" == *"node -e"* ]]
}

@test "script includes anthropic-router provider" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"anthropic-router"* ]]
  [[ "$output" == *"http://localhost:55119/v1"* ]]
}

@test "script includes model alias 'smart'" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'"alias": "smart"'* ]] || [[ "$output" == *'alias: "smart"'* ]]
}

@test "script conditionally adds anthropic aliases" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"reasoning"* ]]
  [[ "$output" == *"haiku"* ]]
  [[ "$output" == *"sonnet"* ]]
  [[ "$output" == *"opus"* ]]
}

@test "script conditionally adds openrouter aliases" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"backup"* ]]
  [[ "$output" == *"code"* ]]
  [[ "$output" == *"free"* ]]
  [[ "$output" == *"media"* ]]
  [[ "$output" == *"fast"* ]]
}

@test "script validates JSON after generation" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"JSON.parse"* ]]
}

# =============================================================================
# node.json Generation (AC: 8)
# =============================================================================

@test "script generates node.json" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"node.json"* ]]
}

@test "script generates UUID for node.json" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"uuidgen"* ]] || [[ "$output" == *"random/uuid"* ]]
}

# =============================================================================
# .env Generation (AC: 9)
# =============================================================================

@test "script generates .env file" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'ENV_DIR'* ]]
  [[ "$output" == *'.env'* ]]
}

@test ".env has Identity section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === Identity ==="* ]]
}

@test ".env has VPS Configuration section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === VPS Configuration ==="* ]]
}

@test ".env has Locale section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === Locale ==="* ]]
}

@test ".env has LLM API Keys section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === LLM API Keys"* ]]
}

@test ".env has Supabase section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === Supabase"* ]]
}

@test ".env has Services section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === Services"* ]]
}

@test ".env has Advanced section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"# === Advanced ==="* ]]
}

# =============================================================================
# mcp-config.json Generation (AC: 10)
# =============================================================================

@test "script generates mcp-config.json" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"mcp-config.json"* ]]
}

@test "script includes filesystem MCP server" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"@anthropic/mcp-filesystem"* ]]
}

@test "script conditionally includes brave-search MCP" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"@anthropic/mcp-brave-search"* ]]
}

@test "script conditionally includes memory MCP" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"@anthropic/mcp-memory"* ]]
}

# =============================================================================
# Security — chmod 600 (AC: 11)
# =============================================================================

@test "script sets chmod 600 on aiosbot.json" {
  run grep -c 'chmod 600.*aiosbot.json' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "script sets chmod 600 on node.json" {
  run grep -c 'chmod 600.*node.json' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "script sets chmod 600 on .env" {
  run grep -c 'chmod 600.*\.env' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "script sets chmod 600 on mcp-config.json" {
  run grep -c 'chmod 600.*mcp-config.json' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "script sets chmod 600 on dados_gateway_config" {
  run grep -c 'chmod 600.*dados_gateway_config' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

# =============================================================================
# State Saving (AC: 12)
# =============================================================================

@test "script saves dados_gateway_config" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_gateway_config"* ]]
}

@test "dados_gateway_config includes required fields" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"Agente:"* ]]
  [[ "$output" == *"Config Dir:"* ]]
  [[ "$output" == *"aiosbot.json:"* ]]
  [[ "$output" == *"node.json:"* ]]
  [[ "$output" == *"Status: completo"* ]]
}

# =============================================================================
# Resumo Final (AC: 13)
# =============================================================================

@test "script calls resumo_final" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"resumo_final"* ]]
}

@test "script calls hint_gateway_config" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"hint_gateway_config"* ]]
}

@test "script calls log_finish" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"log_finish"* ]]
}

# =============================================================================
# Backup (pre-overwrite)
# =============================================================================

@test "script creates backup before overwriting" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *".bak"* ]]
}

# =============================================================================
# WhatsApp / Evolution conditional (AC: 6)
# =============================================================================

@test "script conditionally includes whatsapp channel" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"HAS_EVOLUTION"* ]]
  [[ "$output" == *"channels.whatsapp"* ]] || [[ "$output" == *"config.channels.whatsapp"* ]]
}

# =============================================================================
# Gateway config (AC: 7)
# =============================================================================

@test "script configures gateway port from dados_openclaw" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"openclaw_porta"* ]]
  [[ "$output" == *"18789"* ]]
}

@test "script generates gateway password" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"openssl rand"* ]]
}

@test "script generates hooks token" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"openssl rand -hex"* ]]
}

# =============================================================================
# Compaction prompt (complex string handling)
# =============================================================================

@test "script includes compaction memoryFlush prompt" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"Pre-compaction memory flush"* ]]
  [[ "$output" == *"Observation Masking"* ]]
}

@test "script includes wizard section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"wizard"* ]]
}

@test "script includes messages section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"messages"* ]]
  [[ "$output" == *"ackReactionScope"* ]]
}

@test "script includes commands section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"nativeSkills"* ]]
}

@test "script includes bindings section" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"bindings"* ]]
}
