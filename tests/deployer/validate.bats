#!/usr/bin/env bats

# =============================================================================
# Tests for deployer/scripts/validate.sh
# Story: 12.8
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/scripts/validate.sh"

setup() {
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)

  export STATE_DIR="$(mktemp -d)"
  mkdir -p "$STATE_DIR"
  export LOG_DIR="$(mktemp -d)"

  # Create test apps structure
  TEST_APPS_DIR="$(mktemp -d)"
  export TEST_APPS_DIR
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" 2>/dev/null || true
}

# --- Structural Tests ---

@test "validate.sh exists" {
  [[ -f "$SCRIPT_PATH" ]]
}

@test "validate.sh is executable" {
  [[ -x "$SCRIPT_PATH" ]]
}

@test "validate.sh has valid bash syntax" {
  run bash -n "$SCRIPT_PATH"
  [[ "$status" -eq 0 ]]
}

@test "validate.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_PATH"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "validate.sh sources ui.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "validate.sh sources logger.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "validate.sh sources common.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "validate.sh calls step_init" {
  run grep -c 'step_init' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "validate.sh calls resumo_final" {
  run grep -c 'resumo_final' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "validate.sh calls log_init" {
  run grep -c 'log_init' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "validate.sh calls setup_trap" {
  run grep -c 'setup_trap' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

# --- Content/Logic Tests ---

@test "validate.sh checks dados_whitelabel" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_whitelabel"* ]]
}

@test "validate.sh checks dados_openclaw" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_openclaw"* ]]
}

@test "validate.sh checks dados_workspace" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"dados_workspace"* ]]
}

@test "validate.sh checks gateway health via curl" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"curl"* ]]
  [[ "$output" == *"/health"* ]]
}

@test "validate.sh checks SKILL.md" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"SKILL.md"* ]]
}

@test "validate.sh checks all 8 bootstrap files" {
  for bf in AGENTS.md SOUL.md IDENTITY.md USER.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md; do
    run cat "$SCRIPT_PATH"
    [[ "$output" == *"$bf"* ]]
  done
}

@test "validate.sh exits 1 if no agent name provided" {
  # No agent arg, no dados_whitelabel
  run bash -c "export STATE_DIR='$STATE_DIR'; export HOME='$(mktemp -d)'; bash '$SCRIPT_PATH' 2>&1" || true
  [[ "$status" -ne 0 ]]
}

@test "validate.sh references validate-config.sh" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *"validate-config.sh"* ]]
}

@test "validate.sh exits based on STEP_FAIL" {
  run cat "$SCRIPT_PATH"
  [[ "$output" == *'STEP_FAIL'* ]]
  [[ "$output" == *'exit 1'* ]]
  [[ "$output" == *'exit 0'* ]]
}

# --- Behavioral Tests (mocked state) ---

# Helper: create a test HOME with dados_vps and apps structure
# common.sh sets STATE_DIR=$HOME/dados_vps, so we must set HOME
_setup_test_home() {
  TEST_HOME="$(mktemp -d)"
  mkdir -p "$TEST_HOME/dados_vps"
}

@test "validate.sh: missing state files lists which are missing" {
  _setup_test_home
  # Only create dados_whitelabel, skip dados_openclaw and dados_workspace
  echo "Agente: test-agent" > "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Apps Path: $TEST_APPS_DIR" >> "$TEST_HOME/dados_vps/dados_whitelabel"

  mkdir -p "$TEST_APPS_DIR/skills/test-skill"
  echo "# Test" > "$TEST_APPS_DIR/skills/test-skill/SKILL.md"
  mkdir -p "$TEST_APPS_DIR/workspace"
  for bf in AGENTS.md SOUL.md IDENTITY.md USER.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md; do
    touch "$TEST_APPS_DIR/workspace/$bf"
  done

  run bash -c "export HOME='$TEST_HOME'; bash '$SCRIPT_PATH' test-agent 2>&1" || true
  [[ "$output" == *"dados_openclaw"* ]]
  [[ "$output" == *"dados_workspace"* ]]
  rm -rf "$TEST_HOME" 2>/dev/null || true
}

