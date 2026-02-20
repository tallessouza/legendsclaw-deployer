#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 02: PostgreSQL (PgVector)
# Pattern: 8-Step Tool Lifecycle (SetupOrion)
# Story 1.3: Dual-mode (local compose / VPS stack deploy)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source lib
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/deploy.sh"
source "${SCRIPT_DIR}/lib/hints.sh"
source "${SCRIPT_DIR}/lib/env-detect.sh"

# Constantes
readonly FERRAMENTA="postgres"
readonly TOTAL=8

main() {
  log_init "$FERRAMENTA"
  setup_trap
  step_init "$TOTAL"

  local ambiente
  ambiente=$(detectar_ambiente)

  echo -e "${UI_CYAN}${UI_BOLD}[02] PostgreSQL (PgVector)${UI_NC}"
  echo -e "  Modo: ${ambiente}"
  echo ""

  # =========================================================================
  # STEP 1: RESOURCE GATE (AC: 1)
  # =========================================================================
  if recursos 1 1; then
    step_ok "Gate de recursos (1 vCPU, 1GB RAM)"
  else
    step_fail "Gate de recursos — servidor nao atende e usuario recusou"
    exit 1
  fi

  # =========================================================================
  # STEP 2: LOAD STATE
  # =========================================================================
  dados
  step_ok "Estado carregado"

  # =========================================================================
  # STEP 3: CHECK IF ALREADY EXISTS
  # =========================================================================
  if verificar_container_postgres; then
    echo "  Postgres ja esta rodando."
    pegar_senha_postgres > /dev/null 2>&1
    step_skip "Postgres (ja instalado)"
    resumo_final
    log_finish
    exit 0
  fi

  # =========================================================================
  # STEP 4: INPUT COLLECTION — Senha Postgres (loop confirmado)
  # =========================================================================
  local senha_pg=""

  while true; do
    echo ""
    while true; do
      read -rsp "Senha para o usuario postgres: " senha_pg
      echo ""
      if validar_senha "$senha_pg"; then
        break
      fi
      echo "Tente novamente."
    done

    conferindo_as_info \
      "Senha Postgres=********"

    read -rp "A informacao esta correta? (s/n): " confirmacao
    if [[ "$confirmacao" =~ ^[Ss]$ ]]; then
      break
    fi
    echo "Vamos recoletar..."
  done

  step_ok "Inputs coletados e confirmados"

  # =========================================================================
  # STEP 5: GENERATE YAML (AC: 6)
  # =========================================================================
  if [[ "$ambiente" == "vps" ]]; then
    cat > "$HOME/postgres.yaml" << EOL
version: "3.7"

services:
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      - POSTGRES_PASSWORD=${senha_pg}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${nome_rede:-legendsclaw_net}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  postgres_data:
    external: true
    name: postgres_data

networks:
  ${nome_rede:-legendsclaw_net}:
    external: true
    name: ${nome_rede:-legendsclaw_net}
EOL
  else
    cat > "$HOME/postgres.yaml" << EOL
version: "3.7"

services:
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      - POSTGRES_PASSWORD=${senha_pg}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

volumes:
  postgres_data:
EOL
  fi

  chmod 600 "$HOME/postgres.yaml"
  step_ok "~/postgres.yaml gerado (PgVector pg16, modo ${ambiente}, chmod 600)"

  # =========================================================================
  # STEP 6: DEPLOY (AC: 6)
  # =========================================================================
  if [[ "$ambiente" == "vps" ]]; then
    # Criar volume externo se nao existir
    docker volume create postgres_data 2>/dev/null || true
  fi

  deploy_stack "postgres" "$HOME/postgres.yaml"
  ROLLBACK_CMD="docker stack rm postgres 2>/dev/null || docker compose -f $HOME/postgres.yaml down 2>/dev/null || true; rm -f $HOME/postgres.yaml"
  ROLLBACK_DESC="Remover stack Postgres e YAML gerado"
  step_ok "Postgres deployado (modo ${ambiente})"

  # =========================================================================
  # STEP 7: VERIFY — Wait polling (AC: 11)
  # =========================================================================
  echo "  Aguardando Postgres ficar online..."
  if wait_deploy "postgres" "postgres"; then
    step_ok "Postgres online"
  else
    step_fail "Postgres nao ficou online (timeout 5min)"
    exit 1
  fi

  # =========================================================================
  # STEP 8: FINALIZE — Salvar credenciais (AC: 12)
  # =========================================================================
  mkdir -p "$HOME/dados_vps"

  cat > "$HOME/dados_vps/dados_postgres" << EOL
[ POSTGRESQL ]

Senha: ${senha_pg}
Porta: 5432
Imagem: pgvector/pgvector:pg16
EOL

  chmod 600 "$HOME/dados_vps/dados_postgres"

  step_ok "Credenciais salvas em ~/dados_vps/dados_postgres (chmod 600)"

  resumo_final

  echo -e "${UI_BOLD}PostgreSQL:${UI_NC}"
  echo -e "  Host: postgres (interno) / localhost:5432 (local)"
  echo -e "  Usuario: postgres"
  echo -e "  Imagem: pgvector/pgvector:pg16"
  echo -e "  Credenciais: ~/dados_vps/dados_postgres"
  echo -e "  Log: ${LOG_FILE}"
  echo ""

  log_finish

  if [[ "$STEP_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
