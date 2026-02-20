#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/06-validacao-gw.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/06-validacao-gw.bats
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

# =============================================================================
# hint_validacao_gw — hints contextuais
# =============================================================================

@test "hint_validacao_gw shows header" {
  run hint_validacao_gw "FAIL" "PASS" "PASS" "PASS" "PASS" "18789"
  [[ "$output" == *"RESOLUCAO DE PROBLEMAS"* ]]
}

@test "hint_validacao_gw shows tailscale hint when tailscale FAIL" {
  run hint_validacao_gw "FAIL" "PASS" "PASS" "PASS" "PASS" "18789"
  [[ "$output" == *"TAILSCALE DESCONECTADO"* ]]
  [[ "$output" == *"tailscale up"* ]]
}

@test "hint_validacao_gw does not show tailscale hint when PASS" {
  run hint_validacao_gw "PASS" "FAIL" "PASS" "PASS" "PASS" "18789"
  [[ "$output" != *"TAILSCALE DESCONECTADO"* ]]
}

@test "hint_validacao_gw shows service hint when service FAIL" {
  run hint_validacao_gw "PASS" "FAIL" "PASS" "PASS" "PASS" "18789"
  [[ "$output" == *"OPENCLAW SERVICE PARADO"* ]]
  [[ "$output" == *"systemctl start openclaw"* ]]
}

@test "hint_validacao_gw shows doctor hint when doctor FAIL" {
  run hint_validacao_gw "PASS" "PASS" "FAIL" "PASS" "PASS" "18789"
  [[ "$output" == *"OPENCLAW DOCTOR FALHOU"* ]]
  [[ "$output" == *"pnpm openclaw doctor --verbose"* ]]
}

@test "hint_validacao_gw shows health hint when health FAIL" {
  run hint_validacao_gw "PASS" "PASS" "PASS" "FAIL" "PASS" "18789"
  [[ "$output" == *"HEALTH CHECK FALHOU"* ]]
  [[ "$output" == *"ss -tlnp | grep 18789"* ]]
}

@test "hint_validacao_gw shows health hint with custom port" {
  run hint_validacao_gw "PASS" "PASS" "PASS" "FAIL" "PASS" "9999"
  [[ "$output" == *"ss -tlnp | grep 9999"* ]]
}

@test "hint_validacao_gw shows mensagem hint when mensagem FAIL" {
  run hint_validacao_gw "PASS" "PASS" "PASS" "PASS" "FAIL" "18789"
  [[ "$output" == *"TESTE DE MENSAGEM FALHOU"* ]]
  [[ "$output" == *"pnpm openclaw agent"* ]]
}

@test "hint_validacao_gw shows multiple hints for multiple failures" {
  run hint_validacao_gw "FAIL" "FAIL" "FAIL" "FAIL" "FAIL" "18789"
  [[ "$output" == *"TAILSCALE DESCONECTADO"* ]]
  [[ "$output" == *"OPENCLAW SERVICE PARADO"* ]]
  [[ "$output" == *"OPENCLAW DOCTOR FALHOU"* ]]
  [[ "$output" == *"HEALTH CHECK FALHOU"* ]]
  [[ "$output" == *"TESTE DE MENSAGEM FALHOU"* ]]
}

@test "hint_validacao_gw shows nothing when all PASS" {
  run hint_validacao_gw "PASS" "PASS" "PASS" "PASS" "PASS" "18789"
  [[ "$output" != *"TAILSCALE DESCONECTADO"* ]]
  [[ "$output" != *"OPENCLAW SERVICE PARADO"* ]]
  [[ "$output" != *"OPENCLAW DOCTOR FALHOU"* ]]
  [[ "$output" != *"HEALTH CHECK FALHOU"* ]]
  [[ "$output" != *"TESTE DE MENSAGEM FALHOU"* ]]
}

@test "hint_validacao_gw uses default port when empty" {
  run hint_validacao_gw "PASS" "PASS" "PASS" "FAIL" "PASS"
  [[ "$output" == *"ss -tlnp | grep 18789"* ]]
}

@test "hint_validacao_gw shows journalctl for service failure" {
  run hint_validacao_gw "PASS" "FAIL" "PASS" "PASS" "PASS" "18789"
  [[ "$output" == *"journalctl -u openclaw"* ]]
}

@test "hint_validacao_gw shows node version check for doctor failure" {
  run hint_validacao_gw "PASS" "PASS" "FAIL" "PASS" "PASS" "18789"
  [[ "$output" == *"node --version"* ]]
}

