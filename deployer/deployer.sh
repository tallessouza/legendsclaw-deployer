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
readonly D_RED='\033[0;31m'
readonly D_NC='\033[0m'

# Executa uma ferramenta e verifica exit code
# Uso: run_ferramenta "ferramentas/01-base.sh"
run_ferramenta() {
  local script="$1"
  if bash "${SCRIPT_DIR}/${script}"; then
    if [[ "${AUTO_MODE:-false}" != "true" ]]; then
      read -rp "Pressione ENTER para voltar ao menu..."
    fi
  else
    echo ""
    echo -e "${D_RED}Ferramenta falhou. Verifique o log em ~/legendsclaw-logs/${D_NC}"
    if [[ "${AUTO_MODE:-false}" != "true" ]]; then
      read -rp "Pressione ENTER para voltar ao menu..."
    fi
  fi
}

show_menu() {
  clear
  echo -e "${D_CYAN}${D_BOLD}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║         LEGENDSCLAW DEPLOYER v${DEPLOYER_VERSION}            ║"
  echo "╠══════════════════════════════════════════════╣"
  echo -e "║  ${D_GREEN}[01] Traefik + Portainer (base)${D_CYAN}             ║"
  echo -e "║  ${D_GREEN}[02] Tailscale VPN${D_CYAN}                          ║"
  echo -e "║  ${D_GREEN}[03] OpenClaw Gateway${D_CYAN}                       ║"
  echo -e "║  ${D_GREEN}[04] Validacao Gateway (ping + health)${D_CYAN}     ║"
  echo -e "║  ${D_GREEN}[05] Whitelabel — Identidade do Agente${D_CYAN}     ║"
  echo -e "║  ${D_GREEN}[06] Workspace Files (SOUL, AGENTS, IDENTITY)${D_CYAN}║"
  echo -e "║  ${D_GREEN}[07] LLM Router — Tiers e API Keys${D_CYAN}         ║"
  echo -e "║  ${D_GREEN}[08] Skills AIOS — Configurar Skills${D_CYAN}        ║"
  echo -e "║  ${D_GREEN}[09] Elicitation — Skill de Entrevistas${D_CYAN}    ║"
  echo -e "║  ${D_GREEN}[10] Elicitation Schema — Tabelas e Seeds${D_CYAN} ║"
  echo -e "║  ${D_GREEN}[11] Seguranca (3 Layers)${D_CYAN}                   ║"
  echo -e "║  ${D_GREEN}[12] Bridge — Claude Code Integration${D_CYAN}      ║"
  echo -e "║  ${D_GREEN}[13] Evolution API (cascade Postgres)${D_CYAN}      ║"
  echo -e "║  ${D_GREEN}[14] Gateway Config (aiosbot, node, .env, MCP)${D_CYAN}║"
  echo -e "║  ${D_GREEN}[15] Validacao Final — Teste End-to-End${D_CYAN}    ║"
  echo -e "║  ${D_GRAY}[00] Sair${D_CYAN}                                    ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${D_NC}"
}

main() {
  while true; do
    show_menu
    read -rp "Escolha uma opcao: " opcao

    case "$opcao" in
      01|1)  run_ferramenta "ferramentas/01-base.sh" ;;
      02|2)  run_ferramenta "ferramentas/02-tailscale.sh" ;;
      03|3)  run_ferramenta "ferramentas/03-openclaw.sh" ;;
      04|4)  run_ferramenta "ferramentas/04-validacao-gw.sh" ;;
      05|5)  run_ferramenta "ferramentas/05-whitelabel.sh" ;;
      06|6)  run_ferramenta "ferramentas/06-workspace.sh" ;;
      07|7)  run_ferramenta "ferramentas/07-llm-router.sh" ;;
      08|8)  run_ferramenta "ferramentas/08-skills.sh" ;;
      09|9)  run_ferramenta "ferramentas/09-elicitation.sh" ;;
      10)    run_ferramenta "ferramentas/10-elicitation-schema.sh" ;;
      11)    run_ferramenta "ferramentas/11-seguranca.sh" ;;
      12)    run_ferramenta "ferramentas/12-bridge.sh" ;;
      13)    run_ferramenta "ferramentas/13-evolution.sh" ;;
      14)    run_ferramenta "ferramentas/14-gateway-config.sh" ;;
      15)    run_ferramenta "ferramentas/15-validacao-final.sh" ;;
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
