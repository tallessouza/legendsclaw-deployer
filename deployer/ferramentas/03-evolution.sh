#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 03: Evolution API + Redis
# Pattern: 8-Step Tool Lifecycle (SetupOrion)
# Story 1.3: Dual-mode (local compose / VPS stack deploy)
# Reference: SetupOrion ferramenta_evolution() linhas 6135-6570
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
readonly FERRAMENTA="evolution"
readonly TOTAL=10

main() {
  log_init "$FERRAMENTA"
  step_init "$TOTAL"

  local ambiente
  ambiente=$(detectar_ambiente)

  echo -e "${UI_CYAN}${UI_BOLD}[03] Evolution API + Redis${UI_NC}"
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
  # STEP 3-4: INPUT COLLECTION + HINTS (AC: 3, 4) — Loop confirmado
  # =========================================================================
  local url_evolution=""

  while true; do
    echo ""
    if [[ "$ambiente" == "vps" ]]; then
      read -rp "Dominio para a Evolution API (ex: api.exemplo.com): " url_evolution
    else
      url_evolution="localhost"
      echo "Modo local: Evolution acessivel em http://localhost:8080"
    fi

    if [[ "$ambiente" == "vps" ]]; then
      conferindo_as_info \
        "Dominio Evolution=${url_evolution}"

      read -rp "A informacao esta correta? (s/n): " confirmacao
      if [[ "$confirmacao" =~ ^[Ss]$ ]]; then
        break
      fi
      echo "Vamos recoletar..."
    else
      break
    fi
  done

  # Hint DNS com o dominio real coletado (apenas VPS)
  if [[ "$ambiente" == "vps" ]]; then
    hint_dns "$url_evolution"
    step_ok "Hints de DNS exibidos para ${url_evolution}"
  else
    step_skip "Hints de DNS (modo local — nao necessario)"
  fi

  step_ok "Inputs coletados e confirmados"

  # =========================================================================
  # STEP 5: RESOLVE DEPENDENCIES — Postgres (AC: 5, 7)
  # =========================================================================
  echo -e "\n  Verificando dependencias..."

  if verificar_container_postgres; then
    echo "  Postgres encontrado"
    pegar_senha_postgres > /dev/null 2>&1
    step_ok "Postgres ja instalado — senha obtida"
  else
    echo "  Postgres nao encontrado — instalando automaticamente..."
    bash "${SCRIPT_DIR}/ferramentas/02-postgres.sh"
    pegar_senha_postgres > /dev/null 2>&1
    step_ok "Postgres instalado via dependencia cascata"
  fi

  # Criar banco evolution
  echo "  Criando banco 'evolution'..."
  criar_banco_postgres_da_stack "evolution"
  step_ok "Banco 'evolution' criado no Postgres"

  # =========================================================================
  # STEP 6: GENERATE API KEY (AC: 8)
  # =========================================================================
  local apikeyglobal
  apikeyglobal=$(openssl rand -hex 16)

  # =========================================================================
  # STEP 7: GENERATE YAML (AC: 9)
  # =========================================================================
  local server_url
  local evolution_port=""

  if [[ "$ambiente" == "vps" ]]; then
    server_url="https://${url_evolution}"
  else
    server_url="http://localhost:8080"
    evolution_port="      - \"8080:8080\""
  fi

  if [[ "$ambiente" == "vps" ]]; then
    cat > "$HOME/evolution.yaml" << EOL
version: "3.7"
services:

  evolution_api:
    image: evoapicloud/evolution-api:v2.2.3
    volumes:
      - evolution_instances:/evolution/instances
    networks:
      - ${nome_rede:-legendsclaw_net}
    environment:
      ## Configuracoes Gerais
      - SERVER_URL=${server_url}
      - AUTHENTICATION_API_KEY=${apikeyglobal}
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - DEL_INSTANCE=false
      - QRCODE_LIMIT=1902
      - LANGUAGE=pt-BR
      ## Cliente
      - CONFIG_SESSION_PHONE_CLIENT=LegendsClaw
      - CONFIG_SESSION_PHONE_NAME=Chrome
      ## Banco de Dados
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:${senha_postgres}@postgres:5432/evolution
      - DATABASE_CONNECTION_CLIENT_NAME=evolution
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - DATABASE_SAVE_DATA_LABELS=true
      - DATABASE_SAVE_DATA_HISTORIC=true
      ## Integracoes
      - N8N_ENABLED=true
      - EVOAI_ENABLED=true
      - OPENAI_ENABLED=true
      - DIFY_ENABLED=true
      - TYPEBOT_ENABLED=true
      - TYPEBOT_API_VERSION=latest
      - CHATWOOT_ENABLED=true
      - CHATWOOT_MESSAGE_READ=true
      - CHATWOOT_MESSAGE_DELETE=true
      ## Cache Redis
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://evolution_redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=false
      - CACHE_LOCAL_ENABLED=false
      ## S3 (desabilitado)
      - S3_ENABLED=false
      ## WhatsApp Business
      - WA_BUSINESS_TOKEN_WEBHOOK=evolution
      - WA_BUSINESS_URL=https://graph.facebook.com
      - WA_BUSINESS_VERSION=v23.0
      - WA_BUSINESS_LANGUAGE=pt_BR
      ## Telemetria
      - TELEMETRY=false
      ## WebSocket
      - WEBSOCKET_ENABLED=false
      - WEBSOCKET_GLOBAL_EVENTS=false
      ## SQS (desabilitado)
      - SQS_ENABLED=false
      ## RabbitMQ (desabilitado)
      - RABBITMQ_ENABLED=false
      ## Webhook
      - WEBHOOK_GLOBAL_ENABLED=false
      ## Provider
      - PROVIDER_ENABLED=false
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=1
        - traefik.http.routers.evolution.rule=Host(\`${url_evolution}\`)
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.routers.evolution.priority=1
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.service=evolution
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.services.evolution.loadbalancer.passHostHeader=true

  evolution_redis:
    image: redis:7-alpine
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - evolution_redis:/data
    networks:
      - ${nome_rede:-legendsclaw_net}
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  evolution_instances:
    external: true
    name: evolution_instances
  evolution_redis:
    external: true
    name: evolution_redis

networks:
  ${nome_rede:-legendsclaw_net}:
    external: true
    name: ${nome_rede:-legendsclaw_net}
EOL
  else
    # Modo local — docker compose (sem Traefik, sem overlay)
    cat > "$HOME/evolution.yaml" << EOL
version: "3.7"
services:

  evolution_api:
    image: evoapicloud/evolution-api:v2.2.3
    volumes:
      - evolution_instances:/evolution/instances
    ports:
      - "8080:8080"
    environment:
      ## Configuracoes Gerais
      - SERVER_URL=${server_url}
      - AUTHENTICATION_API_KEY=${apikeyglobal}
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - DEL_INSTANCE=false
      - QRCODE_LIMIT=1902
      - LANGUAGE=pt-BR
      ## Cliente
      - CONFIG_SESSION_PHONE_CLIENT=LegendsClaw
      - CONFIG_SESSION_PHONE_NAME=Chrome
      ## Banco de Dados
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:${senha_postgres}@postgres:5432/evolution
      - DATABASE_CONNECTION_CLIENT_NAME=evolution
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - DATABASE_SAVE_DATA_LABELS=true
      - DATABASE_SAVE_DATA_HISTORIC=true
      ## Integracoes
      - N8N_ENABLED=true
      - EVOAI_ENABLED=true
      - OPENAI_ENABLED=true
      - DIFY_ENABLED=true
      - TYPEBOT_ENABLED=true
      - TYPEBOT_API_VERSION=latest
      - CHATWOOT_ENABLED=true
      - CHATWOOT_MESSAGE_READ=true
      - CHATWOOT_MESSAGE_DELETE=true
      ## Cache Redis
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://evolution_redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=false
      - CACHE_LOCAL_ENABLED=false
      ## S3 (desabilitado)
      - S3_ENABLED=false
      ## WhatsApp Business
      - WA_BUSINESS_TOKEN_WEBHOOK=evolution
      - WA_BUSINESS_URL=https://graph.facebook.com
      - WA_BUSINESS_VERSION=v23.0
      - WA_BUSINESS_LANGUAGE=pt_BR
      ## Telemetria
      - TELEMETRY=false
      ## WebSocket
      - WEBSOCKET_ENABLED=false
      - WEBSOCKET_GLOBAL_EVENTS=false
      ## SQS (desabilitado)
      - SQS_ENABLED=false
      ## RabbitMQ (desabilitado)
      - RABBITMQ_ENABLED=false
      ## Webhook
      - WEBHOOK_GLOBAL_ENABLED=false
      ## Provider
      - PROVIDER_ENABLED=false
    depends_on:
      - evolution_redis

  evolution_redis:
    image: redis:7-alpine
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - evolution_redis:/data

volumes:
  evolution_instances:
  evolution_redis:
EOL
  fi

  chmod 600 "$HOME/evolution.yaml"
  step_ok "~/evolution.yaml gerado (Evolution API + Redis, modo ${ambiente}, chmod 600)"

  # =========================================================================
  # STEP 8: DEPLOY (AC: 10)
  # =========================================================================
  if [[ "$ambiente" == "vps" ]]; then
    # Criar volumes externos se nao existirem
    docker volume create evolution_instances 2>/dev/null || true
    docker volume create evolution_redis 2>/dev/null || true
  fi

  # Pull images
  echo "  Baixando imagens..."
  pull "redis:7-alpine" || true
  pull "evoapicloud/evolution-api:v2.2.3" || true

  deploy_stack "evolution" "$HOME/evolution.yaml"
  step_ok "Evolution API deployada (modo ${ambiente})"

  # =========================================================================
  # STEP 9: VERIFY — Wait polling (AC: 11)
  # =========================================================================
  echo "  Aguardando services ficarem online..."
  if wait_deploy "evolution" "evolution_redis" "evolution_api"; then
    step_ok "Evolution API + Redis online"
  else
    step_fail "Services nao ficaram online (timeout 5min)"
    exit 1
  fi

  # =========================================================================
  # STEP 10: FINALIZE — Salvar credenciais (AC: 12)
  # =========================================================================
  mkdir -p "$HOME/dados_vps"

  if [[ "$ambiente" == "vps" ]]; then
    cat > "$HOME/dados_vps/dados_evolution" << EOL
[ EVOLUTION API ]

Manager Evolution: https://${url_evolution}/manager

BaseUrl: https://${url_evolution}

Global API Key: ${apikeyglobal}
EOL
  else
    cat > "$HOME/dados_vps/dados_evolution" << EOL
[ EVOLUTION API ]

Manager Evolution: http://localhost:8080/manager

BaseUrl: http://localhost:8080

Global API Key: ${apikeyglobal}
EOL
  fi

  chmod 600 "$HOME/dados_vps/dados_evolution"

  step_ok "Credenciais salvas em ~/dados_vps/dados_evolution (chmod 600)"

  resumo_final

  echo -e "${UI_BOLD}Evolution API:${UI_NC}"
  if [[ "$ambiente" == "vps" ]]; then
    echo -e "  Manager: https://${url_evolution}/manager"
    echo -e "  BaseUrl: https://${url_evolution}"
  else
    echo -e "  Manager: http://localhost:8080/manager"
    echo -e "  BaseUrl: http://localhost:8080"
  fi
  echo -e "  Global API Key: ${apikeyglobal}"
  echo -e "  Credenciais: ~/dados_vps/dados_evolution"
  echo -e "  Log: ${LOG_FILE}"
  echo ""

  log_finish

  if [[ "$STEP_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
