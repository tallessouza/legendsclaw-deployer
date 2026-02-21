#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Deploy Functions
# stack_editavel() (Portainer API), wait_stack() (polling), pull()
# =============================================================================

# Deploy stack via Portainer API (para ferramentas 02+)
# Uso: stack_editavel "nome_stack" "/caminho/para/stack.yaml"
stack_editavel() {
  local stack_name="$1"
  local stack_file="$2"

  # Ler credenciais do Portainer
  local portainer_url
  portainer_url=$(grep "Dominio do portainer:" "$HOME/dados_vps/dados_portainer" 2>/dev/null | awk -F': ' '{print $2}')
  local usuario
  usuario=$(grep "Usuario:" "$HOME/dados_vps/dados_portainer" 2>/dev/null | awk -F': ' '{print $2}')
  local senha
  senha=$(grep "Senha:" "$HOME/dados_vps/dados_portainer" 2>/dev/null | awk -F': ' '{print $2}')

  if [[ -z "$portainer_url" || -z "$usuario" || -z "$senha" ]]; then
    echo "ERRO: Credenciais do Portainer nao encontradas em ~/dados_vps/dados_portainer"
    return 1
  fi

  # Obter JWT token (retry 6x, sleep 5s)
  local token=""
  local tentativa=0
  local max_tentativas=6

  while [[ -z "$token" || "$token" == "null" ]]; do
    token=$(curl -k -s -X POST \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg u "$usuario" --arg p "$senha" '{username:$u,password:$p}')" \
      "https://${portainer_url}/api/auth" | jq -r .jwt 2>/dev/null)

    tentativa=$((tentativa + 1))
    if [[ "$tentativa" -ge "$max_tentativas" ]]; then
      echo "ERRO: Falha ao obter token do Portainer apos ${max_tentativas} tentativas"
      return 1
    fi
    if [[ -z "$token" || "$token" == "null" ]]; then
      sleep 5
    fi
  done

  # Obter endpoint ID
  local endpoint_id
  endpoint_id=$(curl -k -s -X GET \
    -H "Authorization: Bearer ${token}" \
    "https://${portainer_url}/api/endpoints" | jq -r '.[0].Id' 2>/dev/null)

  # Obter Swarm ID
  local swarm_id
  swarm_id=$(docker info --format '{{.Swarm.Cluster.ID}}' 2>/dev/null)

  # Ler conteudo do YAML
  local stack_content
  stack_content=$(cat "$stack_file")

  # Criar stack via API
  local response
  response=$(curl -k -s -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${stack_name}\",
      \"stackFileContent\": $(echo "$stack_content" | jq -Rsa .),
      \"swarmID\": \"${swarm_id}\",
      \"env\": []
    }" \
    "https://${portainer_url}/api/stacks?type=1&method=string&endpointId=${endpoint_id}")

  if echo "$response" | jq -e '.Id' >/dev/null 2>&1; then
    echo "Stack '${stack_name}' criada com sucesso via Portainer API"
    return 0
  else
    echo "ERRO ao criar stack '${stack_name}': ${response}"
    return 1
  fi
}

# Wait com polling ate services ficarem 1/1
# Uso: wait_stack "traefik_traefik" "portainer_portainer"
# Timeout: 5 minutos (10 iteracoes de 30s)
wait_stack() {
  local -A services_status
  for service in "$@"; do
    services_status["$service"]="pendente"
  done

  local max_iter=10
  local iter=0

  while [[ "$iter" -lt "$max_iter" ]]; do
    local all_active=true

    for service in "${!services_status[@]}"; do
      if docker service ls --filter "name=${service}" --format "{{.Replicas}}" 2>/dev/null | grep -q "1/1"; then
        if [[ "${services_status[$service]}" != "ativo" ]]; then
          echo "  Service ${service} esta online (1/1)"
          services_status["$service"]="ativo"
        fi
      else
        all_active=false
      fi
    done

    if $all_active; then
      return 0
    fi

    iter=$((iter + 1))
    echo "  Aguardando services... (${iter}/${max_iter})"
    sleep 30
  done

  echo "TIMEOUT: Nem todos os services ficaram online apos 5 minutos"
  for service in "${!services_status[@]}"; do
    if [[ "${services_status[$service]}" != "ativo" ]]; then
      echo "  PENDENTE: ${service}"
    fi
  done
  return 1
}

# Pull de imagem com retry
# Uso: pull "traefik:v3.5.3"
pull() {
  local image="$1"
  local max_retries=3
  local retry=0

  while [[ "$retry" -lt "$max_retries" ]]; do
    if docker pull "$image" 2>/dev/null; then
      return 0
    fi

    retry=$((retry + 1))
    if [[ "$retry" -lt "$max_retries" ]]; then
      echo "  Retry pull ${image} (${retry}/${max_retries})..."
      sleep 5
    fi
  done

  echo "ERRO: Falha ao fazer pull de ${image} apos ${max_retries} tentativas"
  return 1
}
