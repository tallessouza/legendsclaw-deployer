#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Environment Detection (Dual-Mode)
# detectar_ambiente(), deploy_stack(), wait_stack_local()
# Story 1.3: Supports local (docker compose) and VPS (docker stack deploy)
# NOTE: This file is sourced (not executed standalone).
#       It inherits set -euo pipefail from the calling script.
# =============================================================================

# Detecta se estamos em ambiente local ou VPS
# Criterio: Docker Swarm ativo = VPS, senao = local
# Retorna: "local" ou "vps" via stdout
detectar_ambiente() {
  local swarm_state
  swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")
  if [[ "$swarm_state" == "active" ]]; then
    echo "vps"
  else
    echo "local"
  fi
}

# Deploy wrapper dual-mode
# VPS: usa stack_editavel() via Portainer API
# Local: usa docker compose up -d
# Uso: deploy_stack "nome_stack" "/caminho/stack.yaml"
deploy_stack() {
  local stack_name="$1"
  local yaml_file="$2"
  local ambiente
  ambiente=$(detectar_ambiente)

  if [[ "$ambiente" == "vps" ]]; then
    stack_editavel "$stack_name" "$yaml_file"
  else
    docker compose -f "$yaml_file" -p "$stack_name" up -d
  fi
}

# Wait com polling para modo local (docker compose)
# Uso: wait_stack_local "stack_name" "service1" "service2"
# Timeout: 5 minutos (10 iteracoes de 30s)
wait_stack_local() {
  local project="$1"
  shift
  local max_iter=10
  local iter=0

  while [[ "$iter" -lt "$max_iter" ]]; do
    local all_running=true

    for service in "$@"; do
      local status
      if command -v jq &>/dev/null; then
        status=$(docker compose -p "$project" ps --format json 2>/dev/null \
          | jq -r "select(.Service==\"${service}\") | .State" 2>/dev/null || echo "")
      else
        # Fallback sem jq: checar via docker compose ps com grep
        status=$(docker compose -p "$project" ps 2>/dev/null \
          | grep -E "${service}.*running" &>/dev/null && echo "running" || echo "")
      fi
      if [[ "$status" != "running" ]]; then
        all_running=false
      fi
    done

    if $all_running; then
      echo "  Todos os services estao running"
      return 0
    fi

    iter=$((iter + 1))
    echo "  Aguardando services... (${iter}/${max_iter})"
    sleep 30
  done

  echo "TIMEOUT: Nem todos os services ficaram online apos 5 minutos"
  return 1
}

# Wait wrapper dual-mode
# VPS: usa wait_stack (de deploy.sh) com nomes de swarm services
# Local: usa wait_stack_local com nomes de compose services
# Uso: wait_deploy "stack_name" "service1" "service2" ...
wait_deploy() {
  local stack_name="$1"
  shift
  local ambiente
  ambiente=$(detectar_ambiente)

  if [[ "$ambiente" == "vps" ]]; then
    # Swarm services sao nomeados como: stackname_servicename
    local swarm_services=()
    for svc in "$@"; do
      swarm_services+=("${stack_name}_${svc}")
    done
    wait_stack "${swarm_services[@]}"
  else
    wait_stack_local "$stack_name" "$@"
  fi
}
