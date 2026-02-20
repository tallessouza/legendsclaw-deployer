#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/setup.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/setup.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"

# -----------------------------------------------------------------------------
# Helper: extrai funcoes do script sem readonly e sem main
# -----------------------------------------------------------------------------
setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  export LOG_DIR="$TEST_DIR/legendsclaw-logs"
  export STATE_DIR="$TEST_DIR/dados_vps"

  # Source funcoes removendo readonly declarations e main execution
  source <(sed 's/^readonly //g; /^main "\$@"/d; /^main$/d' "$SETUP_SCRIPT" 2>/dev/null || true)

  # Reset contadores para cada teste
  CURRENT_STEP=0
  COUNT_OK=0
  COUNT_SKIP=0
  COUNT_FAIL=0
}

teardown() {
  rm -rf "$TEST_DIR"
}

# -----------------------------------------------------------------------------
# Testes: Sistema de Feedback Visual
# -----------------------------------------------------------------------------
@test "feedback OK exibe formato correto N/TOTAL - [ OK ]" {
  run feedback "OK" "Teste de sucesso"
  [[ "$output" == *"1/15"* ]]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"Teste de sucesso"* ]]
}

@test "feedback FAIL exibe formato correto N/TOTAL - [ FAIL ]" {
  run feedback "FAIL" "Teste de falha"
  [[ "$output" == *"1/15"* ]]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"Teste de falha"* ]]
}

@test "feedback SKIP exibe formato correto N/TOTAL - [ SKIP ]" {
  run feedback "SKIP" "Teste de skip"
  [[ "$output" == *"1/15"* ]]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"Teste de skip"* ]]
}

@test "feedback incrementa contador de steps" {
  feedback "OK" "Step 1" >/dev/null
  [[ "$CURRENT_STEP" -eq 1 ]]
  feedback "OK" "Step 2" >/dev/null
  [[ "$CURRENT_STEP" -eq 2 ]]
}

@test "feedback incrementa contadores OK/SKIP/FAIL corretamente" {
  feedback "OK" "ok1" >/dev/null
  feedback "SKIP" "skip1" >/dev/null
  feedback "FAIL" "fail1" >/dev/null
  feedback "OK" "ok2" >/dev/null
  [[ "$COUNT_OK" -eq 2 ]]
  [[ "$COUNT_SKIP" -eq 1 ]]
  [[ "$COUNT_FAIL" -eq 1 ]]
}

# -----------------------------------------------------------------------------
# Testes: Sistema de Logging
# -----------------------------------------------------------------------------
@test "setup_logging cria diretorio de logs" {
  setup_logging >/dev/null 2>&1 || true
  [[ -d "$LOG_DIR" ]]
}

# -----------------------------------------------------------------------------
# Testes: Verificacao de Root
# -----------------------------------------------------------------------------
@test "check_root detecta usuario nao-root via funcao id" {
  # Nao podemos sobrescrever EUID (readonly do bash), entao testamos
  # que a funcao existe e executa sem crash quando somos root ou nao
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    run check_root
    [[ "$output" == *"OK"* ]]
  else
    run check_root
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"FAIL"* ]]
  fi
}

# -----------------------------------------------------------------------------
# Testes: Verificacao de OS
# -----------------------------------------------------------------------------
@test "check_os detecta OS sem falhar" {
  run check_os
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
}

# -----------------------------------------------------------------------------
# Testes: Estrutura de Estado
# -----------------------------------------------------------------------------
@test "create_state_structure cria ~/dados_vps/ com placeholders" {
  create_state_structure >/dev/null
  [[ -d "$STATE_DIR" ]]
  [[ -f "$STATE_DIR/dados_vps" ]]
  [[ -f "$STATE_DIR/dados_portainer" ]]
  [[ -f "$STATE_DIR/dados_openclaw" ]]
  [[ -f "$STATE_DIR/dados_evolution" ]]
  [[ -f "$STATE_DIR/dados_n8n" ]]
  [[ -f "$STATE_DIR/dados_postgres" ]]
  [[ -f "$STATE_DIR/dados_tailscale" ]]
}

@test "create_state_structure skip se ja existe" {
  mkdir -p "$STATE_DIR"
  run create_state_structure
  [[ "$output" == *"SKIP"* ]]
}

# -----------------------------------------------------------------------------
# Testes: install_if_missing
# -----------------------------------------------------------------------------
@test "install_if_missing faz SKIP para comando existente" {
  run install_if_missing "bash" "true" "Bash shell"
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"ja instalado"* ]]
}

@test "install_if_missing tenta instalar para comando inexistente" {
  _fake_install() { return 0; }
  export -f _fake_install
  run install_if_missing "comando_inexistente_xyz_123" "_fake_install" "Comando Fake"
  [[ "$output" == *"OK"* ]]
}

@test "install_if_missing reporta FAIL quando instalacao falha" {
  _fake_fail() { return 1; }
  export -f _fake_fail
  run install_if_missing "comando_inexistente_xyz_456" "_fake_fail" "Comando que Falha"
  [[ "$output" == *"FAIL"* ]]
}

# -----------------------------------------------------------------------------
# Testes: Resumo Final
# -----------------------------------------------------------------------------
@test "show_summary exibe contadores com falhas" {
  COUNT_OK=10
  COUNT_SKIP=3
  COUNT_FAIL=2
  run show_summary
  [[ "$output" == *"10"* ]]
  [[ "$output" == *"3"* ]]
  [[ "$output" == *"2"* ]]
  [[ "$output" == *"ATENCAO"* ]]
}

@test "show_summary mostra sucesso quando sem falhas" {
  COUNT_OK=13
  COUNT_SKIP=2
  COUNT_FAIL=0
  run show_summary
  [[ "$output" == *"Bootstrap completo"* ]]
}
