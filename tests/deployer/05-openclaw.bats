#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/05-openclaw.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/05-openclaw.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  # Source libs com readonly removido
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/hints.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/env-detect.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/deploy.sh" 2>/dev/null || true)

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
# hint_dns_openclaw
# -----------------------------------------------------------------------------
@test "hint_dns_openclaw displays domain in DNS table" {
  run hint_dns_openclaw "gw.exemplo.com"
  [[ "$output" == *"gw.exemplo.com"* ]]
}

@test "hint_dns_openclaw shows DNS configuration header" {
  run hint_dns_openclaw "gw.test.com"
  [[ "$output" == *"DNS PARA OPENCLAW GATEWAY"* ]]
}

@test "hint_dns_openclaw shows dig verification command" {
  run hint_dns_openclaw "gw.test.com"
  [[ "$output" == *"dig gw.test.com +short"* ]]
}

@test "hint_dns_openclaw shows record type A" {
  run hint_dns_openclaw "gw.test.com"
  [[ "$output" == *"A"* ]]
}

@test "hint_dns_openclaw uses default domain when empty" {
  run hint_dns_openclaw
  [[ "$output" == *"gw.exemplo.com"* ]]
}

# -----------------------------------------------------------------------------
# hint_troubleshoot_openclaw
# -----------------------------------------------------------------------------
@test "hint_troubleshoot_openclaw shows systemctl status command" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"systemctl status openclaw"* ]]
}

@test "hint_troubleshoot_openclaw shows journalctl command" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"journalctl -u openclaw -f"* ]]
}

@test "hint_troubleshoot_openclaw shows ss port check" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"ss -tlnp | grep 18789"* ]]
}

@test "hint_troubleshoot_openclaw shows health check command" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"curl http://localhost:18789/health"* ]]
}

@test "hint_troubleshoot_openclaw shows custom port" {
  run hint_troubleshoot_openclaw "9999" ""
  [[ "$output" == *"9999"* ]]
}

@test "hint_troubleshoot_openclaw shows domain URL when provided" {
  run hint_troubleshoot_openclaw "18789" "gw.test.com"
  [[ "$output" == *"curl https://gw.test.com/health"* ]]
}

@test "hint_troubleshoot_openclaw shows restart command" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"systemctl restart openclaw"* ]]
}

@test "hint_troubleshoot_openclaw shows openclaw doctor" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"openclaw doctor"* ]]
}

@test "hint_troubleshoot_openclaw shows tailscale status" {
  run hint_troubleshoot_openclaw "18789" ""
  [[ "$output" == *"tailscale status"* ]]
}

@test "hint_troubleshoot_openclaw uses default port when empty" {
  run hint_troubleshoot_openclaw
  [[ "$output" == *"18789"* ]]
}

# -----------------------------------------------------------------------------
# dados_openclaw state file
# -----------------------------------------------------------------------------
@test "dados_openclaw file format is correct" {
  cat > "$STATE_DIR/dados_openclaw" << EOF
URL Gateway: https://gw.exemplo.com
Porta: 18789
Repo: https://github.com/openclaw/openclaw.git
Install Path: /opt/openclaw
Systemd Unit: /etc/systemd/system/openclaw.service
EOF

  [[ -f "$STATE_DIR/dados_openclaw" ]]
  run grep "URL Gateway:" "$STATE_DIR/dados_openclaw"
  [[ "$output" == *"https://gw.exemplo.com"* ]]
  run grep "Porta:" "$STATE_DIR/dados_openclaw"
  [[ "$output" == *"18789"* ]]
  run grep "Repo:" "$STATE_DIR/dados_openclaw"
  [[ "$output" == *"openclaw.git"* ]]
  run grep "Install Path:" "$STATE_DIR/dados_openclaw"
  [[ "$output" == *"/opt/openclaw"* ]]
  run grep "Systemd Unit:" "$STATE_DIR/dados_openclaw"
  [[ "$output" == *"openclaw.service"* ]]
}

@test "dados_openclaw file with custom port" {
  cat > "$STATE_DIR/dados_openclaw" << EOF
URL Gateway: https://gw.custom.com
Porta: 9999
Repo: https://github.com/custom/repo.git
Install Path: /opt/openclaw
Systemd Unit: /etc/systemd/system/openclaw.service
EOF

  run grep "Porta:" "$STATE_DIR/dados_openclaw"
  [[ "$output" == *"9999"* ]]
}

