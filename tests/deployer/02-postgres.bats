#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/ferramentas/02-postgres.sh
# Story 1.3: PostgreSQL (PgVector) deployment
# =============================================================================

setup() {
  # Source common functions
  eval "$(cat "${BATS_TEST_DIRNAME}/../../deployer/lib/common.sh" | sed 's/^readonly //g')"
}

# --- verificar_container_postgres ---

@test "verificar_container_postgres: returns 0 when postgres container exists" {
  docker() {
    if [[ "$1" == "ps" ]]; then
      echo "postgres_postgres.1.abc123"
    elif [[ "$1" == "service" ]]; then
      echo ""
    fi
  }
  export -f docker

  run verificar_container_postgres
  [ "$status" -eq 0 ]
}

@test "verificar_container_postgres: returns 1 when no postgres found" {
  docker() {
    echo ""
  }
  export -f docker

  run verificar_container_postgres
  [ "$status" -eq 1 ]
}

# --- pegar_senha_postgres ---

@test "pegar_senha_postgres: reads from dados_postgres file" {
  STATE_DIR=$(mktemp -d)
  cat > "$STATE_DIR/dados_postgres" << EOF
[ POSTGRESQL ]

Senha: MyStr0ngPass
Porta: 5432
EOF

  pegar_senha_postgres
  [ "$senha_postgres" = "MyStr0ngPass" ]

  rm -rf "$STATE_DIR"
}

@test "pegar_senha_postgres: returns 1 when no file exists" {
  STATE_DIR="/nonexistent"
  HOME="/nonexistent"

  run pegar_senha_postgres
  [ "$status" -eq 1 ]
}

# --- criar_banco_postgres_da_stack ---

@test "criar_banco_postgres_da_stack: creates database successfully" {
  docker() {
    case "$1" in
      ps) echo "abc123" ;;
      exec)
        if [[ "$*" == *"-lqt"* ]]; then
          echo " template0 | postgres"
        elif [[ "$*" == *"CREATE DATABASE"* ]]; then
          return 0
        fi
        ;;
    esac
  }
  export -f docker

  run criar_banco_postgres_da_stack "evolution"
  [ "$status" -eq 0 ]
  [[ "$output" == *"criado com sucesso"* ]]
}

@test "criar_banco_postgres_da_stack: skips if database already exists" {
  docker() {
    case "$1" in
      ps) echo "abc123" ;;
      exec)
        if [[ "$*" == *"-lqt"* ]]; then
          echo " evolution | postgres"
        fi
        ;;
    esac
  }
  export -f docker

  run criar_banco_postgres_da_stack "evolution"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ja existe"* ]]
}
