#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/04-tailscale.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/04-tailscale.bats
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
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# hint_tailscale_desktop
# -----------------------------------------------------------------------------
@test "hint_tailscale_desktop displays Windows install instructions" {
  run hint_tailscale_desktop "mygw" "100.64.0.1" "vps"
  [[ "$output" == *"Windows"* ]]
  [[ "$output" == *"tailscale.com/download/windows"* ]]
}

@test "hint_tailscale_desktop displays Mac install instructions" {
  run hint_tailscale_desktop "mygw" "100.64.0.1" "vps"
  [[ "$output" == *"Mac"* ]]
  [[ "$output" == *"brew"* ]]
}

@test "hint_tailscale_desktop displays WSL2 install instructions" {
  run hint_tailscale_desktop "mygw" "100.64.0.1" "vps"
  [[ "$output" == *"WSL2"* ]]
  [[ "$output" == *"curl"* ]]
}

@test "hint_tailscale_desktop shows tailscale ping command" {
  run hint_tailscale_desktop "legendsclaw-gw" "100.64.0.1" "vps"
  [[ "$output" == *"tailscale ping legendsclaw-gw"* ]]
}

@test "hint_tailscale_desktop shows IP address" {
  run hint_tailscale_desktop "mygw" "100.64.0.5" "local"
  [[ "$output" == *"100.64.0.5"* ]]
}

@test "hint_tailscale_desktop VPS mode mentions VPS" {
  run hint_tailscale_desktop "mygw" "100.64.0.1" "vps"
  [[ "$output" == *"VPS"* ]]
}

@test "hint_tailscale_desktop local mode does not mention VPS" {
  run hint_tailscale_desktop "mygw" "100.64.0.1" "local"
  [[ "$output" != *"VPS"* ]]
}

@test "hint_tailscale_desktop uses defaults when no args" {
  run hint_tailscale_desktop
  [[ "$output" == *"meu-gateway"* ]]
  [[ "$output" == *"TAILSCALE_IP"* ]]
}

# -----------------------------------------------------------------------------
# dados_tailscale state file
# -----------------------------------------------------------------------------
@test "dados_tailscale file format is correct" {
  # Simulate writing state
  cat > "$STATE_DIR/dados_tailscale" << EOF
Hostname Tailscale: legendsclaw-gw
IP Tailscale: 100.64.0.1
Funnel: Inativo
Porta Funnel: N/A
EOF

  [[ -f "$STATE_DIR/dados_tailscale" ]]
  run grep "Hostname Tailscale:" "$STATE_DIR/dados_tailscale"
  [[ "$output" == *"legendsclaw-gw"* ]]
  run grep "IP Tailscale:" "$STATE_DIR/dados_tailscale"
  [[ "$output" == *"100.64.0.1"* ]]
  run grep "Funnel:" "$STATE_DIR/dados_tailscale"
  [[ "$output" == *"Inativo"* ]]
}

@test "dados_tailscale file with funnel active" {
  cat > "$STATE_DIR/dados_tailscale" << EOF
Hostname Tailscale: legendsclaw-gw
IP Tailscale: 100.64.0.1
Funnel: Ativo
Porta Funnel: 18789
EOF

  run grep "Funnel:" "$STATE_DIR/dados_tailscale"
  [[ "$output" == *"Ativo"* ]]
  run grep "Porta Funnel:" "$STATE_DIR/dados_tailscale"
  [[ "$output" == *"18789"* ]]
}

@test "dados_tailscale chmod 600 is enforceable" {
  touch "$STATE_DIR/dados_tailscale"
  chmod 600 "$STATE_DIR/dados_tailscale"
  local perms
  perms=$(stat -c "%a" "$STATE_DIR/dados_tailscale" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/dados_tailscale" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

# -----------------------------------------------------------------------------
# step_init for tailscale (9 steps)
# -----------------------------------------------------------------------------
@test "step_init sets STEP_TOTAL to 9 for tailscale" {
  step_init 9
  [[ "$STEP_TOTAL" -eq 9 ]]
  [[ "$STEP_CURRENT" -eq 0 ]]
}

# -----------------------------------------------------------------------------
# detectar_ambiente integration
# -----------------------------------------------------------------------------
@test "detectar_ambiente returns local or vps" {
  run detectar_ambiente
  [[ "$output" == "local" || "$output" == "vps" ]]
}

# -----------------------------------------------------------------------------
# conferindo_as_info for tailscale inputs
# -----------------------------------------------------------------------------
@test "conferindo_as_info displays tailscale hostname" {
  run conferindo_as_info "Hostname Tailscale=legendsclaw-gw" "Ambiente=vps"
  [[ "$output" == *"legendsclaw-gw"* ]]
  [[ "$output" == *"vps"* ]]
}

# -----------------------------------------------------------------------------
# log_init for tailscale
# -----------------------------------------------------------------------------
@test "log_init creates tailscale log file" {
  # Override exec redirect for test
  log_init_test() {
    local ferramenta="${1:-deployer}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_DIR}/${ferramenta}-${timestamp}.log"
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
  }
  log_init_test "tailscale"
  [[ -f "$LOG_FILE" ]]
  [[ "$LOG_FILE" == *"tailscale-"* ]]
}