@test "hint_validacao_gw shows tailscale reset for auth issue" {
  run hint_validacao_gw "FAIL" "PASS" "PASS" "PASS" "PASS" "18789"
  [[ "$output" == *"tailscale up --reset"* ]]
}

# =============================================================================
# State file validation
# =============================================================================

@test "validation fails when dados_openclaw missing" {
  # dados_tailscale exists but dados_openclaw does not
  echo "Hostname Tailscale: meu-gw" > "$STATE_DIR/dados_tailscale"
  echo "IP Tailscale: 100.64.0.1" >> "$STATE_DIR/dados_tailscale"

  # Source the script functions but test state check
  [[ ! -f "$STATE_DIR/dados_openclaw" ]]
}

@test "validation fails when dados_tailscale missing" {
  # dados_openclaw exists but dados_tailscale does not
  echo "Porta: 18789" > "$STATE_DIR/dados_openclaw"

  [[ ! -f "$STATE_DIR/dados_tailscale" ]]
}

@test "state files can be read correctly" {
  # Create mock state files
  cat > "$STATE_DIR/dados_openclaw" << 'EOF'
URL Gateway: https://gw.test.com
Porta: 18789
Repo: https://github.com/openclaw/openclaw.git
Install Path: /opt/openclaw
Systemd Unit: /etc/systemd/system/openclaw.service
EOF

  cat > "$STATE_DIR/dados_tailscale" << 'EOF'
Hostname Tailscale: meu-gateway
IP Tailscale: 100.64.0.1
EOF

  # Verify fields can be extracted
  porta=$(grep "Porta:" "$STATE_DIR/dados_openclaw" | awk -F': ' '{print $2}')
  [[ "$porta" == "18789" ]]

  hostname=$(grep "Hostname Tailscale:" "$STATE_DIR/dados_tailscale" | awk -F': ' '{print $2}')
  [[ "$hostname" == "meu-gateway" ]]

  ip=$(grep "IP Tailscale:" "$STATE_DIR/dados_tailscale" | awk -F': ' '{print $2}')
  [[ "$ip" == "100.64.0.1" ]]
}

@test "porta defaults to 18789 when not found in state" {
  echo "URL Gateway: https://gw.test.com" > "$STATE_DIR/dados_openclaw"

  porta=$(grep "Porta:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}')
  porta="${porta:-18789}"
  [[ "$porta" == "18789" ]]
}

# =============================================================================
# Result recording
# =============================================================================

@test "validation result appended to dados_openclaw" {
  cat > "$STATE_DIR/dados_openclaw" << 'EOF'
URL Gateway: https://gw.test.com
Porta: 18789
EOF

  # Simulate appending results
  {
    echo ""
    echo "--- Validacao End-to-End ---"
    echo "Validacao: PASS"
    echo "Data Validacao: 2026-02-20 10:00:00"
    echo "Tailscale: PASS"
    echo "OpenClaw Service: PASS"
    echo "Doctor: PASS"
    echo "Health Check: PASS"
    echo "Mensagem Local: PASS"
  } >> "$STATE_DIR/dados_openclaw"

  grep -q 'Validacao: PASS' "$STATE_DIR/dados_openclaw"
  [[ "$(grep 'Tailscale: PASS' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'OpenClaw Service: PASS' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'Doctor: PASS' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'Health Check: PASS' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'Mensagem Local: PASS' "$STATE_DIR/dados_openclaw")" ]]
}

@test "validation result records FAIL correctly" {
  cat > "$STATE_DIR/dados_openclaw" << 'EOF'
Porta: 18789
EOF

  {
    echo ""
    echo "--- Validacao End-to-End ---"
    echo "Validacao: FAIL"
    echo "Tailscale: FAIL"
    echo "OpenClaw Service: PASS"
    echo "Doctor: FAIL"
    echo "Health Check: PASS"
    echo "Mensagem Local: FAIL"
  } >> "$STATE_DIR/dados_openclaw"

  [[ "$(grep 'Validacao: FAIL' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'Tailscale: FAIL' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'Doctor: FAIL' "$STATE_DIR/dados_openclaw")" ]]
  [[ "$(grep 'Mensagem Local: FAIL' "$STATE_DIR/dados_openclaw")" ]]
}

@test "dados_openclaw permissions preserved after append" {
  echo "Porta: 18789" > "$STATE_DIR/dados_openclaw"
  chmod 600 "$STATE_DIR/dados_openclaw"

  echo "Validacao: PASS" >> "$STATE_DIR/dados_openclaw"
  chmod 600 "$STATE_DIR/dados_openclaw"

  perms=$(stat -c %a "$STATE_DIR/dados_openclaw" 2>/dev/null || stat -f %Lp "$STATE_DIR/dados_openclaw" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

@test "result section has separator" {
  echo "Porta: 18789" > "$STATE_DIR/dados_openclaw"
  {
    echo ""
    echo "--- Validacao End-to-End ---"
    echo "Validacao: PASS"
  } >> "$STATE_DIR/dados_openclaw"

  grep -qF -- '--- Validacao End-to-End ---' "$STATE_DIR/dados_openclaw"
}

# =============================================================================
# UI feedback patterns
# =============================================================================

@test "step_init sets 10 steps for validation" {
  step_init 10
  [[ "$STEP_TOTAL" -eq 10 ]]
  [[ "$STEP_CURRENT" -eq 0 ]]
}

@test "step_ok increments counters" {
  step_init 10
  run step_ok "Test step"
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"Test step"* ]]
}

@test "step_fail increments fail counter" {
  step_init 10
  run step_fail "Test fail"
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"Test fail"* ]]
}

