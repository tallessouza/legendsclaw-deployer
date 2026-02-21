#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Installer — One-Liner para VM limpa
# Uso: bash <(curl -sSL https://raw.githubusercontent.com/<org>/legendsclaw-deployer/main/install.sh)
# Compativel: Ubuntu 22.04+ (soft gate para outros OS)
# =============================================================================

readonly INSTALL_VERSION="1.0.0"
readonly INSTALL_DIR="/opt/legendsclaw"
readonly REPO_URL="https://github.com/tallessouza/legendsclaw-deployer.git"
readonly TOTAL_STEPS=8
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly LOG_DIR="$HOME/legendsclaw-logs"
readonly LOG_FILE="$LOG_DIR/install-${TIMESTAMP}.log"

# Cores ANSI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Contadores
CURRENT_STEP=0
COUNT_OK=0
COUNT_SKIP=0
COUNT_FAIL=0

# --- Logging (inline — roda antes do clone) ---
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=============================================="
echo "  Legendsclaw Installer v${INSTALL_VERSION}"
echo "=============================================="
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Hostname: $(hostname)"
echo "OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo 'Desconhecido')"
echo "User: $(whoami)"
echo "Log: ${LOG_FILE}"
echo "=============================================="
echo ""

# --- Trap Handlers ---
cleanup_on_fail() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "" >&2
    echo -e "${RED}Instalacao falhou no step ${CURRENT_STEP}/${TOTAL_STEPS} (exit code: $exit_code)${NC}" >&2
    echo -e "${RED}Log: ${LOG_FILE}${NC}" >&2
    echo ""
    echo -e "${BOLD}RESUMO${NC}"
    echo -e "  ${GREEN}OK${NC}:   ${COUNT_OK}"
    echo -e "  ${YELLOW}SKIP${NC}: ${COUNT_SKIP}"
    echo -e "  ${RED}FAIL${NC}: ${COUNT_FAIL}"
  fi
}
trap 'cleanup_on_fail' EXIT
trap 'echo "Interrompido pelo usuario"; exit 130' INT TERM

# --- Feedback Visual (Pattern SetupOrion N/M) ---
feedback() {
  local status="$1"
  local message="$2"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  case "$status" in
    OK)   COUNT_OK=$((COUNT_OK + 1));   echo -e "${CURRENT_STEP}/${TOTAL_STEPS} - [ ${GREEN}OK${NC} ] - ${message}" ;;
    FAIL) COUNT_FAIL=$((COUNT_FAIL + 1)); echo -e "${CURRENT_STEP}/${TOTAL_STEPS} - [ ${RED}FAIL${NC} ] - ${message}" ;;
    SKIP) COUNT_SKIP=$((COUNT_SKIP + 1)); echo -e "${CURRENT_STEP}/${TOTAL_STEPS} - [ ${YELLOW}SKIP${NC} ] - ${message}" ;;
  esac
}

# =============================================================================
# STEP 1: Determinar user real (funciona com sudo, root direto, ou user normal)
# =============================================================================
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_USER="$SUDO_USER"
  REAL_GROUP="$(id -gn "$SUDO_USER")"
elif [[ $EUID -eq 0 ]]; then
  # Root direto — tentar detectar user logado
  REAL_USER="$(logname 2>/dev/null || who am i 2>/dev/null | awk '{print $1}' || echo root)"
  REAL_GROUP="$(id -gn "$REAL_USER" 2>/dev/null || echo root)"
else
  REAL_USER="$(whoami)"
  REAL_GROUP="$(id -gn)"
fi

# Verificar se consegue usar sudo (necessario para /opt/)
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
  feedback FAIL "Precisa de sudo para instalar em /opt/ (use: sudo bash install.sh)"
  exit 1
fi
feedback OK "User: ${REAL_USER} (executando como $(whoami))"

# =============================================================================
# STEP 2: OS check (soft gate)
# =============================================================================
OS_ID=$(grep -oP '^ID=\K\w+' /etc/os-release 2>/dev/null || echo "unknown")
if [[ "$OS_ID" == "ubuntu" ]]; then
  feedback OK "Sistema operacional: Ubuntu"
else
  feedback SKIP "OS detectado: ${OS_ID} (recomendado: Ubuntu 22.04+)"
fi

# =============================================================================
# STEP 3: Conectividade
# =============================================================================
if curl -sI --connect-timeout 5 https://github.com > /dev/null 2>&1; then
  feedback OK "Conectividade com github.com"
else
  feedback FAIL "Sem conectividade com github.com"
  exit 1
fi

# =============================================================================
# STEP 4: Git
# =============================================================================
if command -v git > /dev/null 2>&1; then
  feedback SKIP "git ja instalado ($(git --version | cut -d' ' -f3))"
else
  apt-get update -qq > /dev/null 2>&1 && apt-get install -y git > /dev/null 2>&1
  feedback OK "git instalado"
fi

# =============================================================================
# STEP 5: Clone / Pull
# =============================================================================
if [[ -d "$INSTALL_DIR/.git" ]]; then
  if git -C "$INSTALL_DIR" pull --ff-only > /dev/null 2>&1; then
    feedback OK "Repositorio atualizado (git pull)"
  else
    feedback FAIL "Falha ao atualizar repositorio (git pull)"
    exit 1
  fi
elif [[ -d "$INSTALL_DIR" ]]; then
  feedback FAIL "${INSTALL_DIR} existe mas nao e um repositorio git"
  exit 1
else
  # Criar /opt/legendsclaw com sudo se necessario, clonar como user real
  if [[ $EUID -ne 0 ]]; then
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "${REAL_USER}:${REAL_GROUP}" "$INSTALL_DIR"
  else
    mkdir -p "$INSTALL_DIR"
  fi
  if git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1; then
    # Garantir ownership ao user real para que ferramentas funcionem sem sudo
    if [[ "$REAL_USER" != "root" ]] && [[ $EUID -eq 0 ]]; then
      chown -R "${REAL_USER}:${REAL_GROUP}" "$INSTALL_DIR"
    fi
    feedback OK "Repositorio clonado em ${INSTALL_DIR} (owner: ${REAL_USER})"
  else
    feedback FAIL "Falha ao clonar repositorio"
    exit 1
  fi
fi

# =============================================================================
# STEP 6: Executar setup.sh
# =============================================================================
if bash "${INSTALL_DIR}/setup.sh"; then
  feedback OK "Dependencias instaladas com sucesso"
else
  feedback FAIL "setup.sh falhou (verifique o log acima)"
  exit 1
fi

# =============================================================================
# STEP 7: Instrucoes finais
# =============================================================================
echo ""
echo -e "${BOLD}${CYAN}=============================================="
echo "  INSTALACAO CONCLUIDA!"
echo "==============================================${NC}"
echo ""
echo -e "  Proximo passo:"
echo -e "  ${BOLD}cd ${INSTALL_DIR} && bash deployer.sh${NC}"
echo ""
feedback OK "Instrucoes exibidas"

# =============================================================================
# STEP 8: Resumo
# =============================================================================
echo ""
echo -e "${BOLD}RESUMO${NC}"
echo -e "  ${GREEN}OK${NC}:   ${COUNT_OK}"
echo -e "  ${YELLOW}SKIP${NC}: ${COUNT_SKIP}"
echo -e "  ${RED}FAIL${NC}: ${COUNT_FAIL}"
echo -e "  Log: ${LOG_FILE}"
feedback OK "Instalacao finalizada"
