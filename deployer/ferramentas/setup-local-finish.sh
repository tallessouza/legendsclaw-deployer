#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Setup Local: Instrucoes Finais
# Chamado pelo install.sh (source) — roda do repo atualizado
# =============================================================================

# Ler dados reais dos state files
_state_dir="${HOME}/dados_vps"
_agent_name=$(grep "Agente:" "$_state_dir/dados_bridge" 2>/dev/null | awk -F': ' '{print $2}' || true)
_agent_name="${_agent_name:-seu-agente}"
_aios_dir=$(grep "Diretorio:" "$_state_dir/dados_aios_init" 2>/dev/null | awk -F': ' '{print $2}' || true)
_aios_dir="${_aios_dir:-${INSTALL_DIR:-$HOME/legendsclaw}}"

echo ""
echo -e "\033[1m\033[0;36m=============================================="
echo -e "  SETUP LOCAL CONCLUIDO!"
echo -e "==============================================\033[0m"
echo ""
echo -e "  Seu ambiente local esta pronto."
echo -e "  Para ativar o agente no Claude Code:"
echo -e "  \033[1mcd ${_aios_dir} && @${_agent_name}\033[0m"
echo ""
echo -e "  Para verificar o bridge:"
echo -e "  \033[1mcd ${_aios_dir} && node .aios-core/infrastructure/services/bridge.js status\033[0m"
echo ""
