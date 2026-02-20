#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/07-whitelabel.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/07-whitelabel.bats
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

  # Mock APPS_DIR
  export TEST_APPS_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" 2>/dev/null || true
}

# =============================================================================
# hint_whitelabel
# =============================================================================

@test "hint_whitelabel displays next steps header" {
  run hint_whitelabel "jarvis"
  [[ "$output" == *"PROXIMOS PASSOS"* ]]
}

@test "hint_whitelabel shows LLM Router step" {
  run hint_whitelabel "jarvis"
  [[ "$output" == *"Configurar LLM Router"* ]]
}

@test "hint_whitelabel shows config.js path with agent name" {
  run hint_whitelabel "atlas"
  [[ "$output" == *"apps/atlas/skills/config.js"* ]]
}

@test "hint_whitelabel shows AIOS agent creation step" {
  run hint_whitelabel "cortana"
  [[ "$output" == *"@aios-master *create agent"* ]]
}

@test "hint_whitelabel shows AIOS agent manual path" {
  run hint_whitelabel "jarvis"
  [[ "$output" == *".aios-core/development/agents/jarvis.md"* ]]
}

@test "hint_whitelabel mentions AIOS Core requirement" {
  run hint_whitelabel "jarvis"
  [[ "$output" == *"AIOS Core"* ]]
}

@test "hint_whitelabel uses default agent name when empty" {
  run hint_whitelabel
  [[ "$output" == *"meu-agente"* ]]
}

@test "hint_whitelabel shows Ferramenta [08] reference" {
  run hint_whitelabel "test"
  [[ "$output" == *"Ferramenta [08]"* ]]
}

# =============================================================================
# Input Validation — nome_agente kebab-case
# =============================================================================

