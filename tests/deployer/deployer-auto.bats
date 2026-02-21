#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/deployer-auto.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/deployer-auto.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
RUNNER="$SCRIPT_DIR/deployer-auto.sh"

setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  mkdir -p "$TEST_DIR/legendsclaw-logs"

  # Criar config valido de teste
  export TEST_CONFIG="$TEST_DIR/test-config.env"
  cat > "$TEST_CONFIG" << 'EOF'
base.dominio_portainer: painel.test.com
base.email_ssl: test@test.com
base.user_portainer: admin
base.pass_portainer: Test1234!
base.nome_servidor: test-01
base.nome_rede: test_net
EOF
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# --help
# -----------------------------------------------------------------------------
@test "--help exibe usage e sai com exit 0" {
  run bash "$RUNNER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--config"* ]]
  [[ "$output" == *"--from"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

# -----------------------------------------------------------------------------
# --config obrigatorio
# -----------------------------------------------------------------------------
@test "sem --config falha com exit 1" {
  run bash "$RUNNER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--config e obrigatorio"* ]]
}

# -----------------------------------------------------------------------------
# config inexistente
# -----------------------------------------------------------------------------
@test "config inexistente falha com exit 1" {
  run bash "$RUNNER" --config "$TEST_DIR/nao-existe.env"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nao encontrado"* ]]
}

# -----------------------------------------------------------------------------
# flag desconhecida
# -----------------------------------------------------------------------------
@test "flag desconhecida falha com exit 1" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --invalido
  [ "$status" -eq 1 ]
  [[ "$output" == *"Flag desconhecida"* ]]
}

# -----------------------------------------------------------------------------
# --from invalido
# -----------------------------------------------------------------------------
@test "--from com numero invalido falha" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --from 99
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalido"* ]]
}

# -----------------------------------------------------------------------------
# --to invalido
# -----------------------------------------------------------------------------
@test "--to com numero invalido falha" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --to 00
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalido"* ]]
}

# -----------------------------------------------------------------------------
# --only com numero invalido
# -----------------------------------------------------------------------------
@test "--only com numero invalido falha" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --only "01,99"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalido"* ]]
}

# -----------------------------------------------------------------------------
# --only + --from conflito
# -----------------------------------------------------------------------------
@test "--only combinado com --from falha" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --only "01,02" --from 03
  [ "$status" -eq 1 ]
  [[ "$output" == *"nao pode ser combinado"* ]]
}

# -----------------------------------------------------------------------------
# --dry-run
# -----------------------------------------------------------------------------
@test "--dry-run lista ferramentas sem executar" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"[01]"* ]]
  [[ "$output" == *"[15]"* ]]
  [[ "$output" == *"Nenhuma ferramenta sera executada"* ]]
}

@test "--dry-run com --from/--to filtra ferramentas" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --from 03 --to 05
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"[03]"* ]]
  [[ "$output" == *"[05]"* ]]
  [[ "$output" != *"[01]"* ]]
  [[ "$output" != *"[15]"* ]]
}

@test "--dry-run com --only filtra ferramentas" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --only "01,04,15"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"[01]"* ]]
  [[ "$output" == *"[04]"* ]]
  [[ "$output" == *"[15]"* ]]
  [[ "$output" != *"[07]"* ]]
}

@test "--dry-run mostra contagem de chaves" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Chaves no config: 6"* ]]
}

# -----------------------------------------------------------------------------
# --from validos
# -----------------------------------------------------------------------------
@test "--from 01 aceita" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --from 01
  [ "$status" -eq 0 ]
}

@test "--from 15 aceita" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --from 15
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ferramentas a executar (1)"* ]]
}

# -----------------------------------------------------------------------------
# --to valido
# -----------------------------------------------------------------------------
@test "--to 03 lista apenas 01-03" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --to 03
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ferramentas a executar (3)"* ]]
}

# -----------------------------------------------------------------------------
# --from + --to range
# -----------------------------------------------------------------------------
@test "--from 05 --to 07 lista 3 ferramentas" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --from 05 --to 07
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ferramentas a executar (3)"* ]]
  [[ "$output" == *"[05]"* ]]
  [[ "$output" == *"[06]"* ]]
  [[ "$output" == *"[07]"* ]]
}

# -----------------------------------------------------------------------------
# --config com path relativo funciona
# -----------------------------------------------------------------------------
@test "--config com path relativo aceita" {
  # Dry-run com path relativo
  cd "$TEST_DIR"
  run bash "$RUNNER" --config "test-config.env" --dry-run
  [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# --only order natural
# -----------------------------------------------------------------------------
@test "--only executa na ordem natural (01 antes de 15)" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --dry-run --only "15,01,07"
  [ "$status" -eq 0 ]
  # Verificar que 01 aparece antes de 07 e 07 antes de 15
  local pos_01 pos_07 pos_15
  pos_01=$(echo "$output" | grep -n "\[01\]" | head -1 | cut -d: -f1)
  pos_07=$(echo "$output" | grep -n "\[07\]" | head -1 | cut -d: -f1)
  pos_15=$(echo "$output" | grep -n "\[15\]" | head -1 | cut -d: -f1)
  [ "$pos_01" -lt "$pos_07" ]
  [ "$pos_07" -lt "$pos_15" ]
}

# -----------------------------------------------------------------------------
# --config sem argumento falha
# -----------------------------------------------------------------------------
@test "--config sem argumento falha" {
  run bash "$RUNNER" --config
  [ "$status" -eq 1 ]
  [[ "$output" == *"requer um argumento"* ]]
}

@test "--from sem argumento falha" {
  run bash "$RUNNER" --config "$TEST_CONFIG" --from
  [ "$status" -eq 1 ]
  [[ "$output" == *"requer um argumento"* ]]
}
