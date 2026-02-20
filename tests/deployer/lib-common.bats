#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/lib/common.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/lib-common.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  export STATE_DIR="$TEST_DIR/dados_vps"
  mkdir -p "$STATE_DIR"

  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)
  # Override STATE_DIR after source
  STATE_DIR="$TEST_DIR/dados_vps"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# -----------------------------------------------------------------------------
# dados()
# -----------------------------------------------------------------------------
@test "dados loads nome_servidor from dados_vps" {
  echo "Nome do Servidor: meuserver" > "$STATE_DIR/dados_vps"
  echo "Rede interna: minha_rede" >> "$STATE_DIR/dados_vps"
  dados
  [ "$nome_servidor" = "meuserver" ]
  [ "$nome_rede" = "minha_rede" ]
}

@test "dados returns empty when file is empty" {
  touch "$STATE_DIR/dados_vps"
  dados
  [ -z "$nome_servidor" ]
  [ -z "$nome_rede" ]
}

@test "dados returns empty when file does not exist" {
  rm -f "$STATE_DIR/dados_vps"
  dados
  [ -z "$nome_servidor" ]
  [ -z "$nome_rede" ]
}

# -----------------------------------------------------------------------------
# validar_senha()
# -----------------------------------------------------------------------------
@test "validar_senha accepts valid password" {
  run validar_senha "MinhaS3nha"
  [ "$status" -eq 0 ]
}

@test "validar_senha rejects short password" {
  run validar_senha "Ab1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"curta"* ]]
}

@test "validar_senha rejects password without uppercase" {
  run validar_senha "minhas3nha"
  [ "$status" -eq 1 ]
  [[ "$output" == *"maiuscula"* ]]
}

@test "validar_senha rejects password without number" {
  run validar_senha "MinhaSenha"
  [ "$status" -eq 1 ]
  [[ "$output" == *"numero"* ]]
}

@test "validar_senha accepts exactly 8 chars" {
  run validar_senha "Abcdef1X"
  [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# conferindo_as_info()
# -----------------------------------------------------------------------------
@test "conferindo_as_info displays fields" {
  run conferindo_as_info "Dominio=painel.example.com" "Usuario=admin"
  [[ "$output" == *"CONFERINDO"* ]]
  [[ "$output" == *"Dominio"* ]]
  [[ "$output" == *"painel.example.com"* ]]
  [[ "$output" == *"Usuario"* ]]
  [[ "$output" == *"admin"* ]]
}

# -----------------------------------------------------------------------------
# verificar_stack() — mocked
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# criar_banco_postgres_da_stack() — input validation
# -----------------------------------------------------------------------------
@test "criar_banco_postgres_da_stack rejects invalid db name with uppercase" {
  run criar_banco_postgres_da_stack "Evolution"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalido"* ]]
}

@test "criar_banco_postgres_da_stack rejects db name with special chars" {
  run criar_banco_postgres_da_stack "db; DROP TABLE users"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalido"* ]]
}

@test "criar_banco_postgres_da_stack rejects db name starting with number" {
  run criar_banco_postgres_da_stack "1evolution"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalido"* ]]
}

@test "criar_banco_postgres_da_stack accepts valid db name" {
  # Mock docker to simulate container not found (tests validation passes)
  docker() { return 1; }
  export -f docker
  run criar_banco_postgres_da_stack "evolution"
  # Will fail on "container not found" but NOT on validation
  [[ "$output" == *"Container Postgres nao encontrado"* ]]
  unset -f docker
}

# -----------------------------------------------------------------------------
# verificar_stack() — mocked
# -----------------------------------------------------------------------------
@test "verificar_stack returns 1 when docker not available" {
  # Mock docker to not exist
  docker() { return 1; }
  export -f docker
  run verificar_stack "traefik"
  [ "$status" -eq 1 ]
  unset -f docker
}
