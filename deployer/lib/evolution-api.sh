#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Evolution API Helper Functions
# Story 5.1: WhatsApp + Webhook integration
# Functions: evolution_create_instance, evolution_connect_instance,
#            evolution_check_connection, evolution_set_webhook
# NOTE: This file is sourced (not executed standalone).
#       It inherits set -euo pipefail from the calling script.
# =============================================================================

# Timeout para chamadas curl (segundos)
readonly EVOLUTION_API_TIMEOUT=30

# Max tentativas para retry com backoff
readonly EVOLUTION_API_MAX_RETRIES=3

# Mascara API key para exibicao em logs
# Uso: mask_key "abc123def456"
# Retorna: "abc1****f456"
mask_key() {
  local key="$1"
  if [[ ${#key} -le 8 ]]; then
    echo "****"
  else
    echo "${key:0:4}****${key: -4}"
  fi
}

# Wrapper curl com retry e backoff exponencial
# Uso: _evolution_curl "GET" "$base_url/instance/connect/foo" "$apikey"
# Uso: _evolution_curl "POST" "$base_url/instance/create" "$apikey" '{"json":"body"}'
# Retorna: response body via stdout, exit code 0=ok 1=fail
_evolution_curl() {
  local method="$1"
  local url="$2"
  local apikey="$3"
  local body="${4:-}"

  local attempt=0
  local delay=2
  local response=""

  while [[ "$attempt" -lt "$EVOLUTION_API_MAX_RETRIES" ]]; do
    if [[ "$method" == "POST" && -n "$body" ]]; then
      response=$(curl -s -w "\n%{http_code}" \
        --max-time "$EVOLUTION_API_TIMEOUT" \
        -X POST \
        -H "apikey: ${apikey}" \
        -H "Content-Type: application/json" \
        -d "$body" \
        "$url" 2>/dev/null) || true
    else
      response=$(curl -s -w "\n%{http_code}" \
        --max-time "$EVOLUTION_API_TIMEOUT" \
        -H "apikey: ${apikey}" \
        "$url" 2>/dev/null) || true
    fi

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body_response
    body_response=$(echo "$response" | sed '$d')

    if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
      echo "$body_response"
      return 0
    fi

    attempt=$((attempt + 1))
    if [[ "$attempt" -lt "$EVOLUTION_API_MAX_RETRIES" ]]; then
      echo "  Retry Evolution API (${attempt}/${EVOLUTION_API_MAX_RETRIES}, aguardando ${delay}s)..." >&2
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done

  echo "ERRO: Evolution API falhou apos ${EVOLUTION_API_MAX_RETRIES} tentativas (url: ${url}, http: ${http_code:-timeout})" >&2
  echo "$body_response"
  return 1
}

# Criar instancia WhatsApp na Evolution API
# POST /instance/create
# Uso: evolution_create_instance "$base_url" "$apikey" "$instance_name" "$number" "$webhook_url"
# Retorna: JSON response (instanceName, instanceId)
evolution_create_instance() {
  local base_url="$1"
  local apikey="$2"
  local instance_name="$3"
  local number="$4"
  local webhook_url="${5:-}"

  local payload
  if [[ -n "$webhook_url" ]]; then
    payload=$(cat << EOJSON
{
  "instanceName": "${instance_name}",
  "number": "${number}",
  "integration": "WHATSAPP-BAILEYS",
  "webhook": {
    "url": "${webhook_url}",
    "byEvents": true,
    "events": ["MESSAGES_UPSERT", "CONNECTION_UPDATE", "QRCODE_UPDATED"]
  }
}
EOJSON
    )
  else
    payload=$(cat << EOJSON
{
  "instanceName": "${instance_name}",
  "number": "${number}",
  "integration": "WHATSAPP-BAILEYS"
}
EOJSON
    )
  fi

  echo "  Criando instancia '${instance_name}' (numero: ${number}, apikey: $(mask_key "$apikey"))..." >&2
  _evolution_curl "POST" "${base_url}/instance/create" "$apikey" "$payload"
}

# Conectar instancia (obter QR Code)
# GET /instance/connect/{instanceName}
# Uso: evolution_connect_instance "$base_url" "$apikey" "$instance_name"
# Retorna: JSON com QR Code data (base64)
evolution_connect_instance() {
  local base_url="$1"
  local apikey="$2"
  local instance_name="$3"

  echo "  Conectando instancia '${instance_name}' (obtendo QR Code)..." >&2
  _evolution_curl "GET" "${base_url}/instance/connect/${instance_name}" "$apikey"
}

# Verificar estado da conexao
# GET /instance/connectionState/{instanceName}
# Uso: evolution_check_connection "$base_url" "$apikey" "$instance_name"
# Retorna: JSON com state (open|close|connecting)
evolution_check_connection() {
  local base_url="$1"
  local apikey="$2"
  local instance_name="$3"

  _evolution_curl "GET" "${base_url}/instance/connectionState/${instance_name}" "$apikey"
}

# Configurar webhook para instancia
# POST /webhook/set/{instanceName}
# Uso: evolution_set_webhook "$base_url" "$apikey" "$instance_name" "$webhook_url"
evolution_set_webhook() {
  local base_url="$1"
  local apikey="$2"
  local instance_name="$3"
  local webhook_url="$4"

  local payload
  payload=$(cat << EOJSON
{
  "url": "${webhook_url}",
  "webhookByEvents": true,
  "events": ["MESSAGES_UPSERT", "CONNECTION_UPDATE"]
}
EOJSON
  )

  echo "  Configurando webhook para '${instance_name}' → ${webhook_url}..." >&2
  _evolution_curl "POST" "${base_url}/webhook/set/${instance_name}" "$apikey" "$payload"
}
