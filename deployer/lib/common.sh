#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Common Functions
# dados(), recursos(), verificar_stack(), validar_senha()
# NOTE: This file is sourced (not executed standalone).
#       It inherits set -euo pipefail from the calling script.
# =============================================================================

STATE_DIR="$HOME/dados_vps"

# Carrega estado do filesystem (~/dados_vps/)
# Popula variaveis globais: nome_servidor, nome_rede
# Uso: dados
dados() {
  nome_servidor=$(grep "Nome do Servidor:" "$STATE_DIR/dados_vps" 2>/dev/null | awk -F': ' '{print $2}')
  nome_rede=$(grep "Rede interna:" "$STATE_DIR/dados_vps" 2>/dev/null | awk -F': ' '{print $2}')
}

# Gate de recursos — verifica vCPU e RAM minimos
# Uso: recursos 1 1  (minimo 1 vCPU, 1GB RAM)
# Retorna: 0 se OK ou usuario aceita, 1 se recusou
recursos() {
  local vcpu_requerido="${1:-1}"
  local ram_requerido="${2:-1}"

  local vcpu_disponivel
  vcpu_disponivel=$(nproc 2>/dev/null || echo 0)

  local ram_disponivel_mb
  ram_disponivel_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo 0)
  local ram_disponivel_gb=$(( ram_disponivel_mb / 1024 ))

  if [[ "$vcpu_disponivel" -ge "$vcpu_requerido" && "$ram_disponivel_gb" -ge "$ram_requerido" ]]; then
    echo "Recursos OK: ${vcpu_disponivel} vCPU, ${ram_disponivel_gb}GB RAM (minimo: ${vcpu_requerido} vCPU, ${ram_requerido}GB RAM)"
    return 0
  else
    echo "AVISO: Servidor tem ${vcpu_disponivel} vCPU e ${ram_disponivel_gb}GB RAM (minimo: ${vcpu_requerido} vCPU, ${ram_requerido}GB RAM)"
    read -rp "Continuar mesmo assim? (s/n): " escolha
    if [[ "$escolha" =~ ^[Ss]$ ]]; then
      return 0
    else
      return 1
    fi
  fi
}

# Verifica se uma stack Docker ja existe
# Uso: verificar_stack "traefik"
# Retorna: 0 se existe, 1 se nao existe
verificar_stack() {
  local nome_stack="$1"
  if docker stack ls --format "{{.Name}}" 2>/dev/null | grep -q "^${nome_stack}$"; then
    return 0
  else
    return 1
  fi
}

# Valida senha — minimo 8 chars, 1 maiuscula, 1 numero
# Uso: validar_senha "MinhaS3nha"
# Retorna: 0 se valida, 1 se invalida
validar_senha() {
  local senha="$1"

  if [[ ${#senha} -lt 8 ]]; then
    echo "Senha muito curta (minimo 8 caracteres)"
    return 1
  fi

  if ! echo "$senha" | grep -q '[A-Z]'; then
    echo "Senha deve conter pelo menos 1 letra maiuscula"
    return 1
  fi

  if ! echo "$senha" | grep -q '[0-9]'; then
    echo "Senha deve conter pelo menos 1 numero"
    return 1
  fi

  return 0
}

# Verifica se container Postgres esta rodando
# Retorna: 0 se existe, 1 se nao existe
verificar_container_postgres() {
  if docker ps --format "{{.Names}}" 2>/dev/null | grep -qE "(^|_)postgres($|_)"; then
    return 0
  fi
  # Fallback: checar no swarm
  if docker service ls --format "{{.Name}}" 2>/dev/null | grep -qE "(^|_)postgres($|_)"; then
    return 0
  fi
  return 1
}

# Le senha do Postgres do YAML gerado ou do arquivo de estado
# Popula variavel global: senha_postgres
pegar_senha_postgres() {
  # Primeiro tenta do arquivo de estado
  senha_postgres=$(grep "Senha:" "$STATE_DIR/dados_postgres" 2>/dev/null | awk -F': ' '{print $2}')
  if [[ -n "$senha_postgres" ]]; then
    return 0
  fi
  # Fallback: ler do YAML
  senha_postgres=$(grep "POSTGRES_PASSWORD" "$HOME/postgres.yaml" 2>/dev/null | head -1 | sed 's/.*=//; s/^[[:space:]]*//')
  if [[ -n "$senha_postgres" ]]; then
    return 0
  fi
  echo "ERRO: Senha do Postgres nao encontrada"
  return 1
}

# Cria banco de dados no Postgres via docker exec
# Uso: criar_banco_postgres_da_stack "evolution"
criar_banco_postgres_da_stack() {
  local db_name="$1"
  local container_id

  # Validar nome do banco contra SQL injection
  if ! [[ "$db_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "ERRO: Nome de banco invalido '${db_name}' (apenas [a-z][a-z0-9_]* permitido)"
    return 1
  fi

  # Encontrar container Postgres
  container_id=$(docker ps -q --filter "name=postgres" 2>/dev/null | head -1)
  if [[ -z "$container_id" ]]; then
    echo "ERRO: Container Postgres nao encontrado"
    return 1
  fi

  # Verificar se banco ja existe
  if docker exec "$container_id" psql -U postgres -lqt 2>/dev/null | cut -d\| -f1 | grep -qw "$db_name"; then
    echo "Banco '${db_name}' ja existe"
    return 0
  fi

  # Criar banco
  if docker exec "$container_id" psql -U postgres -c "CREATE DATABASE ${db_name};" 2>/dev/null; then
    echo "Banco '${db_name}' criado com sucesso"
    return 0
  else
    echo "ERRO: Falha ao criar banco '${db_name}'"
    return 1
  fi
}

# Exibe resumo de dados coletados para confirmacao
# Uso: conferindo_as_info "campo1=valor1" "campo2=valor2" ...
conferindo_as_info() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  CONFERINDO AS INFORMACOES"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  for item in "$@"; do
    local campo="${item%%=*}"
    local valor="${item#*=}"
    echo -e "  ${campo}: ${valor}"
  done
  echo ""
  echo "=============================================="
}
