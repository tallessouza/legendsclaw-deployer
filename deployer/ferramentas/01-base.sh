#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 01: Base Infrastructure
# Traefik v3.5.3 + Portainer CE + Docker Swarm
# Pattern: 8-Step Tool Lifecycle (SetupOrion)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source lib
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/deploy.sh"
source "${SCRIPT_DIR}/lib/hints.sh"

# Constantes
readonly FERRAMENTA="base"
readonly TRAEFIK_VERSION="v3.5.3"
readonly TOTAL=13

main() {
  log_init "$FERRAMENTA"
  step_init "$TOTAL"

  echo -e "${UI_CYAN}${UI_BOLD}[01] Traefik + Portainer + Docker Swarm${UI_NC}"
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
  step_ok "Estado carregado de ~/dados_vps/"

  # =========================================================================
  # STEP 3: HINTS (AC: 3, 4)
  # =========================================================================
  hint_firewall
  hint_dns
  step_ok "Hints de firewall e DNS exibidos"

  # =========================================================================
  # STEP 4: INPUT COLLECTION (AC: 2) — Loop confirmado
  # =========================================================================
  local dominio_portainer=""
  local email_ssl=""
  local user_portainer=""
  local pass_portainer=""
  local nome_servidor=""
  local nome_rede=""

  while true; do
    echo ""
    read -rp "Dominio do Portainer (ex: painel.exemplo.com): " dominio_portainer
    read -rp "Email para SSL/Let's Encrypt: " email_ssl
    read -rp "Usuario admin do Portainer: " user_portainer

    while true; do
      read -rsp "Senha admin do Portainer: " pass_portainer
      echo ""
      if validar_senha "$pass_portainer"; then
        break
      fi
      echo "Tente novamente."
    done

    read -rp "Nome do servidor (ex: legendsclaw-01): " nome_servidor
    read -rp "Nome da rede overlay (ex: legendsclaw_net): " nome_rede

    conferindo_as_info \
      "Dominio Portainer=${dominio_portainer}" \
      "Email SSL=${email_ssl}" \
      "Usuario Portainer=${user_portainer}" \
      "Senha Portainer=********" \
      "Nome Servidor=${nome_servidor}" \
      "Rede Overlay=${nome_rede}"

    read -rp "As informacoes estao corretas? (s/n): " confirmacao
    if [[ "$confirmacao" =~ ^[Ss]$ ]]; then
      break
    fi
    echo "Vamos recoletar os dados..."
  done

  step_ok "Inputs coletados e confirmados"

  # =========================================================================
  # STEP 5: DOCKER SWARM INIT (AC: 5, 6)
  # =========================================================================

  # Detectar IP principal
  local ip_vps
  ip_vps=$(hostname -I 2>/dev/null | awk '{print $1}' || curl -s https://ifconfig.me)

  # Inicializar Swarm (retry 3x)
  if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
    step_skip "Docker Swarm (ja inicializado)"
  else
    local swarm_ok=false
    for i in 1 2 3; do
      if docker swarm init --advertise-addr "$ip_vps" 2>/dev/null; then
        swarm_ok=true
        break
      fi
      log "Swarm init tentativa ${i}/3 falhou, retentando em 5s..."
      sleep 5
    done

    if $swarm_ok; then
      step_ok "Docker Swarm inicializado (advertise: ${ip_vps})"
    else
      step_fail "Docker Swarm — falha apos 3 tentativas"
      exit 1
    fi
  fi

  # Criar overlay network
  if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${nome_rede}$"; then
    step_skip "Overlay network '${nome_rede}' (ja existe)"
  else
    if docker network create --driver=overlay "$nome_rede" 2>/dev/null; then
      step_ok "Overlay network '${nome_rede}' criada"
    else
      step_fail "Overlay network '${nome_rede}'"
      exit 1
    fi
  fi

  # =========================================================================
  # STEP 6: GENERATE YAML — Heredoc inline (Orion pattern) (AC: 7, 8)
  # =========================================================================

  # Traefik YAML
  cat > "$HOME/traefik.yaml" << EOL
version: "3.7"

services:
  traefik:
    image: traefik:${TRAEFIK_VERSION}
    command:
      - --api.dashboard=true
      - --api.insecure=false
      - --providers.docker=true
      - --providers.docker.swarmMode=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=${nome_rede}
      - --entrypoints.web.address=:80
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge=true
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.letsencryptresolver.acme.email=${email_ssl}
      - --certificatesresolvers.letsencryptresolver.acme.storage=/letsencrypt/acme.json
      - --log.level=INFO
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - traefik-letsencrypt:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - ${nome_rede}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "0.50"
          memory: 256M

volumes:
  traefik-letsencrypt:
    external: false

networks:
  ${nome_rede}:
    external: true
    name: ${nome_rede}
EOL

  step_ok "~/traefik.yaml gerado (Traefik ${TRAEFIK_VERSION} + Let's Encrypt)"

  # Portainer YAML
  cat > "$HOME/portainer.yaml" << EOL
version: "3.7"

services:
  portainer_agent:
    image: portainer/agent:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - ${nome_rede}
    deploy:
      mode: global
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "0.25"
          memory: 128M

  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.portainer_agent:9001 --tlsskipverify
    volumes:
      - portainer-data:/data
    networks:
      - ${nome_rede}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`${dominio_portainer}\`)
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.services.portainer.loadbalancer.server.port=9000
      resources:
        limits:
          cpus: "0.50"
          memory: 256M

volumes:
  portainer-data:
    external: false

networks:
  ${nome_rede}:
    external: true
    name: ${nome_rede}
EOL

  step_ok "~/portainer.yaml gerado (Agent + CE + Traefik labels)"

  # =========================================================================
  # STEP 7: DEPLOY — docker stack deploy (AC: 9, 10)
  # =========================================================================

  # Deploy Traefik
  if verificar_stack "traefik"; then
    step_skip "Stack 'traefik' (ja existe — remova do Portainer para reinstalar)"
  else
    docker stack deploy -c "$HOME/traefik.yaml" traefik
    step_ok "Stack 'traefik' deployada"
  fi

  # Wait Traefik
  echo "  Aguardando Traefik ficar online..."
  if wait_stack "traefik_traefik"; then
    log "Traefik online"
  else
    step_fail "Traefik nao ficou online (timeout 5min)"
    echo "  Verifique: docker service ls"
    exit 1
  fi

  # Deploy Portainer
  if verificar_stack "portainer"; then
    step_skip "Stack 'portainer' (ja existe — remova do Portainer para reinstalar)"
  else
    docker stack deploy -c "$HOME/portainer.yaml" portainer
    step_ok "Stack 'portainer' deployada"
  fi

  # Wait Portainer
  echo "  Aguardando Portainer ficar online..."
  if wait_stack "portainer_portainer" "portainer_portainer_agent"; then
    log "Portainer online"
  else
    step_fail "Portainer nao ficou online (timeout 5min)"
    echo "  Verifique: docker service ls"
    exit 1
  fi

  # =========================================================================
  # STEP 8: PORTAINER ADMIN ACCOUNT (AC: 11, 12)
  # =========================================================================

  # Criar conta admin (retry 4x, sleep 15s)
  local admin_criado=false
  for i in 1 2 3 4; do
    local response
    response=$(curl -k -s -X POST \
      "https://${dominio_portainer}/api/users/admin/init" \
      -H "Content-Type: application/json" \
      -d "{\"Username\":\"${user_portainer}\",\"Password\":\"${pass_portainer}\"}" 2>/dev/null)

    if echo "$response" | grep -q "\"Username\":\"${user_portainer}\""; then
      admin_criado=true
      break
    fi
    log "Portainer admin init tentativa ${i}/4 falhou, retentando em 15s..."
    sleep 15
  done

  if ! $admin_criado; then
    step_fail "Criar conta admin do Portainer (4 tentativas falharam)"
    exit 1
  fi

  # Obter JWT token
  local token
  token=$(curl -k -s -X POST \
    "https://${dominio_portainer}/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${user_portainer}\",\"password\":\"${pass_portainer}\"}" | jq -r .jwt 2>/dev/null)

  step_ok "Conta admin do Portainer criada e token JWT obtido"

  # Salvar credenciais
  cat > "$HOME/dados_vps/dados_portainer" << EOL
Dominio do portainer: ${dominio_portainer}
Usuario: ${user_portainer}
Senha: ${pass_portainer}
Token: ${token}
EOL

  # Proteger credenciais (AC: seguranca — fix PO)
  chmod 600 "$HOME/dados_vps/dados_portainer"

  # Atualizar dados_vps
  cat > "$HOME/dados_vps/dados_vps" << EOL
Nome do Servidor: ${nome_servidor}
Rede interna: ${nome_rede}
EOL

  step_ok "Credenciais salvas em ~/dados_vps/dados_portainer (chmod 600)"

  # =========================================================================
  # FINALIZE — Resumo
  # =========================================================================
  resumo_final

  echo -e "${UI_BOLD}Acessos:${UI_NC}"
  echo -e "  Portainer: https://${dominio_portainer}"
  echo -e "  Usuario:   ${user_portainer}"
  echo ""
  echo -e "  Traefik Dashboard: via Portainer (port 8080 interno)"
  echo ""
  echo -e "  Arquivos YAML: ~/traefik.yaml, ~/portainer.yaml"
  echo -e "  Credenciais:   ~/dados_vps/dados_portainer"
  echo -e "  Log:           ${LOG_FILE}"
  echo ""

  log_finish

  # Exit code
  if [[ "$STEP_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