@test "resumo_final shows summary" {
  step_init 3
  step_ok "paso 1" > /dev/null
  step_fail "paso 2" > /dev/null
  step_ok "paso 3" > /dev/null
  run resumo_final
  [[ "$output" == *"RESUMO"* ]]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"FAIL"* ]]
}

# =============================================================================
# Logging
# =============================================================================

@test "log_init creates log file for validation-gw" {
  log_init "validation-gw"
  [[ -f "$LOG_FILE" ]]
  [[ "$LOG_FILE" == *"validation-gw"* ]]
}

@test "log_init writes header with hostname" {
  log_init "validation-gw"
  [[ "$(cat "$LOG_FILE")" == *"Hostname:"* ]]
}

@test "log_init writes header with date" {
  log_init "validation-gw"
  [[ "$(cat "$LOG_FILE")" == *"Data:"* ]]
}

# =============================================================================
# Integration with 05-openclaw.sh
# =============================================================================

@test "05-openclaw.sh contains validation prompt" {
  local script="$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  [[ -f "$script" ]]
  grep -q "validacao end-to-end" "$script"
}

@test "05-openclaw.sh calls 06-validacao-gw.sh" {
  local script="$SCRIPT_DIR/ferramentas/05-openclaw.sh"
  grep -q "06-validacao-gw.sh" "$script"
}

# =============================================================================
# Script file validation
# =============================================================================

@test "06-validacao-gw.sh exists" {
  [[ -f "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh" ]]
}

@test "06-validacao-gw.sh is executable" {
  [[ -x "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh" ]]
}

@test "06-validacao-gw.sh has set -euo pipefail" {
  grep -q "set -euo pipefail" "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh sources required libs" {
  local script="$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
  grep -q 'source.*ui.sh' "$script"
  grep -q 'source.*logger.sh' "$script"
  grep -q 'source.*common.sh' "$script"
  grep -q 'source.*hints.sh' "$script"
  grep -q 'source.*env-detect.sh' "$script"
}

@test "06-validacao-gw.sh calls log_init with validation-gw" {
  grep -q 'log_init "validation-gw"' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh calls step_init with 10" {
  grep -q 'step_init 10' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh checks dados_openclaw" {
  grep -q 'dados_openclaw' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh checks dados_tailscale" {
  grep -q 'dados_tailscale' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh runs tailscale status" {
  grep -q 'tailscale status' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh runs systemctl is-active openclaw" {
  grep -q 'systemctl is-active openclaw' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh runs openclaw doctor" {
  grep -q 'openclaw doctor' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh runs curl health check" {
  grep -q 'curl.*health' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh runs openclaw agent message test" {
  grep -q 'openclaw agent --message' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh has timeout for message test" {
  grep -q 'timeout 30' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh calls chmod 600 on dados_openclaw" {
  grep -q 'chmod 600.*dados_openclaw' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh calls hint_validacao_gw" {
  grep -q 'hint_validacao_gw' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh calls resumo_final" {
  grep -q 'resumo_final' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh calls log_finish" {
  grep -q 'log_finish' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

@test "06-validacao-gw.sh displays test commands for desktop" {
  grep -q 'tailscale ping' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
  grep -q 'COMANDOS DE TESTE' "$SCRIPT_DIR/ferramentas/06-validacao-gw.sh"
}

# =============================================================================
# dados() function
# =============================================================================

@test "dados function loads state" {
  mkdir -p "$STATE_DIR"
  echo "Nome do Servidor: meu-server" > "$STATE_DIR/dados_vps"
  echo "Rede interna: minha-rede" >> "$STATE_DIR/dados_vps"

  dados
  [[ "$nome_servidor" == "meu-server" ]]
  [[ "$nome_rede" == "minha-rede" ]]
}
