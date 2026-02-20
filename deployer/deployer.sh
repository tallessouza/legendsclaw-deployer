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
  echo -e "║  ${D_GREEN}[02] PostgreSQL (standalone)${D_CYAN}                 ║"
  echo -e "║  ${D_GREEN}[03] Evolution API (instala Postgres se faltar)${D_CYAN}║"
  echo -e "║  ${D_GREEN}[04] Tailscale VPN${D_CYAN}                          ║"
  echo -e "║  ${D_GREEN}[05] OpenClaw Gateway${D_CYAN}                       ║"
  echo -e "║  ${D_GRAY}[06] N8N (Workflows)             [EM BREVE]${D_CYAN}  ║"
  echo -e "║  ${D_GREEN}[07] Whitelabel — Identidade do Agente${D_CYAN}     ║"
  echo -e "║  ${D_GREEN}[08] LLM Router — Tiers e API Keys${D_CYAN}         ║"
  echo -e "║  ${D_GREEN}[09] Skills AIOS — Configurar Skills${D_CYAN}        ║"
  echo -e "║  ${D_GREEN}[10] Elicitation — Skill de Entrevistas${D_CYAN}    ║"
  echo -e "║  ${D_GREEN}[11] Elicitation Schema — Tabelas e Seeds${D_CYAN} ║"
  echo -e "║  ${D_GREEN}[12] Seguranca (3 Layers)${D_CYAN}                   ║"
  echo -e "║  ${D_GREEN}[13] Bridge — Claude Code Integration${D_CYAN}      ║"
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
        bash "${SCRIPT_DIR}/ferramentas/02-postgres.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      03|3)
        bash "${SCRIPT_DIR}/ferramentas/03-evolution.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      04|4)
        bash "${SCRIPT_DIR}/ferramentas/04-tailscale.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      05|5)
        bash "${SCRIPT_DIR}/ferramentas/05-openclaw.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      07|7)
        bash "${SCRIPT_DIR}/ferramentas/07-whitelabel.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      08|8)
        bash "${SCRIPT_DIR}/ferramentas/08-llm-router.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      09|9)
        bash "${SCRIPT_DIR}/ferramentas/09-skills.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      10)
        bash "${SCRIPT_DIR}/ferramentas/10-elicitation.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      11)
        bash "${SCRIPT_DIR}/ferramentas/11-elicitation-schema.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      12)
        bash "${SCRIPT_DIR}/ferramentas/12-seguranca.sh"
        read -rp "Pressione ENTER para voltar ao menu..."
        ;;
      13)
        bash "${SCRIPT_DIR}/ferramentas/13-bridge.sh"
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
