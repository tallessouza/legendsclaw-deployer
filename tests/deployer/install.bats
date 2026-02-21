#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/install.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/install.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

# -----------------------------------------------------------------------------
# Helper: extrai funcoes do install.sh para teste isolado
# -----------------------------------------------------------------------------
setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  export LOG_DIR="$TEST_DIR/legendsclaw-logs"

  # Source apenas as funcoes (feedback, cleanup), sem executar o main flow
  # Remove readonly, set -euo pipefail, exec redirect, e trap/main logic
  source <(sed \
    -e 's/^readonly //g' \
    -e '/^set -euo pipefail/d' \
    -e '/^exec > >(tee/d' \
    -e '/^trap /d' \
    -e '/^mkdir -p "\$LOG_DIR"/d' \
    -e '/^# ===/,/^feedback/{ /^feedback/!d }' \
    "$INSTALL_SCRIPT" 2>/dev/null | head -80 || true)

  # Reset contadores para cada teste
  CURRENT_STEP=0
  TOTAL_STEPS=8
  COUNT_OK=0
  COUNT_SKIP=0
  COUNT_FAIL=0

  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/install-test.log"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Testes: Arquivo e permissoes
# -----------------------------------------------------------------------------
@test "install.sh existe" {
  [[ -f "$INSTALL_SCRIPT" ]]
}

@test "install.sh e executavel" {
  [[ -x "$INSTALL_SCRIPT" ]]
}

@test "install.sh tem shebang correto" {
  head -1 "$INSTALL_SCRIPT" | grep -q '#!/usr/bin/env bash'
}

@test "install.sh tem set -euo pipefail" {
  grep -q 'set -euo pipefail' "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Constantes obrigatorias
# -----------------------------------------------------------------------------
@test "define INSTALL_DIR=/opt/legendsclaw" {
  grep -q 'INSTALL_DIR="/opt/legendsclaw"' "$INSTALL_SCRIPT"
}

@test "define TOTAL_STEPS=8" {
  grep -q 'TOTAL_STEPS=8' "$INSTALL_SCRIPT"
}

@test "define REPO_URL" {
  grep -q 'REPO_URL=' "$INSTALL_SCRIPT"
}

@test "define LOG_DIR em legendsclaw-logs" {
  grep -q 'LOG_DIR="$HOME/legendsclaw-logs"' "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Cores ANSI definidas inline
# -----------------------------------------------------------------------------
@test "define cores ANSI inline (RED, GREEN, YELLOW, NC)" {
  grep -q "RED=" "$INSTALL_SCRIPT"
  grep -q "GREEN=" "$INSTALL_SCRIPT"
  grep -q "YELLOW=" "$INSTALL_SCRIPT"
  grep -q "NC=" "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Feedback visual (pattern SetupOrion)
# -----------------------------------------------------------------------------
@test "feedback OK exibe formato N/TOTAL - [ OK ]" {
  run feedback "OK" "Teste de sucesso"
  [[ "$output" == *"1/8"* ]]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"Teste de sucesso"* ]]
}

@test "feedback FAIL exibe formato N/TOTAL - [ FAIL ]" {
  run feedback "FAIL" "Teste de falha"
  [[ "$output" == *"1/8"* ]]
  [[ "$output" == *"FAIL"* ]]
}

@test "feedback SKIP exibe formato N/TOTAL - [ SKIP ]" {
  run feedback "SKIP" "Teste de skip"
  [[ "$output" == *"1/8"* ]]
  [[ "$output" == *"SKIP"* ]]
}

@test "feedback incrementa CURRENT_STEP" {
  feedback "OK" "step1"
  feedback "OK" "step2"
  [[ "$CURRENT_STEP" -eq 2 ]]
}

@test "feedback incrementa contadores corretos" {
  feedback "OK" "ok1"
  feedback "FAIL" "fail1"
  feedback "SKIP" "skip1"
  [[ "$COUNT_OK" -eq 1 ]]
  [[ "$COUNT_FAIL" -eq 1 ]]
  [[ "$COUNT_SKIP" -eq 1 ]]
}

# -----------------------------------------------------------------------------
# Testes: Trap handlers presentes
# -----------------------------------------------------------------------------
@test "install.sh define trap EXIT" {
  grep -q "trap 'cleanup_on_fail' EXIT" "$INSTALL_SCRIPT"
}

@test "install.sh define trap INT TERM" {
  grep -q "trap.*INT TERM" "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Steps presentes no script
# -----------------------------------------------------------------------------
@test "step 1: verifica root (EUID)" {
  grep -q 'EUID' "$INSTALL_SCRIPT"
}

@test "step 2: verifica OS (/etc/os-release)" {
  grep -q '/etc/os-release' "$INSTALL_SCRIPT"
}

@test "step 3: verifica conectividade (curl github.com)" {
  grep -q 'curl.*github.com' "$INSTALL_SCRIPT"
}

@test "step 4: instala git se ausente" {
  grep -q 'apt-get.*install.*git' "$INSTALL_SCRIPT"
}

@test "step 5: git clone ou git pull" {
  grep -q 'git clone' "$INSTALL_SCRIPT"
  grep -q 'git.*pull' "$INSTALL_SCRIPT"
}

@test "step 6: executa setup.sh" {
  grep -q 'bash.*setup.sh' "$INSTALL_SCRIPT"
}

@test "step 7: exibe instrucoes finais (cd /opt/legendsclaw)" {
  grep -q 'cd.*INSTALL_DIR.*deployer.sh' "$INSTALL_SCRIPT"
}

@test "step 8: exibe resumo final" {
  grep -q 'RESUMO' "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Idempotencia (logica clone/pull)
# -----------------------------------------------------------------------------
@test "verifica .git antes de pull (idempotencia)" {
  grep -q '\.git' "$INSTALL_SCRIPT"
}

@test "trata diretorio existente sem .git como erro" {
  grep -q 'nao e um repositorio git' "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Logging
# -----------------------------------------------------------------------------
@test "logging usa tee para stdout+arquivo" {
  grep -q 'tee -a' "$INSTALL_SCRIPT"
}

@test "log inclui header com data e hostname" {
  grep -q 'hostname' "$INSTALL_SCRIPT"
  grep -q 'Data:' "$INSTALL_SCRIPT"
}

# -----------------------------------------------------------------------------
# Testes: Syntax check
# -----------------------------------------------------------------------------
@test "install.sh passa bash -n (syntax check)" {
  run bash -n "$INSTALL_SCRIPT"
  [[ "$status" -eq 0 ]]
}