@test "validate.sh: all state files present shows OK for state check" {
  _setup_test_home
  echo "Agente: test-agent" > "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Apps Path: $TEST_APPS_DIR" >> "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Porta: 19888" > "$TEST_HOME/dados_vps/dados_openclaw"
  echo "Workspace Path: $TEST_APPS_DIR/workspace" > "$TEST_HOME/dados_vps/dados_workspace"

  mkdir -p "$TEST_APPS_DIR/skills/test-skill"
  echo "# Test" > "$TEST_APPS_DIR/skills/test-skill/SKILL.md"
  mkdir -p "$TEST_APPS_DIR/workspace"
  for bf in AGENTS.md SOUL.md IDENTITY.md USER.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md; do
    touch "$TEST_APPS_DIR/workspace/$bf"
  done

  run bash -c "export HOME='$TEST_HOME'; bash '$SCRIPT_PATH' test-agent 2>&1" || true
  # Strip ANSI codes for reliable matching
  local clean_output
  clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$clean_output" == *"State files essenciais presentes"* ]]
  rm -rf "$TEST_HOME" 2>/dev/null || true
}

@test "validate.sh: missing workspace files lists which are missing" {
  _setup_test_home
  echo "Agente: test-agent" > "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Apps Path: $TEST_APPS_DIR" >> "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Porta: 19888" > "$TEST_HOME/dados_vps/dados_openclaw"
  echo "Workspace Path: $TEST_APPS_DIR/workspace" > "$TEST_HOME/dados_vps/dados_workspace"

  mkdir -p "$TEST_APPS_DIR/skills/test-skill"
  echo "# Test" > "$TEST_APPS_DIR/skills/test-skill/SKILL.md"
  mkdir -p "$TEST_APPS_DIR/workspace"
  touch "$TEST_APPS_DIR/workspace/AGENTS.md"
  touch "$TEST_APPS_DIR/workspace/SOUL.md"
  touch "$TEST_APPS_DIR/workspace/IDENTITY.md"

  run bash -c "export HOME='$TEST_HOME'; bash '$SCRIPT_PATH' test-agent 2>&1" || true
  local clean_output
  clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$clean_output" == *"Workspace incompleto"* ]]
  [[ "$clean_output" == *"TOOLS.md"* ]]
  [[ "$clean_output" == *"HEARTBEAT.md"* ]]
  rm -rf "$TEST_HOME" 2>/dev/null || true
}

@test "validate.sh: skills dir with SKILL.md shows count" {
  _setup_test_home
  echo "Agente: test-agent" > "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Apps Path: $TEST_APPS_DIR" >> "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Porta: 19888" > "$TEST_HOME/dados_vps/dados_openclaw"
  echo "Workspace Path: $TEST_APPS_DIR/workspace" > "$TEST_HOME/dados_vps/dados_workspace"

  mkdir -p "$TEST_APPS_DIR/skills/memory"
  echo "# Memory Skill" > "$TEST_APPS_DIR/skills/memory/SKILL.md"
  mkdir -p "$TEST_APPS_DIR/skills/planner"
  echo "# Planner Skill" > "$TEST_APPS_DIR/skills/planner/SKILL.md"

  mkdir -p "$TEST_APPS_DIR/workspace"
  for bf in AGENTS.md SOUL.md IDENTITY.md USER.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md; do
    touch "$TEST_APPS_DIR/workspace/$bf"
  done

  run bash -c "export HOME='$TEST_HOME'; bash '$SCRIPT_PATH' test-agent 2>&1" || true
  local clean_output
  clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$clean_output" == *"Skills instalados: 2"* ]]
  rm -rf "$TEST_HOME" 2>/dev/null || true
}

@test "validate.sh: missing skills dir shows FAIL" {
  _setup_test_home
  echo "Agente: test-agent" > "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Apps Path: $TEST_APPS_DIR" >> "$TEST_HOME/dados_vps/dados_whitelabel"
  echo "Porta: 19888" > "$TEST_HOME/dados_vps/dados_openclaw"
  echo "Workspace Path: $TEST_APPS_DIR/workspace" > "$TEST_HOME/dados_vps/dados_workspace"

  mkdir -p "$TEST_APPS_DIR/workspace"
  for bf in AGENTS.md SOUL.md IDENTITY.md USER.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md; do
    touch "$TEST_APPS_DIR/workspace/$bf"
  done

  run bash -c "export HOME='$TEST_HOME'; bash '$SCRIPT_PATH' test-agent 2>&1" || true
  local clean_output
  clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$clean_output" == *"skills nao encontrado"* ]]
  rm -rf "$TEST_HOME" 2>/dev/null || true
}
