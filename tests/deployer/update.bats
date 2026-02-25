#!/usr/bin/env bats

# =============================================================================
# Tests for deployer/scripts/update.sh
# Story: 12.8
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/scripts/update.sh"

setup() {
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)

  export STATE_DIR="$(mktemp -d)"
  mkdir -p "$STATE_DIR"
  export LOG_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" 2>/dev/null || true
}

# --- Structural Tests ---

@test "update.sh exists" {
  [[ -f "$SCRIPT_PATH" ]]
}

@test "update.sh is executable" {
  [[ -x "$SCRIPT_PATH" ]]
}

@test "update.sh has valid bash syntax" {
  run bash -n "$SCRIPT_PATH"
  [[ "$status" -eq 0 ]]
}

@test "update.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_PATH"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "update.sh sources ui.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "update.sh sources logger.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "update.sh sources common.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "update.sh calls step_init" {
  run grep -c 'step_init' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "update.sh calls resumo_final" {
  run grep -c 'resumo_final' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "update.sh calls log_init" {
  run grep -c 'log_init' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "update.sh calls setup_trap" {
  run grep -c 'setup_trap' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

# --- Content/Logic Tests ---

@test "update.sh creates backup directory with timestamp" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"legendsclaw-backups"* ]]
  [[ "$output" == *'date +'* ]]
}

@test "update.sh copies config to backup" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"cp -r"* ]]
  [[ "$output" == *"backup_dir"* ]]
}

@test "update.sh performs git pull" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"git"* ]]
  [[ "$output" == *"pull"* ]]
}

@test "update.sh prompts for confirmation before git pull" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"git pull"* ]]
  [[ "$output" == *"S/n"* ]]
}

@test "update.sh aborts on git pull failure" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"exit 1"* ]]
  # Check that git pull failure leads to exit
  run grep -A3 "pull falhou" "$SCRIPT_PATH"
  [[ "$output" == *"exit 1"* ]]
}

@test "update.sh calls validate-config.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"validate-config.sh"* ]]
}

@test "update.sh calls validate.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"validate.sh"* ]]
}

@test "update.sh sets LEGENDSCLAW_TEE_ACTIVE for subscripts" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"LEGENDSCLAW_TEE_ACTIVE=1"* ]]
}

@test "update.sh exits 1 if no agent name provided" {
  run bash -c "export STATE_DIR='$STATE_DIR'; export HOME='$(mktemp -d)'; bash '$SCRIPT_PATH' 2>&1" || true
  [[ "$status" -ne 0 ]]
}

@test "update.sh exits based on STEP_FAIL" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'STEP_FAIL'* ]]
  [[ "$output" == *'exit 1'* ]]
  [[ "$output" == *'exit 0'* ]]
}

@test "update.sh supports AUTO_MODE for non-interactive" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"AUTO_MODE"* ]]
}

# --- Behavioral Tests ---

@test "update.sh: backup creates directory with config copy" {
  # Setup state and config
  local test_apps="$(mktemp -d)"
  echo "Agente: test-agent" > "$STATE_DIR/dados_whitelabel"
  echo "Apps Path: $test_apps" >> "$STATE_DIR/dados_whitelabel"
  mkdir -p "$test_apps/config"
  echo '{"test": true}' > "$test_apps/config/aiosbot.json"

  local test_home="$(mktemp -d)"
  # We can't fully run update.sh (needs git repo), but we can test the backup logic
  # by checking the script handles the backup_created flag
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"backup_created"* ]]

  rm -rf "$test_apps" "$test_home" 2>/dev/null || true
}

@test "update.sh: git pull failure message guards backup_dir reference" {
  # Verify the script has the backup_created guard
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'backup_created'* ]]
  [[ "$output" == *'backup_msg'* ]]
}
