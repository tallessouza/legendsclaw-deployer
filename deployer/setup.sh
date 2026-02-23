#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Bootstrap — Preparacao de Ambiente
# Versao: 1.0.0
# Uso: bash <(curl -sSL <URL>/deployer/setup.sh)
# Compativel: Ubuntu 22.04+ (soft gate para outros OS)
# Pattern: SetupOrion v2.8.0 (feedback N/M, skip logic, estado plaintext)
# =============================================================================

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly LEGENDSCLAW_VERSION="1.0.0"
readonly NODE_MIN_VERSION=22
readonly TOTAL_STEPS=16
readonly LOG_DIR="$HOME/legendsclaw-logs"
readonly STATE_DIR="$HOME/dados_vps"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly LOG_FILE="$LOG_DIR/bootstrap-${TIMESTAMP}.log"

# Cores ANSI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Contadores
CURRENT_STEP=0
COUNT_OK=0
COUNT_SKIP=0
COUNT_FAIL=0

# --- Trap Handler ---
cleanup_on_fail_bootstrap() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "" >&2
    echo -e "${RED}Bootstrap falhou no step ${CURRENT_STEP}/${TOTAL_STEPS} (exit code: $exit_code)${NC}" >&2
    echo -e "${RED}Log: ${LOG_FILE}${NC}" >&2
    echo "[$(date '+%H:%M:%S')] FAIL: Bootstrap encerrado com exit code $exit_code no step $CURRENT_STEP" >> "$LOG_FILE" 2>/dev/null || true
    echo ""
    echo -e "${BOLD}RESUMO${NC}"
    echo -e "  ${GREEN}OK${NC}:   ${COUNT_OK}"
    echo -e "  ${YELLOW}SKIP${NC}: ${COUNT_SKIP}"
    echo -e "  ${RED}FAIL${NC}: ${COUNT_FAIL}"
  fi
}
trap 'cleanup_on_fail_bootstrap' EXIT
trap 'echo "Interrompido pelo usuario"; exit 130' INT TERM

# -----------------------------------------------------------------------------
# Sistema de Feedback Visual (Pattern SetupOrion N/M)
# -----------------------------------------------------------------------------
feedback() {
  local status="$1"
  local message="$2"
  CURRENT_STEP=$((CURRENT_STEP + 1))

  case "$status" in
    OK)
      COUNT_OK=$((COUNT_OK + 1))
      echo -e "${CURRENT_STEP}/${TOTAL_STEPS} - [ ${GREEN}OK${NC} ] - ${message}"
      ;;
    FAIL)
      COUNT_FAIL=$((COUNT_FAIL + 1))
      echo -e "${CURRENT_STEP}/${TOTAL_STEPS} - [ ${RED}FAIL${NC} ] - ${message}"
      ;;
    SKIP)
      COUNT_SKIP=$((COUNT_SKIP + 1))
      echo -e "${CURRENT_STEP}/${TOTAL_STEPS} - [ ${YELLOW}SKIP${NC} ] - ${message}"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Sistema de Logging
# -----------------------------------------------------------------------------
setup_logging() {
  mkdir -p "$LOG_DIR"

  # Redireciona stdout e stderr para tee (tela + arquivo)
  exec > >(tee -a "$LOG_FILE") 2>&1

  # Header do log
  echo "=============================================="
  echo "Legendsclaw Bootstrap v${LEGENDSCLAW_VERSION}"
  echo "=============================================="
  echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Hostname: $(hostname)"
  echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Desconhecido')"
  echo "User: $(whoami)"
  echo "Log: ${LOG_FILE}"
  echo "=============================================="
  echo ""
}

# -----------------------------------------------------------------------------
# Verificacoes de Pre-requisito
# -----------------------------------------------------------------------------
check_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    feedback "OK" "Executando como root"
  else
    feedback "FAIL" "Este script precisa ser executado como root (use: sudo bash setup.sh)"
    exit 1
  fi
}

check_os() {
  local os_name
  os_name=$(cat /etc/os-release 2>/dev/null | grep "^ID=" | cut -d'=' -f2 | tr -d '"' || echo "unknown")
  local os_version
  os_version=$(cat /etc/os-release 2>/dev/null | grep "^VERSION_ID=" | cut -d'=' -f2 | tr -d '"' || echo "unknown")

  if [[ "$os_name" == "ubuntu" && "$os_version" == "22.04" ]]; then
    feedback "OK" "OS compativel: Ubuntu ${os_version}"
  elif [[ "$os_name" == "ubuntu" ]]; then
    feedback "OK" "Ubuntu ${os_version} detectado (recomendado: 22.04, mas continuando)"
  elif [[ "$os_name" == "debian" ]]; then
    feedback "OK" "Debian ${os_version} detectado (soft gate: nao e Ubuntu, mas continuando)"
  else
    echo -e "  ${YELLOW}AVISO: OS nao testado (${os_name} ${os_version}). Recomendado: Ubuntu 22.04${NC}"
    feedback "OK" "OS: ${os_name} ${os_version} (soft gate — continuando)"
  fi
}

