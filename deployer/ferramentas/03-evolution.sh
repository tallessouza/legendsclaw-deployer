#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 03: Evolution API + Redis
# Pattern: 14-Step Tool Lifecycle (SetupOrion)
# Story 1.3: Dual-mode (local compose / VPS stack deploy)
# Story 5.1: WhatsApp + Webhook integration (conditional on OpenClaw Gateway)
# Reference: SetupOrion ferramenta_evolution() linhas 6135-6570
# Features: Multi-instância, Webhook granular, RabbitMQ, S3, Provider, WhatsApp
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source lib
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/deploy.sh"
source "${SCRIPT_DIR}/lib/hints.sh"
source "${SCRIPT_DIR}/lib/env-detect.sh"
source "${SCRIPT_DIR}/lib/evolution-api.sh"

# Constantes
readonly FERRAMENTA="evolution"
readonly TOTAL=14

main() {
  log_init "$FERRAMENTA"
  step_init "$TOTAL"

  local ambiente
  ambiente=$(detectar_ambiente)

  echo -e "${UI_CYAN}${UI_BOLD}[03] Evolution API + Redis${UI_NC}"
  echo -e "  Modo: ${ambiente}"
  echo ""

  # =========================================================================
  # STEP 1: RESOURCE GATE
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
  # STEP 3: CHECK OPENCLAW DEPENDENCY (Story 5.1)
  # =========================================================================
  local OPENCLAW_AVAILABLE=false
  local url_openclaw=""
  local porta_openclaw=""

  if [[ -f "$HOME/dados_vps/dados_openclaw" ]]; then
    url_openclaw=$(grep "URL:" "$HOME/dados_vps/dados_openclaw" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d ' ')
    porta_openclaw=$(grep "Porta:" "$HOME/dados_vps/dados_openclaw" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d ' ')
    if [[ -n "$url_openclaw" ]]; then
      OPENCLAW_AVAILABLE=true
      step_ok "OpenClaw Gateway encontrado (${url_openclaw}:${porta_openclaw:-18789})"
    else
      step_skip "dados_openclaw existe mas URL vazia — modo standalone"
    fi
  else
    step_skip "OpenClaw Gateway nao encontrado — modo standalone (sem WhatsApp)"
  fi

  # =========================================================================
  # STEP 4: MULTI-INSTANCIA — Detectar stacks existentes
  # =========================================================================
  local sufixo=""
  local stack_name="evolution"
  local instance_label="evolution"

  if [[ "$ambiente" == "vps" ]]; then
    local existing_stacks
    existing_stacks=$(docker stack ls --format '{{.Name}}' 2>/dev/null | grep -E '^evolution' || true)

    if [[ -n "$existing_stacks" ]]; then
      echo ""
      echo -e "  ${UI_YELLOW}Instancias Evolution existentes:${UI_NC}"
      echo "$existing_stacks" | while read -r s; do echo "    - $s"; done
      echo ""

      while true; do
        read -rp "Nome para a nova instancia (ex: cliente1, loja2): " instance_name
        instance_name=$(echo "$instance_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

        if [[ ! "$instance_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
          echo "  Nome invalido. Use apenas letras minusculas, numeros e underscore. Deve comecar com letra."
          continue
        fi

        sufixo="_${instance_name}"
        stack_name="evolution${sufixo}"
        instance_label="evolution${sufixo}"

        # Verificar se ja existe
        if echo "$existing_stacks" | grep -qx "$stack_name"; then
          echo "  Stack '$stack_name' ja existe. Escolha outro nome."
          continue
        fi

        break
      done
    fi
  else
    # Modo local: verificar se ja existe compose evolution
    local existing_local
    existing_local=$(docker compose ls --format json 2>/dev/null | grep -o '"evolution[^"]*"' || true)

    if [[ -n "$existing_local" ]]; then
      echo ""
      echo -e "  ${UI_YELLOW}Instancias Evolution existentes (local):${UI_NC}"
      echo "$existing_local" | tr -d '"' | while read -r s; do echo "    - $s"; done
      echo ""

      while true; do
        read -rp "Nome para a nova instancia (ex: cliente1, loja2): " instance_name
        instance_name=$(echo "$instance_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

        if [[ ! "$instance_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
          echo "  Nome invalido. Use apenas letras minusculas, numeros e underscore. Deve comecar com letra."
          continue
        fi

        sufixo="_${instance_name}"
        stack_name="evolution${sufixo}"
        instance_label="evolution${sufixo}"
        break
      done
    fi
  fi

  step_ok "Instancia: ${instance_label}"

  # =========================================================================
  # STEP 5: INPUT COLLECTION + HINTS — Loop confirmado
  # =========================================================================
  local url_evolution=""
  local numero_whatsapp=""

  while true; do
    echo ""
    if [[ "$ambiente" == "vps" ]]; then
      read -rp "Dominio para a Evolution API (ex: api.exemplo.com): " url_evolution
    else
      url_evolution="localhost"
      echo "Modo local: Evolution acessivel em http://localhost:8080"
    fi

    # Coletar numero WhatsApp (apenas se OpenClaw disponivel)
    if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then
      echo ""
      echo "  OpenClaw Gateway detectado — integracao WhatsApp disponivel."
      while true; do
        read -rp "Numero WhatsApp (formato: 5511999999999, sem + ou espacos): " numero_whatsapp
        if [[ "$numero_whatsapp" =~ ^[0-9]{10,15}$ ]]; then
          break
        else
          echo "  Formato invalido. Use apenas digitos (10-15 caracteres). Ex: 5511999999999"
        fi
      done
    fi

    if [[ "$ambiente" == "vps" ]]; then
      local conf_args=("Instancia=${instance_label}" "Dominio Evolution=${url_evolution}")
      if [[ -n "$numero_whatsapp" ]]; then
        conf_args+=("Numero WhatsApp=${numero_whatsapp}")
      fi
      conferindo_as_info "${conf_args[@]}"

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
  # STEP 6: HINTS WHATSAPP PREP (Story 5.1, condicional)
  # =========================================================================
  if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then
    hint_whatsapp_prep
    step_ok "Hints de preparacao WhatsApp exibidos"
  else
    step_skip "Hints WhatsApp (OpenClaw nao disponivel)"
  fi

  # =========================================================================
  # STEP 7: RESOLVE DEPENDENCIES — Postgres
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

  # Criar banco com sufixo
  local db_name="evolution${sufixo}"
  echo "  Criando banco '${db_name}'..."
  criar_banco_postgres_da_stack "$db_name"
  step_ok "Banco '${db_name}' criado no Postgres"

  # =========================================================================
  # STEP 8: GENERATE API KEY
  # =========================================================================
  local apikeyglobal
  apikeyglobal=$(openssl rand -hex 16)

  # =========================================================================
  # STEP 9: GENERATE YAML
  # =========================================================================
  local server_url
  local yaml_file="$HOME/evolution${sufixo}.yaml"

  if [[ "$ambiente" == "vps" ]]; then
    server_url="https://${url_evolution}"
  else
    server_url="http://localhost:8080"
  fi

  if [[ "$ambiente" == "vps" ]]; then
    cat > "$yaml_file" << EOL
version: "3.7"
services:

  evolution${sufixo}_api:
    image: evoapicloud/evolution-api:v2.2.3
    volumes:
      - evolution${sufixo}_instances:/evolution/instances
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
      - DATABASE_CONNECTION_URI=postgresql://postgres:${senha_postgres}@postgres:5432/evolution${sufixo}
      - DATABASE_CONNECTION_CLIENT_NAME=evolution${sufixo}
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
      - CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=
      - CHATWOOT_IMPORT_PLACEHOLDER_MEDIA_MESSAGE=false
      ## Cache Redis
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://evolution${sufixo}_redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=false
      - CACHE_LOCAL_ENABLED=false
      ## S3 (desabilitado — configurar endpoint para ativar)
      - S3_ENABLED=false
      - S3_ACCESS_KEY=
      - S3_SECRET_KEY=
      - S3_BUCKET=evolution
      - S3_PORT=443
      - S3_ENDPOINT=
      - S3_USE_SSL=true
      ## WhatsApp Business
      - WA_BUSINESS_TOKEN_WEBHOOK=evolution${sufixo}
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
      - SQS_ACCESS_KEY_ID=
      - SQS_SECRET_ACCESS_KEY=
      - SQS_ACCOUNT_ID=
      - SQS_REGION=
      ## RabbitMQ (desabilitado — ativar para escala horizontal)
      - RABBITMQ_ENABLED=false
      - RABBITMQ_FRAME_MAX=8192
      - RABBITMQ_URI=amqp://USER:PASS@rabbitmq:5672/evolution${sufixo}
      - RABBITMQ_EXCHANGE_NAME=evolution
      - RABBITMQ_GLOBAL_ENABLED=false
      - RABBITMQ_EVENTS_APPLICATION_STARTUP=false
      - RABBITMQ_EVENTS_INSTANCE_CREATE=false
      - RABBITMQ_EVENTS_INSTANCE_DELETE=false
      - RABBITMQ_EVENTS_QRCODE_UPDATED=false
      - RABBITMQ_EVENTS_SEND_MESSAGE_UPDATE=false
      - RABBITMQ_EVENTS_MESSAGES_SET=false
      - RABBITMQ_EVENTS_MESSAGES_UPSERT=true
      - RABBITMQ_EVENTS_MESSAGES_EDITED=false
      - RABBITMQ_EVENTS_MESSAGES_UPDATE=false
      - RABBITMQ_EVENTS_MESSAGES_DELETE=false
      - RABBITMQ_EVENTS_SEND_MESSAGE=false
      - RABBITMQ_EVENTS_CONTACTS_SET=false
      - RABBITMQ_EVENTS_CONTACTS_UPSERT=false
      - RABBITMQ_EVENTS_CONTACTS_UPDATE=false
      - RABBITMQ_EVENTS_PRESENCE_UPDATE=false
      - RABBITMQ_EVENTS_CHATS_SET=false
      - RABBITMQ_EVENTS_CHATS_UPSERT=false
      - RABBITMQ_EVENTS_CHATS_UPDATE=false
      - RABBITMQ_EVENTS_CHATS_DELETE=false
      - RABBITMQ_EVENTS_GROUPS_UPSERT=false
      - RABBITMQ_EVENTS_GROUP_UPDATE=false
      - RABBITMQ_EVENTS_GROUP_PARTICIPANTS_UPDATE=false
      - RABBITMQ_EVENTS_CONNECTION_UPDATE=true
      - RABBITMQ_EVENTS_CALL=false
      - RABBITMQ_EVENTS_TYPEBOT_START=false
      - RABBITMQ_EVENTS_TYPEBOT_CHANGE_STATUS=false
      ## Webhook (Story 5.1: condicional — ativado quando OpenClaw disponivel)
      - WEBHOOK_GLOBAL_ENABLED=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_GLOBAL_URL=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "http://openclaw_gateway:${porta_openclaw:-18789}/webhook/evolution"; fi)
      - WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_APPLICATION_STARTUP=false
      - WEBHOOK_EVENTS_QRCODE_UPDATED=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_MESSAGES_SET=false
      - WEBHOOK_EVENTS_SEND_MESSAGE_UPDATE=false
      - WEBHOOK_EVENTS_MESSAGES_UPSERT=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_MESSAGES_EDITED=false
      - WEBHOOK_EVENTS_MESSAGES_UPDATE=false
      - WEBHOOK_EVENTS_MESSAGES_DELETE=false
      - WEBHOOK_EVENTS_SEND_MESSAGE=false
      - WEBHOOK_EVENTS_CONTACTS_SET=false
      - WEBHOOK_EVENTS_CONTACTS_UPSERT=false
      - WEBHOOK_EVENTS_CONTACTS_UPDATE=false
      - WEBHOOK_EVENTS_PRESENCE_UPDATE=false
      - WEBHOOK_EVENTS_CHATS_SET=false
      - WEBHOOK_EVENTS_CHATS_UPSERT=false
      - WEBHOOK_EVENTS_CHATS_UPDATE=false
      - WEBHOOK_EVENTS_CHATS_DELETE=false
      - WEBHOOK_EVENTS_GROUPS_UPSERT=false
      - WEBHOOK_EVENTS_GROUPS_UPDATE=false
      - WEBHOOK_EVENTS_GROUP_PARTICIPANTS_UPDATE=false
      - WEBHOOK_EVENTS_CONNECTION_UPDATE=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_LABELS_EDIT=false
      - WEBHOOK_EVENTS_LABELS_ASSOCIATION=false
      - WEBHOOK_EVENTS_CALL=false
      - WEBHOOK_EVENTS_TYPEBOT_START=false
      - WEBHOOK_EVENTS_TYPEBOT_CHANGE_STATUS=false
      - WEBHOOK_EVENTS_ERRORS=false
      - WEBHOOK_EVENTS_ERRORS_WEBHOOK=
      - WEBHOOK_REQUEST_TIMEOUT_MS=60000
      - WEBHOOK_RETRY_MAX_ATTEMPTS=10
      - WEBHOOK_RETRY_INITIAL_DELAY_SECONDS=5
      - WEBHOOK_RETRY_USE_EXPONENTIAL_BACKOFF=true
      - WEBHOOK_RETRY_MAX_DELAY_SECONDS=300
      - WEBHOOK_RETRY_JITTER_FACTOR=0.2
      - WEBHOOK_RETRY_NON_RETRYABLE_STATUS_CODES=400,401,403,404,422
      ## Provider (desabilitado)
      - PROVIDER_ENABLED=false
      - PROVIDER_HOST=127.0.0.1
      - PROVIDER_PORT=5656
      - PROVIDER_PREFIX=evolution${sufixo}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=1
        - traefik.http.routers.evolution${sufixo}.rule=Host(\`${url_evolution}\`)
        - traefik.http.routers.evolution${sufixo}.entrypoints=websecure
        - traefik.http.routers.evolution${sufixo}.priority=1
        - traefik.http.routers.evolution${sufixo}.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution${sufixo}.service=evolution${sufixo}
        - traefik.http.services.evolution${sufixo}.loadbalancer.server.port=8080
        - traefik.http.services.evolution${sufixo}.loadbalancer.passHostHeader=true

  evolution${sufixo}_redis:
    image: redis:7-alpine
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - evolution${sufixo}_redis:/data
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
  evolution${sufixo}_instances:
    external: true
    name: evolution${sufixo}_instances
  evolution${sufixo}_redis:
    external: true
    name: evolution${sufixo}_redis

networks:
  ${nome_rede:-legendsclaw_net}:
    external: true
    name: ${nome_rede:-legendsclaw_net}
EOL
  else
    # Modo local — docker compose (sem Traefik, sem overlay)
    cat > "$yaml_file" << EOL
version: "3.7"
services:

  evolution${sufixo}_api:
    image: evoapicloud/evolution-api:v2.2.3
    volumes:
      - evolution${sufixo}_instances:/evolution/instances
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
      - DATABASE_CONNECTION_URI=postgresql://postgres:${senha_postgres}@postgres:5432/evolution${sufixo}
      - DATABASE_CONNECTION_CLIENT_NAME=evolution${sufixo}
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
      - CHATWOOT_IMPORT_DATABASE_CONNECTION_URI=
      - CHATWOOT_IMPORT_PLACEHOLDER_MEDIA_MESSAGE=false
      ## Cache Redis
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://evolution${sufixo}_redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=false
      - CACHE_LOCAL_ENABLED=false
      ## S3 (desabilitado — configurar endpoint para ativar)
      - S3_ENABLED=false
      - S3_ACCESS_KEY=
      - S3_SECRET_KEY=
      - S3_BUCKET=evolution
      - S3_PORT=443
      - S3_ENDPOINT=
      - S3_USE_SSL=true
      ## WhatsApp Business
      - WA_BUSINESS_TOKEN_WEBHOOK=evolution${sufixo}
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
      - SQS_ACCESS_KEY_ID=
      - SQS_SECRET_ACCESS_KEY=
      - SQS_ACCOUNT_ID=
      - SQS_REGION=
      ## RabbitMQ (desabilitado — ativar para escala horizontal)
      - RABBITMQ_ENABLED=false
      - RABBITMQ_FRAME_MAX=8192
      - RABBITMQ_URI=amqp://USER:PASS@rabbitmq:5672/evolution${sufixo}
      - RABBITMQ_EXCHANGE_NAME=evolution
      - RABBITMQ_GLOBAL_ENABLED=false
      - RABBITMQ_EVENTS_APPLICATION_STARTUP=false
      - RABBITMQ_EVENTS_INSTANCE_CREATE=false
      - RABBITMQ_EVENTS_INSTANCE_DELETE=false
      - RABBITMQ_EVENTS_QRCODE_UPDATED=false
      - RABBITMQ_EVENTS_SEND_MESSAGE_UPDATE=false
      - RABBITMQ_EVENTS_MESSAGES_SET=false
      - RABBITMQ_EVENTS_MESSAGES_UPSERT=true
      - RABBITMQ_EVENTS_MESSAGES_EDITED=false
      - RABBITMQ_EVENTS_MESSAGES_UPDATE=false
      - RABBITMQ_EVENTS_MESSAGES_DELETE=false
      - RABBITMQ_EVENTS_SEND_MESSAGE=false
      - RABBITMQ_EVENTS_CONTACTS_SET=false
      - RABBITMQ_EVENTS_CONTACTS_UPSERT=false
      - RABBITMQ_EVENTS_CONTACTS_UPDATE=false
      - RABBITMQ_EVENTS_PRESENCE_UPDATE=false
      - RABBITMQ_EVENTS_CHATS_SET=false
      - RABBITMQ_EVENTS_CHATS_UPSERT=false
      - RABBITMQ_EVENTS_CHATS_UPDATE=false
      - RABBITMQ_EVENTS_CHATS_DELETE=false
      - RABBITMQ_EVENTS_GROUPS_UPSERT=false
      - RABBITMQ_EVENTS_GROUP_UPDATE=false
      - RABBITMQ_EVENTS_GROUP_PARTICIPANTS_UPDATE=false
      - RABBITMQ_EVENTS_CONNECTION_UPDATE=true
      - RABBITMQ_EVENTS_CALL=false
      - RABBITMQ_EVENTS_TYPEBOT_START=false
      - RABBITMQ_EVENTS_TYPEBOT_CHANGE_STATUS=false
      ## Webhook (Story 5.1: condicional — ativado quando OpenClaw disponivel)
      - WEBHOOK_GLOBAL_ENABLED=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_GLOBAL_URL=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "http://openclaw_gateway:${porta_openclaw:-18789}/webhook/evolution"; fi)
      - WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_APPLICATION_STARTUP=false
      - WEBHOOK_EVENTS_QRCODE_UPDATED=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_MESSAGES_SET=false
      - WEBHOOK_EVENTS_SEND_MESSAGE_UPDATE=false
      - WEBHOOK_EVENTS_MESSAGES_UPSERT=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_MESSAGES_EDITED=false
      - WEBHOOK_EVENTS_MESSAGES_UPDATE=false
      - WEBHOOK_EVENTS_MESSAGES_DELETE=false
      - WEBHOOK_EVENTS_SEND_MESSAGE=false
      - WEBHOOK_EVENTS_CONTACTS_SET=false
      - WEBHOOK_EVENTS_CONTACTS_UPSERT=false
      - WEBHOOK_EVENTS_CONTACTS_UPDATE=false
      - WEBHOOK_EVENTS_PRESENCE_UPDATE=false
      - WEBHOOK_EVENTS_CHATS_SET=false
      - WEBHOOK_EVENTS_CHATS_UPSERT=false
      - WEBHOOK_EVENTS_CHATS_UPDATE=false
      - WEBHOOK_EVENTS_CHATS_DELETE=false
      - WEBHOOK_EVENTS_GROUPS_UPSERT=false
      - WEBHOOK_EVENTS_GROUPS_UPDATE=false
      - WEBHOOK_EVENTS_GROUP_PARTICIPANTS_UPDATE=false
      - WEBHOOK_EVENTS_CONNECTION_UPDATE=$(if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then echo "true"; else echo "false"; fi)
      - WEBHOOK_EVENTS_LABELS_EDIT=false
      - WEBHOOK_EVENTS_LABELS_ASSOCIATION=false
      - WEBHOOK_EVENTS_CALL=false
      - WEBHOOK_EVENTS_TYPEBOT_START=false
      - WEBHOOK_EVENTS_TYPEBOT_CHANGE_STATUS=false
      - WEBHOOK_EVENTS_ERRORS=false
      - WEBHOOK_EVENTS_ERRORS_WEBHOOK=
      - WEBHOOK_REQUEST_TIMEOUT_MS=60000
      - WEBHOOK_RETRY_MAX_ATTEMPTS=10
      - WEBHOOK_RETRY_INITIAL_DELAY_SECONDS=5
      - WEBHOOK_RETRY_USE_EXPONENTIAL_BACKOFF=true
      - WEBHOOK_RETRY_MAX_DELAY_SECONDS=300
      - WEBHOOK_RETRY_JITTER_FACTOR=0.2
      - WEBHOOK_RETRY_NON_RETRYABLE_STATUS_CODES=400,401,403,404,422
      ## Provider (desabilitado)
      - PROVIDER_ENABLED=false
      - PROVIDER_HOST=127.0.0.1
      - PROVIDER_PORT=5656
      - PROVIDER_PREFIX=evolution${sufixo}
    depends_on:
      - evolution${sufixo}_redis

  evolution${sufixo}_redis:
    image: redis:7-alpine
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - evolution${sufixo}_redis:/data

volumes:
  evolution${sufixo}_instances:
  evolution${sufixo}_redis:
EOL
  fi

  chmod 600 "$yaml_file"
  step_ok "${yaml_file} gerado (Evolution API + Redis, modo ${ambiente}, chmod 600)"

  # =========================================================================
  # STEP 10: DEPLOY
  # =========================================================================
  if [[ "$ambiente" == "vps" ]]; then
    # Criar volumes externos se nao existirem
    docker volume create "evolution${sufixo}_instances" 2>/dev/null || true
    docker volume create "evolution${sufixo}_redis" 2>/dev/null || true
  fi

  # Pull images
  echo "  Baixando imagens..."
  pull "redis:7-alpine" || true
  pull "evoapicloud/evolution-api:v2.2.3" || true

  deploy_stack "$stack_name" "$yaml_file"
  step_ok "Evolution API deployada (modo ${ambiente}, stack: ${stack_name})"

  # =========================================================================
  # STEP 11: VERIFY — Wait polling
  # =========================================================================
  echo "  Aguardando services ficarem online..."
  if wait_deploy "$stack_name" "evolution${sufixo}_redis" "evolution${sufixo}_api"; then
    step_ok "Evolution API + Redis online"
  else
    step_fail "Services nao ficaram online (timeout 5min)"
    exit 1
  fi

  # =========================================================================
  # STEP 12: CONFIGURE WHATSAPP INSTANCE (Story 5.1, condicional)
  # =========================================================================
  if [[ "$OPENCLAW_AVAILABLE" == "true" && -n "$numero_whatsapp" ]]; then
    local wa_instance_name="legendsclaw${sufixo}"
    local wa_webhook_url="http://openclaw_gateway:${porta_openclaw:-18789}/webhook/evolution"

    echo "  Configurando instancia WhatsApp via API Evolution..."

    if evolution_create_instance "$server_url" "$apikeyglobal" "$wa_instance_name" "$numero_whatsapp" "$wa_webhook_url"; then
      step_ok "Instancia WhatsApp '${wa_instance_name}' criada"

      # Obter QR Code para pareamento
      if evolution_connect_instance "$server_url" "$apikeyglobal" "$wa_instance_name"; then
        echo ""
        hint_whatsapp_qr "$server_url" "$wa_instance_name"
        step_ok "QR Code disponivel para pareamento"
      else
        echo "  AVISO: Nao foi possivel obter QR Code agora. Use o Manager para parear depois."
        step_ok "Instancia criada (pareamento pendente via Manager)"
      fi
    else
      echo "  AVISO: Falha ao criar instancia WhatsApp. O pareamento pode ser feito manualmente via Manager."
      step_ok "Evolution API online (instancia WA pendente)"
    fi
  else
    step_skip "Configuracao WhatsApp (OpenClaw nao disponivel ou numero nao fornecido)"
  fi

  # =========================================================================
  # STEP 13: FINALIZE — Salvar credenciais
  # =========================================================================
  mkdir -p "$HOME/dados_vps"

  local dados_file="$HOME/dados_vps/dados_evolution${sufixo}"

  if [[ "$ambiente" == "vps" ]]; then
    cat > "$dados_file" << EOL
[ EVOLUTION API — ${instance_label} ]

Manager Evolution: https://${url_evolution}/manager

BaseUrl: https://${url_evolution}

Global API Key: ${apikeyglobal}

Stack: ${stack_name}
Banco: evolution${sufixo}
YAML: ${yaml_file}
EOL
  else
    cat > "$dados_file" << EOL
[ EVOLUTION API — ${instance_label} ]

Manager Evolution: http://localhost:8080/manager

BaseUrl: http://localhost:8080

Global API Key: ${apikeyglobal}

Stack: ${stack_name}
Banco: evolution${sufixo}
YAML: ${yaml_file}
EOL
  fi

  # Append WhatsApp data (Story 5.1)
  if [[ "$OPENCLAW_AVAILABLE" == "true" && -n "$numero_whatsapp" ]]; then
    cat >> "$dados_file" << EOL

Numero WhatsApp: ${numero_whatsapp}
Webhook URL: http://openclaw_gateway:${porta_openclaw:-18789}/webhook/evolution
Instancia WA: legendsclaw${sufixo}
EOL
  fi

  chmod 600 "$dados_file"

  step_ok "Credenciais salvas em ${dados_file} (chmod 600)"

  # =========================================================================
  # STEP 14: RESUMO
  # =========================================================================
  resumo_final

  echo -e "${UI_BOLD}Evolution API (${instance_label}):${UI_NC}"
  if [[ "$ambiente" == "vps" ]]; then
    echo -e "  Manager: https://${url_evolution}/manager"
    echo -e "  BaseUrl: https://${url_evolution}"
  else
    echo -e "  Manager: http://localhost:8080/manager"
    echo -e "  BaseUrl: http://localhost:8080"
  fi
  echo -e "  Global API Key: ${apikeyglobal}"
  echo -e "  Stack: ${stack_name}"
  if [[ "$OPENCLAW_AVAILABLE" == "true" && -n "$numero_whatsapp" ]]; then
    echo -e "  Numero WhatsApp: ${numero_whatsapp}"
    echo -e "  Webhook: http://openclaw_gateway:${porta_openclaw:-18789}/webhook/evolution"
    echo -e "  Instancia WA: legendsclaw${sufixo}"
  fi
  echo -e "  Credenciais: ${dados_file}"
  echo -e "  Log: ${LOG_FILE}"
  echo ""

  # Hint de debug Evolution (Story 5.1)
  if [[ "$ambiente" == "vps" ]]; then
    hint_evolution_debug "$url_evolution" "$apikeyglobal" "legendsclaw${sufixo}" "${stack_name}"
  fi

  log_finish

  if [[ "$STEP_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
