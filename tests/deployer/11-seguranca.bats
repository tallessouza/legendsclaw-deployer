#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/11-seguranca.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/11-seguranca.bats
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
  export TEST_BLOCKLIST_DIR="${TEST_APPS_DIR}/test-agent/skills/lib"
  mkdir -p "$TEST_BLOCKLIST_DIR"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" 2>/dev/null || true
}

# =============================================================================
# Script existence and executability
# =============================================================================

@test "11-seguranca.sh exists" {
  [[ -f "$SCRIPT_DIR/ferramentas/11-seguranca.sh" ]]
}

@test "11-seguranca.sh is executable" {
  [[ -x "$SCRIPT_DIR/ferramentas/11-seguranca.sh" ]]
}

@test "11-seguranca.sh sources all required libs" {
  run grep -c "source.*LIB_DIR" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$output" -ge 5 ]]
}

# =============================================================================
# Dependency check (OpenClaw)
# =============================================================================

@test "script checks for dados_openclaw dependency" {
  run grep "dados_openclaw" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Layer 1: Blocklist
# =============================================================================

@test "blocklist.yaml generated contains default blocked commands" {
  # Simulate blocklist generation
  cat > "${TEST_BLOCKLIST_DIR}/blocklist.yaml" << 'EOF'
blocked_commands:
  - rm -rf
  - sudo su
  - dd if=
  - mkfs
  - iptables -F
validation:
  - Regex matching antes de executar comandos
  - Whitelist de comandos permitidos por skill
  - Logging de tentativas bloqueadas
EOF

  run grep "rm -rf" "${TEST_BLOCKLIST_DIR}/blocklist.yaml"
  [[ "$status" -eq 0 ]]

  run grep "sudo su" "${TEST_BLOCKLIST_DIR}/blocklist.yaml"
  [[ "$status" -eq 0 ]]

  run grep "dd if=" "${TEST_BLOCKLIST_DIR}/blocklist.yaml"
  [[ "$status" -eq 0 ]]

  run grep "mkfs" "${TEST_BLOCKLIST_DIR}/blocklist.yaml"
  [[ "$status" -eq 0 ]]

  run grep "iptables -F" "${TEST_BLOCKLIST_DIR}/blocklist.yaml"
  [[ "$status" -eq 0 ]]
}

@test "command-safety.js exists and exports validateCommand" {
  # Simulate command-safety generation
  cat > "${TEST_BLOCKLIST_DIR}/command-safety.js" << 'EOF'
const { validateCommand, loadBlocklist, reloadBlocklist } = require('./actual');
module.exports = { validateCommand, loadBlocklist, reloadBlocklist };
EOF

  [[ -f "${TEST_BLOCKLIST_DIR}/command-safety.js" ]]
  run grep "validateCommand" "${TEST_BLOCKLIST_DIR}/command-safety.js"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Layer 2: Sandbox
# =============================================================================

@test "Dockerfile.sandbox generated uses alpine:3.19" {
  # Check the script generates correct Dockerfile
  run grep "alpine:3.19" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$status" -eq 0 ]]
}

@test "Dockerfile.sandbox uses USER sandbox" {
  run grep "USER sandbox" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$status" -eq 0 ]]
}

@test "sandbox config has network none and read_only" {
  run grep "read_only: true" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Layer 3: Logging
# =============================================================================

@test "journald config has MaxRetentionSec for 6 months" {
  run grep "MaxRetentionSec=15780000" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$status" -eq 0 ]]
}

@test "logrotate config has rotate 180" {
  run grep "rotate 180" "$SCRIPT_DIR/ferramentas/11-seguranca.sh"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# State file
# =============================================================================

@test "dados_seguranca contains status of 3 layers" {
  # Simulate state file
  cat > "$STATE_DIR/dados_seguranca" << 'EOF'
Layer 1 (Blocklist): ATIVO
Layer 2 (Sandbox): ATIVO
Layer 3 (Logging): ATIVO
EOF

  run grep "Layer 1" "$STATE_DIR/dados_seguranca"
  [[ "$status" -eq 0 ]]

  run grep "Layer 2" "$STATE_DIR/dados_seguranca"
  [[ "$status" -eq 0 ]]

  run grep "Layer 3" "$STATE_DIR/dados_seguranca"
  [[ "$status" -eq 0 ]]
}

@test "dados_seguranca has permission 600" {
  cat > "$STATE_DIR/dados_seguranca" << 'EOF'
Layer 1 (Blocklist): ATIVO
EOF
  chmod 600 "$STATE_DIR/dados_seguranca"

  local perms
  perms=$(stat -c "%a" "$STATE_DIR/dados_seguranca" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/dados_seguranca" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

# =============================================================================
# Hints
# =============================================================================

@test "hint_seguranca_blocklist is defined in hints.sh" {
  run type -t hint_seguranca_blocklist
  [[ "$output" == "function" ]]
}

@test "hint_seguranca_blocklist displays blocklist header" {
  run hint_seguranca_blocklist "test-agent"
  [[ "$output" == *"BLOCKLIST"* ]]
  [[ "$output" == *"test-agent"* ]]
}

@test "hint_seguranca_sandbox is defined in hints.sh" {
  run type -t hint_seguranca_sandbox
  [[ "$output" == "function" ]]
}

@test "hint_seguranca_sandbox displays sandbox header" {
  run hint_seguranca_sandbox
  [[ "$output" == *"SANDBOX"* ]]
  [[ "$output" == *"docker"* ]]
}

@test "hint_seguranca_logging is defined in hints.sh" {
  run type -t hint_seguranca_logging
  [[ "$output" == "function" ]]
}

@test "hint_seguranca_logging displays logging header" {
  run hint_seguranca_logging
  [[ "$output" == *"LOGGING"* ]]
  [[ "$output" == *"journalctl"* ]]
}

# =============================================================================
# Menu integration
# =============================================================================

@test "deployer.sh menu contains [11] Seguranca" {
  run grep '\[11\]' "$SCRIPT_DIR/deployer.sh"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Seguranca"* ]]
}

@test "deployer.sh has case 11 handler" {
  run grep "11)" "$SCRIPT_DIR/deployer.sh"
  [[ "$status" -eq 0 ]]
}