check_connectivity() {
  if curl -s --max-time 5 -o /dev/null https://get.docker.com; then
    feedback "OK" "Conectividade com internet verificada"
  else
    feedback "FAIL" "Sem conectividade com internet"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Instalacao de Dependencias
# -----------------------------------------------------------------------------
install_if_missing() {
  local cmd_name="$1"
  local install_fn="$2"
  local description="$3"

  if command -v "$cmd_name" &>/dev/null; then
    feedback "SKIP" "${description} (ja instalado: $(${cmd_name} --version 2>/dev/null | head -1 || echo 'presente'))"
  else
    if $install_fn; then
      feedback "OK" "${description}"
    else
      feedback "FAIL" "${description}"
    fi
  fi
}

wait_for_apt_lock() {
  local max_wait=60
  local waited=0
  while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if [[ $waited -ge $max_wait ]]; then
      echo "  AVISO: apt lock nao liberado apos ${max_wait}s" >&2
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 0
}

install_apt_package() {
  local pkg="$1"
  local retries=3
  local i=0
  while [[ $i -lt $retries ]]; do
    wait_for_apt_lock || true
    if apt-get install -y "$pkg" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    [[ $i -lt $retries ]] && sleep $((i * 5))
  done
  return 1
}

_install_docker() {
  curl -fsSL https://get.docker.com | bash >/dev/null 2>&1 && \
  systemctl enable docker >/dev/null 2>&1 && \
  systemctl start docker >/dev/null 2>&1 && \
  _configure_docker_min_api
}

_configure_docker_min_api() {
  mkdir -p /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
  systemctl daemon-reload >/dev/null 2>&1
  systemctl restart docker >/dev/null 2>&1
}

_install_jq() {
  install_apt_package "jq"
}

_install_apache2_utils() {
  install_apt_package "apache2-utils"
}

_install_git() {
  install_apt_package "git"
}

_install_python3() {
  install_apt_package "python3"
}

_install_nodejs() {
  # Tentativa 1: NodeSource
  if curl -fsSL --max-time 30 https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1; then
    wait_for_apt_lock || true
    if apt-get install -y nodejs >/dev/null 2>&1; then
      return 0
    fi
  fi

  # Fallback: download binario direto
  local arch
  arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
  [[ "$arch" == "amd64" ]] && arch="x64"
  local node_url="https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-${arch}.tar.xz"
  if curl -fsSL --max-time 120 "$node_url" -o /tmp/node.tar.xz; then
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 >/dev/null 2>&1 && \
    rm -f /tmp/node.tar.xz
    return 0
  fi
  return 1
}

_install_pnpm() {
  # Habilita corepack (incluso com Node.js >= 16.13)
  corepack enable >/dev/null 2>&1 && \
  corepack prepare pnpm@latest --activate >/dev/null 2>&1
}

check_node_version() {
  if command -v node &>/dev/null; then
    local node_version
    node_version=$(node -v | sed 's/v//' | cut -d'.' -f1)
    if [[ "$node_version" -ge "$NODE_MIN_VERSION" ]]; then
      feedback "SKIP" "Node.js (ja instalado: v$(node -v | sed 's/v//'))"
      return 0
    else
      echo -e "  ${YELLOW}Node.js v$(node -v | sed 's/v//') encontrado, mas precisa >= ${NODE_MIN_VERSION}. Atualizando...${NC}"
      if _install_nodejs; then
        feedback "OK" "Node.js atualizado para v$(node -v | sed 's/v//')"
      else
        feedback "FAIL" "Falha ao atualizar Node.js"
      fi
      return 0
    fi
  else
    if _install_nodejs; then
      feedback "OK" "Node.js v$(node -v | sed 's/v//') instalado"
    else
      feedback "FAIL" "Falha ao instalar Node.js"
    fi
  fi
}

check_pnpm() {
  if command -v pnpm &>/dev/null; then
    feedback "SKIP" "pnpm (ja instalado: v$(pnpm --version 2>/dev/null || echo 'presente'))"
  else
    if ! command -v node &>/dev/null; then
      feedback "FAIL" "pnpm requer Node.js (nao instalado)"
    elif _install_pnpm; then
      feedback "OK" "pnpm instalado via corepack"
    else
      feedback "FAIL" "Falha ao instalar pnpm"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Estrutura de Estado (Pattern SetupOrion: ~/dados_vps/)
# -----------------------------------------------------------------------------
create_state_structure() {
  if [[ -d "$STATE_DIR" ]]; then
    feedback "SKIP" "Estrutura ${STATE_DIR} (ja existe)"
  else
    mkdir -p "$STATE_DIR"
    # Cria placeholders para estado futuro
    touch "$STATE_DIR/dados_vps"
    touch "$STATE_DIR/dados_portainer"
    touch "$STATE_DIR/dados_openclaw"
    touch "$STATE_DIR/dados_evolution"
    touch "$STATE_DIR/dados_n8n"
    touch "$STATE_DIR/dados_postgres"
    touch "$STATE_DIR/dados_tailscale"
    feedback "OK" "Estrutura ${STATE_DIR} criada"
  fi
}

# -----------------------------------------------------------------------------
# Resumo Final
# -----------------------------------------------------------------------------
show_summary() {
  echo ""
  echo -e "${BOLD}=============================================="
  echo "  RESUMO DO BOOTSTRAP"
  echo -e "==============================================${NC}"
  echo ""
  echo -e "  ${GREEN}OK${NC}:   ${COUNT_OK}"
  echo -e "  ${YELLOW}SKIP${NC}: ${COUNT_SKIP}"
  echo -e "  ${RED}FAIL${NC}: ${COUNT_FAIL}"
  echo ""

  # Versoes instaladas
  echo -e "${BOLD}Versoes instaladas:${NC}"
  echo -e "  Docker:   $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo 'nao instalado')"
  echo -e "  Node.js:  $(node -v 2>/dev/null || echo 'nao instalado')"
  echo -e "  pnpm:     $(pnpm --version 2>/dev/null || echo 'nao instalado')"
  echo -e "  jq:       $(jq --version 2>/dev/null || echo 'nao instalado')"
  echo -e "  git:      $(git --version 2>/dev/null | awk '{print $3}' || echo 'nao instalado')"
  echo -e "  python3:  $(python3 --version 2>/dev/null | awk '{print $2}' || echo 'nao instalado')"
  echo ""
  echo -e "  Log:     ${LOG_FILE}"
  echo -e "  Estado:  ${STATE_DIR}/"
  echo ""

  if [[ "$COUNT_FAIL" -gt 0 ]]; then
    echo -e "  ${RED}${BOLD}ATENCAO: ${COUNT_FAIL} falha(s) detectada(s). Revise o log.${NC}"
    echo ""
  else
    echo -e "  ${GREEN}${BOLD}Bootstrap completo! VPS pronta para deploy.${NC}"
    echo ""
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  setup_logging

  echo -e "${CYAN}${BOLD}Legendsclaw Bootstrap v${LEGENDSCLAW_VERSION}${NC}"
  echo -e "${CYAN}Preparando VPS para deploy...${NC}"
  echo ""

  # Pre-requisitos (Steps 1-3)
  check_root
  check_os
  check_connectivity

  # Resolve possivel dpkg interrompido antes de qualquer install
  dpkg --configure -a >/dev/null 2>&1 || true
  wait_for_apt_lock || true

  # apt update (Step 4) — com retry
  local apt_ok=false
  for attempt in 1 2 3; do
    if apt-get update >/dev/null 2>&1; then
      apt_ok=true
      break
    fi
    sleep $((attempt * 3))
  done
  if $apt_ok; then
    feedback "OK" "apt-get update"
  else
    feedback "FAIL" "apt-get update"
  fi

  # Dependencias (Steps 5-12)
  install_if_missing "docker" "_install_docker" "Docker"

  # Garante DOCKER_MIN_API_VERSION mesmo se Docker ja existia
  if ! grep -q "DOCKER_MIN_API_VERSION" /etc/systemd/system/docker.service.d/override.conf 2>/dev/null; then
    _configure_docker_min_api
    feedback "OK" "Docker MIN_API_VERSION configurado"
  else
    feedback "SKIP" "Docker MIN_API_VERSION (ja configurado)"
  fi
  install_if_missing "jq" "_install_jq" "jq"
  install_if_missing "htpasswd" "_install_apache2_utils" "apache2-utils (htpasswd)"
  install_if_missing "git" "_install_git" "Git"
  install_if_missing "python3" "_install_python3" "Python3"

  # Node.js precisa de check de versao especial
  check_node_version

  # pnpm precisa de check especial (via corepack)
  check_pnpm

  # Estrutura de estado (Step 13)
  create_state_structure

  # Resumo (Steps 14-15)
  feedback "SKIP" "apt-get upgrade (removido — pacotes individuais ja instalados)"
  feedback "OK" "Bootstrap finalizado"

  show_summary

  # Exit code baseado em falhas
  if [[ "$COUNT_FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

# Executa
main "$@"