@test "dados_openclaw chmod 600 is enforceable" {
  touch "$STATE_DIR/dados_openclaw"
  chmod 600 "$STATE_DIR/dados_openclaw"
  local perms
  perms=$(stat -c "%a" "$STATE_DIR/dados_openclaw" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/dados_openclaw" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

# -----------------------------------------------------------------------------
# step_init for openclaw (13 steps)
# -----------------------------------------------------------------------------
@test "step_init sets STEP_TOTAL to 13 for openclaw" {
  step_init 13
  [[ "$STEP_TOTAL" -eq 13 ]]
  [[ "$STEP_CURRENT" -eq 0 ]]
}

# -----------------------------------------------------------------------------
# recursos gate (2 vCPU, 4GB)
# -----------------------------------------------------------------------------
@test "recursos function exists and is callable" {
  run type -t recursos
  [[ "$output" == "function" ]]
}

# -----------------------------------------------------------------------------
# verificar_stack function
# -----------------------------------------------------------------------------
@test "verificar_stack function exists" {
  run type -t verificar_stack
  [[ "$output" == "function" ]]
}

# -----------------------------------------------------------------------------
# conferindo_as_info for openclaw inputs
# -----------------------------------------------------------------------------
@test "conferindo_as_info displays openclaw domain" {
  run conferindo_as_info "Dominio=gw.exemplo.com" "Porta=18789" "Repositorio=https://github.com/openclaw/openclaw.git"
  [[ "$output" == *"gw.exemplo.com"* ]]
  [[ "$output" == *"18789"* ]]
  [[ "$output" == *"openclaw.git"* ]]
}

@test "conferindo_as_info displays CONFERINDO header" {
  run conferindo_as_info "Dominio=test.com"
  [[ "$output" == *"CONFERINDO"* ]]
}

# -----------------------------------------------------------------------------
# detectar_ambiente integration
# -----------------------------------------------------------------------------
@test "detectar_ambiente returns local or vps" {
  run detectar_ambiente
  [[ "$output" == "local" || "$output" == "vps" ]]
}

# -----------------------------------------------------------------------------
# log_init for openclaw
# -----------------------------------------------------------------------------
@test "log_init creates openclaw log file" {
  log_init_test() {
    local ferramenta="${1:-deployer}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_DIR}/${ferramenta}-${timestamp}.log"
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
  }
  log_init_test "openclaw"
  [[ -f "$LOG_FILE" ]]
  [[ "$LOG_FILE" == *"openclaw-"* ]]
}

# -----------------------------------------------------------------------------
# deployer.sh menu integration
# -----------------------------------------------------------------------------
@test "deployer.sh contains openclaw menu option" {
  run grep -c "OpenClaw Gateway" "$SCRIPT_DIR/deployer.sh"
  [[ "$output" -ge 1 ]]
}

@test "deployer.sh routes option 05 to 05-openclaw.sh" {
  run grep "05-openclaw.sh" "$SCRIPT_DIR/deployer.sh"
  [[ "$status" -eq 0 ]]
}

@test "deployer.sh menu option 05 is active (not EM BREVE)" {
  run grep "05.*EM BREVE" "$SCRIPT_DIR/deployer.sh"
  [[ "$status" -ne 0 ]]
}

# -----------------------------------------------------------------------------
# 05-openclaw.sh file structure
# -----------------------------------------------------------------------------
@test "05-openclaw.sh exists and is executable" {
  [[ -f "$SCRIPT_DIR/ferramentas/05-openclaw.sh" ]]
  [[ -x "$SCRIPT_DIR/ferramentas/05-openclaw.sh" ]]
}

@test "05-openclaw.sh has set -euo pipefail" {
  run grep "set -euo pipefail" "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh sources all required libs" {
  run grep 'source.*ui.sh' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
  run grep 'source.*logger.sh' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
  run grep 'source.*common.sh' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
  run grep 'source.*hints.sh' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
  run grep 'source.*env-detect.sh' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
  run grep 'source.*deploy.sh' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls log_init openclaw" {
  run grep 'log_init "openclaw"' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls step_init 13" {
  run grep 'step_init 13' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls recursos 2 4" {
  run grep 'recursos 2 4' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh checks dados_portainer" {
  run grep 'dados_portainer' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh checks node version >= 22" {
  run grep '22' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh verifies pnpm availability" {
  run grep 'command -v pnpm' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh uses conferindo_as_info" {
  run grep 'conferindo_as_info' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh clones to /opt/openclaw" {
  run grep '/opt/openclaw' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh runs pnpm install with retry" {
  run grep -c 'pnpm install' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$output" -ge 1 ]]
}

@test "05-openclaw.sh runs pnpm ui:build" {
  run grep 'pnpm ui:build' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh runs pnpm build" {
  run grep 'pnpm build' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh runs onboard" {
  run grep 'openclaw onboard --install-daemon' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh generates systemd unit" {
  run grep 'openclaw.service' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh systemd unit has correct After directive" {
  run grep 'After=network.target tailscaled.service' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh systemd unit has Restart=always" {
  run grep 'Restart=always' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh checks port availability with ss" {
  run grep 'ss -tlnp' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh checks port BEFORE systemd unit generation" {
  # Port check (STEP 10) must appear before systemd heredoc (STEP 11)
  local port_line systemd_line
  port_line=$(grep -n 'VERIFICAR PORTA LIVRE' "$SCRIPT_DIR/ferramentas/05-openclaw.sh" | head -1 | cut -d: -f1)
  systemd_line=$(grep -n 'GERAR SYSTEMD UNIT' "$SCRIPT_DIR/ferramentas/05-openclaw.sh" | head -1 | cut -d: -f1)
  [[ "$port_line" -lt "$systemd_line" ]]
}

@test "05-openclaw.sh uses pushd/popd instead of cd" {
  run grep 'pushd /opt/openclaw' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
  run grep 'popd' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh runs systemctl daemon-reload" {
  run grep 'systemctl daemon-reload' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh has health check with retry 5x" {
  run grep -c 'Health check' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$output" -ge 1 ]]
  run grep '1 2 3 4 5' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh saves dados_openclaw with chmod 600" {
  run grep 'chmod 600.*dados_openclaw' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls resumo_final" {
  run grep 'resumo_final' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls log_finish" {
  run grep 'log_finish' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls hint_troubleshoot_openclaw" {
  run grep 'hint_troubleshoot_openclaw' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh calls hint_dns_openclaw" {
  run grep 'hint_dns_openclaw' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}

@test "05-openclaw.sh default port is 18789" {
  run grep '18789' "$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ "$status" -eq 0 ]]
}
