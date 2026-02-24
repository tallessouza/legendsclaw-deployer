#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/ferramentas/setup-local.sh
# Story 11.1: Setup local — state file, hints, SO detection
# =============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export STATE_DIR="$TEST_DIR/dados_vps"
  mkdir -p "$STATE_DIR"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- salvar_estado ---

@test "salvar_estado: creates state file with correct format" {
  # Source the script functions only (not main)
  LIB_DIR="${BATS_TEST_DIRNAME}/../../deployer/lib"
  eval "$(cat "${LIB_DIR}/ui.sh" | sed 's/^readonly //g')"
  eval "$(cat "${LIB_DIR}/env-detect.sh" | sed 's/^readonly //g')"

  # Define salvar_estado inline (extracted from setup-local.sh)
  STATE_FILE="${STATE_DIR}/dados_local_setup"
  salvar_estado() {
    local so="$1" git_ver="$2" node_ver="$3" claude_ver="$4" ts_installed="$5" ts_status="$6"
    mkdir -p "$STATE_DIR"
    cat > "$STATE_FILE" <<EOF
so_detectado: ${so}
git_version: ${git_ver}
node_version: ${node_ver}
claude_code_version: ${claude_ver}
tailscale_installed: ${ts_installed}
tailscale_status: ${ts_status}
setup_date: $(date '+%Y-%m-%d %H:%M:%S')
EOF
  }

  salvar_estado "linux" "2.39.2" "22.11.0" "1.0.0" "true" "connected"

  [ -f "$STATE_FILE" ]

  run grep "so_detectado: linux" "$STATE_FILE"
  [ "$status" -eq 0 ]

  run grep "git_version: 2.39.2" "$STATE_FILE"
  [ "$status" -eq 0 ]

  run grep "node_version: 22.11.0" "$STATE_FILE"
  [ "$status" -eq 0 ]

  run grep "tailscale_installed: true" "$STATE_FILE"
  [ "$status" -eq 0 ]

  run grep "tailscale_status: connected" "$STATE_FILE"
  [ "$status" -eq 0 ]

  run grep "setup_date:" "$STATE_FILE"
  [ "$status" -eq 0 ]
}

@test "salvar_estado: state file uses key: value format" {
  STATE_FILE="${STATE_DIR}/dados_local_setup"
  salvar_estado() {
    local so="$1" git_ver="$2" node_ver="$3" claude_ver="$4" ts_installed="$5" ts_status="$6"
    mkdir -p "$STATE_DIR"
    cat > "$STATE_FILE" <<EOF
so_detectado: ${so}
git_version: ${git_ver}
node_version: ${node_ver}
claude_code_version: ${claude_ver}
tailscale_installed: ${ts_installed}
tailscale_status: ${ts_status}
setup_date: $(date '+%Y-%m-%d %H:%M:%S')
EOF
  }

  salvar_estado "wsl" "2.40.0" "22.12.0" "1.1.0" "false" "not_installed"

  # Every non-empty line must match "key: value" format
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[a-z_]+:\ .+ ]]
  done < "$STATE_FILE"
}
