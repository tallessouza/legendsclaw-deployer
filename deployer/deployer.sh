#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Menu Principal
# Entry point para todas as ferramentas de deploy
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly DEPLOYER_VERSION="1.0.0"

# Cores
readonly D_CYAN='\033[0;36m'
readonly D_GREEN='\033[0;32m'
readonly D_YELLOW='\033[1;33m'
readonly D_GRAY='\033[0;90m'
readonly D_BOLD='\033[1m'
readonly D_NC='\033[0m'

show_menu() {
  clear
  echo -e "${D_CYAN}${D_BOLD}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║         LEGENDSCLAW DEPLOYER v${DEPLOYER_VERSION}            ║"
  echo "╠══════════════════════════════════════════════╣"
  echo -e "║  ${D_GREEN}[01] Traefik + Portainer (base)${D_CYAN}             ║"
  echo -e "║  ${D_GREEN}[02] Postgres + Evolution API${D_CYAN}               ║"
  echo -e "║  ${D_GREEN}[03] Tailscale VPN${D_CYAN}                          ║"
  echo -e "║  ${D_GRAY}[04] OpenClaw Gateway            [EM BREVE]${D_CYAN}  ║"
  echo -e "║  ${D_GRAY}[05] N8N (Workflows)             [EM BREVE]${D_CYAN}  ║"
  echo -e "║  ${D_GRAY}[00] Sair${D_CYAN}                                    ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${D_NC}"
}

main() {
  while true; do
    show_menu
    read -rp "Escolha uma opcao: " opcao

    case "$opcao" in
      01|1)
        bash "${SCRIPT_DIR}/ferramentas/01-base.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      02|2)
        bash "${SCRIPT_DIR}/ferramentas/03-evolution.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      03|3)
        bash "${SCRIPT_DIR}/ferramentas/04-tailscale.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      00|0)
        echo "Ate mais!"
        exit 0
        ;;
      *)
        echo -e "${D_YELLOW}Opcao invalida ou ainda nao disponivel.${D_NC}"
        sleep 2
        ;;
    esac
  done
}

main "$@"
