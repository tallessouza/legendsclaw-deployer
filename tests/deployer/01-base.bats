#!/usr/bin/env bats

# =============================================================================
# Testes de integracao para deployer/ferramentas/01-base.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/01-base.bats
# Nota: Testa funcoes individuais, nao o fluxo completo (requer VPS real)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  mkdir -p "$TEST_DIR/dados_vps"

  # Source todas as libs (sem readonly)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/hints.sh" 2>/dev/null || true)

  STATE_DIR="$TEST_DIR/dados_vps"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# -----------------------------------------------------------------------------
# Integration: step_init + step_ok/fail/skip sequence
# -----------------------------------------------------------------------------
@test "full step sequence matches 01-base total of 13" {
  step_init 13
  step_ok "recursos"
  step_ok "estado"
  step_ok "hints"
  step_ok "inputs"
  step_ok "swarm"
  step_ok "network"
  step_ok "traefik yaml"
  step_ok "portainer yaml"
  step_ok "deploy traefik"
  step_ok "deploy portainer"
  step_ok "admin account"
  step_ok "credenciais"
  step_ok "finalizado"
  [ "$STEP_CURRENT" -eq 13 ]
  [ "$STEP_TOTAL" -eq 13 ]
  [ "$STEP_OK" -eq 13 ]
}

# -----------------------------------------------------------------------------
# Integration: dados + state files
# -----------------------------------------------------------------------------
@test "dados loads after credentials are saved" {
  echo "Nome do Servidor: test-server" > "$STATE_DIR/dados_vps"
  echo "Rede interna: test_net" >> "$STATE_DIR/dados_vps"
  dados
  [ "$nome_servidor" = "test-server" ]
  [ "$nome_rede" = "test_net" ]
}

# -----------------------------------------------------------------------------
# Integration: validar_senha with various inputs
# -----------------------------------------------------------------------------
@test "password validation covers all AC requirements" {
  # AC: minimo 8 chars, 1 maiuscula, 1 numero
  run validar_senha "Short1A"
  [ "$status" -eq 1 ]  # too short

  run validar_senha "nouppercase1"
  [ "$status" -eq 1 ]  # no uppercase

  run validar_senha "NoNumber"
  [ "$status" -eq 1 ]  # no number

  run validar_senha "ValidPass1"
  [ "$status" -eq 0 ]  # valid
}

# -----------------------------------------------------------------------------
# Integration: hints display all required ports (AC: 3)
# -----------------------------------------------------------------------------
@test "hint_firewall shows all 8 required ports" {
  run hint_firewall
  [[ "$output" == *"22"* ]]
  [[ "$output" == *"80"* ]]
  [[ "$output" == *"443"* ]]
  [[ "$output" == *"9443"* ]]
  [[ "$output" == *"2377"* ]]
  [[ "$output" == *"7946"* ]]
  [[ "$output" == *"4789"* ]]
  [[ "$output" == *"41641"* ]]
}

# -----------------------------------------------------------------------------
# Integration: conferindo_as_info shows all fields (AC: 2)
# -----------------------------------------------------------------------------
@test "conferindo_as_info shows all 6 input fields" {
  run conferindo_as_info \
    "Dominio Portainer=painel.test.com" \
    "Email SSL=test@test.com" \
    "Usuario=admin" \
    "Senha=********" \
    "Nome Servidor=test-01" \
    "Rede Overlay=test_net"
  [[ "$output" == *"painel.test.com"* ]]
  [[ "$output" == *"test@test.com"* ]]
  [[ "$output" == *"admin"* ]]
  [[ "$output" == *"test-01"* ]]
  [[ "$output" == *"test_net"* ]]
}

# -----------------------------------------------------------------------------
# File structure: verify 01-base.sh exists and is executable
# -----------------------------------------------------------------------------
@test "01-base.sh exists and is executable" {
  [ -f "$SCRIPT_DIR/ferramentas/01-base.sh" ]
  [ -x "$SCRIPT_DIR/ferramentas/01-base.sh" ]
}

# -----------------------------------------------------------------------------
# File structure: verify all lib files exist
# -----------------------------------------------------------------------------
@test "all lib files exist" {
  [ -f "$SCRIPT_DIR/lib/ui.sh" ]
  [ -f "$SCRIPT_DIR/lib/logger.sh" ]
  [ -f "$SCRIPT_DIR/lib/common.sh" ]
  [ -f "$SCRIPT_DIR/lib/deploy.sh" ]
  [ -f "$SCRIPT_DIR/lib/hints.sh" ]
}

# -----------------------------------------------------------------------------
# File structure: verify deployer.sh exists
# -----------------------------------------------------------------------------
@test "deployer.sh exists and is executable" {
  [ -f "$SCRIPT_DIR/deployer.sh" ]
  [ -x "$SCRIPT_DIR/deployer.sh" ]
}