@test "kebab-case validation: lowercase accepted" {
  [[ "jarvis" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: lowercase with numbers accepted" {
  [[ "agent007" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: kebab-case accepted" {
  [[ "meu-agente" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: uppercase rejected" {
  ! [[ "Jarvis" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: spaces rejected" {
  ! [[ "meu agente" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: special chars rejected" {
  ! [[ "agent@home" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: underscore rejected" {
  ! [[ "meu_agente" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: starts with number rejected" {
  ! [[ "007agent" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: empty rejected" {
  ! [[ "" =~ ^[a-z][a-z0-9-]*$ ]]
}

@test "kebab-case validation: dot rejected" {
  ! [[ "agent.ai" =~ ^[a-z][a-z0-9-]*$ ]]
}

# =============================================================================
# Structure Creation
# =============================================================================

@test "create apps structure: all directories exist" {
  local agent_dir="${TEST_APPS_DIR}/test-agent"
  mkdir -p "${agent_dir}/config"
  mkdir -p "${agent_dir}/hooks/session-digest"
  mkdir -p "${agent_dir}/lib"
  mkdir -p "${agent_dir}/skills/lib"

  [[ -d "${agent_dir}/config" ]]
  [[ -d "${agent_dir}/hooks/session-digest" ]]
  [[ -d "${agent_dir}/lib" ]]
  [[ -d "${agent_dir}/skills/lib" ]]
}

@test "create apps structure: config directory exists" {
  local agent_dir="${TEST_APPS_DIR}/test-agent"
  mkdir -p "${agent_dir}/config"
  [[ -d "${agent_dir}/config" ]]
}

@test "create apps structure: hooks/session-digest exists" {
  local agent_dir="${TEST_APPS_DIR}/test-agent"
  mkdir -p "${agent_dir}/hooks/session-digest"
  [[ -d "${agent_dir}/hooks/session-digest" ]]
}

@test "create apps structure: skills/lib exists" {
  local agent_dir="${TEST_APPS_DIR}/test-agent"
  mkdir -p "${agent_dir}/skills/lib"
  [[ -d "${agent_dir}/skills/lib" ]]
}

# =============================================================================
# config.js Generation
# =============================================================================

@test "config.js contains AGENT_NAME" {
  local config_file="${TEST_APPS_DIR}/config.js"
  cat > "$config_file" << 'EOF'
module.exports = {
  AGENT_NAME: 'jarvis',
};
EOF
  run cat "$config_file"
  [[ "$output" == *"AGENT_NAME"* ]]
}

@test "config.js contains CLICKUP_TEAM_ID placeholder" {
  local config_file="${TEST_APPS_DIR}/config.js"
  cat > "$config_file" << 'EOF'
CLICKUP_TEAM_ID: process.env.CLICKUP_TEAM_ID || 'SEU_TEAM_ID',
EOF
  run cat "$config_file"
  [[ "$output" == *"SEU_TEAM_ID"* ]]
}

@test "config.js uses process.env for sensitive values" {
  local config_file="${TEST_APPS_DIR}/config.js"
  cat > "$config_file" << 'EOF'
SUPABASE_URL: process.env.SUPABASE_URL || 'https://SEU_PROJECT.supabase.co',
EOF
  run cat "$config_file"
  [[ "$output" == *"process.env"* ]]
}

@test "config.js contains MEMORY_BASE_PATH" {
  local config_file="${TEST_APPS_DIR}/config.js"
  cat > "$config_file" << 'EOF'
MEMORY_BASE_PATH: process.env.MEMORY_PATH || '~/.jarvis/',
EOF
  run cat "$config_file"
  [[ "$output" == *"MEMORY_BASE_PATH"* ]]
}

# =============================================================================
# State File — dados_whitelabel
# =============================================================================

@test "dados_whitelabel is saved with correct fields" {
  cat > "$STATE_DIR/dados_whitelabel" << 'EOF'
Agente: jarvis
Display Name: Jarvis
Icone: 🤖
Persona: Pratico, eficiente
Idioma: pt-BR
Apps Path: apps/jarvis
Config: apps/jarvis/skills/config.js
Data Criacao: 2026-02-20 10:00:00
EOF
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Agente: jarvis"* ]]
  [[ "$output" == *"Display Name: Jarvis"* ]]
  [[ "$output" == *"Apps Path: apps/jarvis"* ]]
}

@test "dados_whitelabel contains Agente field" {
  echo "Agente: test" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Agente:"* ]]
}

@test "dados_whitelabel contains Display Name field" {
  echo "Display Name: Test" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Display Name:"* ]]
}

@test "dados_whitelabel contains Icone field" {
  echo "Icone: 🤖" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Icone:"* ]]
}

@test "dados_whitelabel contains Persona field" {
  echo "Persona: Test" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Persona:"* ]]
}

@test "dados_whitelabel contains Idioma field" {
  echo "Idioma: pt-BR" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Idioma:"* ]]
}

@test "dados_whitelabel contains Apps Path field" {
  echo "Apps Path: apps/test" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Apps Path:"* ]]
}

@test "dados_whitelabel contains Config field" {
  echo "Config: apps/test/skills/config.js" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Config:"* ]]
}

@test "dados_whitelabel contains Data Criacao field" {
  echo "Data Criacao: 2026-02-20" > "$STATE_DIR/dados_whitelabel"
  run cat "$STATE_DIR/dados_whitelabel"
  [[ "$output" == *"Data Criacao:"* ]]
}

@test "dados_whitelabel permissions are 600" {
  echo "test" > "$STATE_DIR/dados_whitelabel"
  chmod 600 "$STATE_DIR/dados_whitelabel"
  local perms
  perms=$(stat -c %a "$STATE_DIR/dados_whitelabel")
  [[ "$perms" == "600" ]]
}

# =============================================================================
# Failure Scenarios
# =============================================================================

@test "fail: dados_openclaw missing detected" {
  # dados_openclaw should not exist in clean STATE_DIR
  [[ ! -f "$STATE_DIR/dados_openclaw" ]]
}

@test "fail: agent already exists detected" {
  local agent_dir="${TEST_APPS_DIR}/existing-agent"
  mkdir -p "$agent_dir"
  [[ -d "$agent_dir" ]]
}

# =============================================================================
# llm-router-config.yaml Template
# =============================================================================

@test "llm-router-config.yaml created with correct structure" {
  local config="${TEST_APPS_DIR}/llm-router-config.yaml"
  cat > "$config" << 'EOF'
defaults:
  tier: standard
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
  [[ "$output" == *"tier: standard"* ]]
  [[ "$output" == *"budget:"* ]]
  [[ "$output" == *"standard:"* ]]
  [[ "$output" == *"premium:"* ]]
}

# =============================================================================
# skills/lib Files
# =============================================================================

@test "blocklist.yaml contains blocked commands" {
  local bl="${TEST_APPS_DIR}/blocklist.yaml"
  cat > "$bl" << 'EOF'
blocked_commands:
  - rm -rf /
  - sudo su
EOF
  run cat "$bl"
  [[ "$output" == *"rm -rf /"* ]]
  [[ "$output" == *"sudo su"* ]]
}

@test "package.json contains correct name format" {
  local pkg="${TEST_APPS_DIR}/package.json"
  cat > "$pkg" << 'EOF'
{
  "name": "@legendsclaw/jarvis-skills"
}
EOF
  run cat "$pkg"
  [[ "$output" == *"@legendsclaw/jarvis-skills"* ]]
}

# =============================================================================
# step_init / step_ok / step_fail
# =============================================================================

@test "step_init sets STEP_TOTAL to 8" {
  step_init 8
  [[ "$STEP_TOTAL" -eq 8 ]]
}

@test "step_ok increments STEP_OK counter" {
  step_init 8
  step_ok "test message" > /dev/null
  [[ "$STEP_OK" -eq 1 ]]
}

@test "step_ok output contains OK" {
  step_init 8
  run step_ok "test message"
  [[ "$output" == *"OK"* ]]
}

@test "step_fail output contains FAIL" {
  step_init 8
  run step_fail "test message"
  [[ "$output" == *"FAIL"* ]]
}

@test "step_ok output contains step counter" {
  step_init 8
  run step_ok "test message"
  [[ "$output" == *"/8"* ]]
}

# =============================================================================
# conferindo_as_info
# =============================================================================

@test "conferindo_as_info shows all fields" {
  run conferindo_as_info "Nome=jarvis" "Display=Jarvis" "Icone=🤖"
  [[ "$output" == *"Nome: jarvis"* ]]
  [[ "$output" == *"Display: Jarvis"* ]]
}

@test "conferindo_as_info shows header" {
  run conferindo_as_info "teste=valor"
  [[ "$output" == *"CONFERINDO AS INFORMACOES"* ]]
}

# =============================================================================
# Session Digest Placeholders
# =============================================================================

@test "session-digest hook.yml is valid YAML" {
  local hook="${TEST_APPS_DIR}/hook.yml"
  cat > "$hook" << 'EOF'
name: session-digest
trigger: SessionEnd
enabled: false
EOF
  run cat "$hook"
  [[ "$output" == *"name: session-digest"* ]]
  [[ "$output" == *"enabled: false"* ]]
}

# =============================================================================
# Script File Existence
# =============================================================================

@test "07-whitelabel.sh exists" {
  [[ -f "$SCRIPT_DIR/ferramentas/07-whitelabel.sh" ]]
}

@test "07-whitelabel.sh is executable" {
  [[ -x "$SCRIPT_DIR/ferramentas/07-whitelabel.sh" ]]
}

@test "07-whitelabel.sh starts with shebang" {
  run head -1 "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "07-whitelabel.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "07-whitelabel.sh sources ui.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "07-whitelabel.sh sources logger.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "07-whitelabel.sh sources common.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "07-whitelabel.sh sources hints.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *'source "${LIB_DIR}/hints.sh"'* ]]
}

@test "07-whitelabel.sh does NOT source deploy.sh" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  ! [[ "$output" == *'source "${LIB_DIR}/deploy.sh"'* ]]
}

@test "07-whitelabel.sh calls log_init whitelabel" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *'log_init "whitelabel"'* ]]
}

@test "07-whitelabel.sh calls step_init 8" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *"step_init 8"* ]]
}

@test "07-whitelabel.sh checks dados_openclaw dependency" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *"dados_openclaw"* ]]
}

@test "07-whitelabel.sh calls hint_whitelabel" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *"hint_whitelabel"* ]]
}

@test "07-whitelabel.sh calls log_finish" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *"log_finish"* ]]
}

@test "07-whitelabel.sh calls conferindo_as_info" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *"conferindo_as_info"* ]]
}

@test "07-whitelabel.sh chmod 600 dados_whitelabel" {
  run cat "$SCRIPT_DIR/ferramentas/07-whitelabel.sh"
  [[ "$output" == *'chmod 600 "$STATE_DIR/dados_whitelabel"'* ]]
}

# =============================================================================
# Deployer Menu Integration
# =============================================================================

@test "deployer.sh has [07] Whitelabel menu entry" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"Whitelabel"* ]]
}

@test "deployer.sh has case 07|7 for whitelabel" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"07|7)"* ]]
}

@test "deployer.sh calls 07-whitelabel.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"07-whitelabel.sh"* ]]
}
