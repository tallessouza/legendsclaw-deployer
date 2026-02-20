#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Contextual Hints
# hint_firewall(), hint_dns(), hint_provider()
# =============================================================================

# Hint de firewall — tabela de portas necessarias
# Uso: hint_firewall
hint_firewall() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: CONFIGURACAO DE FIREWALL"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Antes de prosseguir, certifique-se de que as"
  echo "  seguintes portas estao abertas no firewall da VPS:"
  echo ""
  echo "  Porta       Protocolo   Servico"
  echo "  -----       ---------   -------"
  echo "  22          TCP         SSH"
  echo "  80          TCP         HTTP (Traefik)"
  echo "  443         TCP         HTTPS (Traefik)"
  echo "  9443        TCP         Portainer"
  echo "  2377        TCP         Docker Swarm manager"
  echo "  7946        TCP+UDP     Swarm node communication"
  echo "  4789        UDP         Overlay network"
  echo "  41641       UDP         Tailscale"
  echo ""
  echo "  No painel Hetzner: Networking > Firewalls"
  echo "  No painel AWS: Security Groups > Inbound Rules"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de DNS — registros A necessarios
# Uso: hint_dns "$dominio_portainer"
hint_dns() {
  local dominio="${1:-portainer.exemplo.com}"
  local ip_vps
  ip_vps=$(curl -s https://ifconfig.me 2>/dev/null || echo "SEU_IP_VPS")

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: CONFIGURACAO DE DNS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Configure os seguintes registros DNS tipo A:"
  echo ""
  echo "  Tipo   Nome                        Valor"
  echo "  ----   ----                        -----"
  echo "  A      ${dominio}    ${ip_vps}"
  echo ""
  echo "  Propagacao DNS pode levar 5-30 minutos."
  echo "  Verifique com: dig ${dominio} +short"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de provider — dicas especificas por cloud provider
# Uso: hint_provider "hetzner"
hint_provider() {
  local provider="${1:-hetzner}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: DICAS ${provider^^}"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  case "$provider" in
    hetzner)
      echo "  - Firewall: Cloud Console > Networking > Firewalls"
      echo "  - DNS: Pode usar Cloudflare ou Hetzner DNS"
      echo "  - Servidor recomendado: CX21+ (2 vCPU, 4GB RAM)"
      echo "  - Datacenter: Helsinki (hel1) ou Falkenstein (fsn1)"
      ;;
    aws)
      echo "  - Firewall: EC2 > Security Groups"
      echo "  - DNS: Route 53 ou externo"
      echo "  - Instancia recomendada: t3.medium+"
      ;;
    *)
      echo "  - Configure firewall conforme tabela de portas acima"
      echo "  - Configure DNS A records para seus dominios"
      ;;
  esac

  echo ""
  echo "=============================================="
  echo ""
}

# Hint de setup Tailscale no desktop
# Uso: hint_tailscale_desktop "$hostname" "$ip" "$ambiente"
hint_tailscale_desktop() {
  local hostname="${1:-meu-gateway}"
  local ip="${2:-TAILSCALE_IP}"
  local ambiente="${3:-vps}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: INSTALAR TAILSCALE NO DESKTOP"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  echo "  Windows:"
  echo "    Baixe: https://tailscale.com/download/windows"
  echo "    Ou via winget: winget install Tailscale.Tailscale"
  echo ""
  echo "  Mac:"
  echo "    brew install --cask tailscale"
  echo "    Ou App Store: pesquise 'Tailscale'"
  echo ""
  echo "  WSL2 (Linux):"
  echo "    curl -fsSL https://tailscale.com/install.sh | sh"
  echo "    sudo tailscale up"
  echo ""

  if [[ "$ambiente" == "vps" ]]; then
    echo "  Apos instalar no desktop, autentique com a"
    echo "  mesma conta Tailscale usada na VPS."
  else
    echo "  Apos instalar no desktop, autentique com a"
    echo "  mesma conta Tailscale usada nesta maquina."
  fi
  echo ""
  echo "  Verifique conectividade com:"
  echo "    tailscale ping ${hostname}"
  echo ""
  echo "  IP Tailscale desta maquina: ${ip}"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de DNS para OpenClaw Gateway
# Uso: hint_dns_openclaw "$dominio"
hint_dns_openclaw() {
  local dominio="${1:-gw.exemplo.com}"
  local ip_vps
  ip_vps=$(curl -s https://ifconfig.me 2>/dev/null || echo "SEU_IP_VPS")

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: DNS PARA OPENCLAW GATEWAY"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Configure o registro DNS tipo A:"
  echo ""
  echo "  Tipo   Nome                        Valor"
  echo "  ----   ----                        -----"
  echo "  A      ${dominio}    ${ip_vps}"
  echo ""
  echo "  Propagacao DNS pode levar 5-30 minutos."
  echo "  Verifique com: dig ${dominio} +short"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de troubleshooting para OpenClaw Gateway
# Uso: hint_troubleshoot_openclaw "$porta" "$dominio"
hint_troubleshoot_openclaw() {
  local porta="${1:-18789}"
  local dominio="${2:-}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: TROUBLESHOOTING OPENCLAW"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Verificar status do servico:"
  echo "    systemctl status openclaw"
  echo ""
  echo "  Ver logs em tempo real:"
  echo "    journalctl -u openclaw -f"
  echo ""
  echo "  Verificar porta:"
  echo "    ss -tlnp | grep ${porta}"
  echo ""
  echo "  Health check manual:"
  echo "    curl http://localhost:${porta}/health"
  echo ""
  echo "  Verificar conectividade Tailscale:"
  echo "    tailscale status"
  if [[ -n "$dominio" ]]; then
    echo "    curl https://${dominio}/health"
  fi
  echo ""
  echo "  Reiniciar servico:"
  echo "    systemctl restart openclaw"
  echo ""
  echo "  Verificar diagnostico:"
  echo "    cd /opt/openclaw && pnpm openclaw doctor"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de validacao gateway — hints contextuais por tipo de erro
# Uso: hint_validacao_gw "$tailscale_result" "$service_result" "$doctor_result" "$health_result" "$mensagem_result" "$porta"
hint_validacao_gw() {
  local tailscale_result="${1:-PASS}"
  local service_result="${2:-PASS}"
  local doctor_result="${3:-PASS}"
  local health_result="${4:-PASS}"
  local mensagem_result="${5:-PASS}"
  local porta="${6:-18789}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: RESOLUCAO DE PROBLEMAS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  if [[ "$tailscale_result" == "FAIL" ]]; then
    echo "  TAILSCALE DESCONECTADO:"
    echo "    tailscale up"
    echo "    tailscale status"
    echo "    # Se auth expirada:"
    echo "    tailscale up --reset"
    echo ""
  fi

  if [[ "$service_result" == "FAIL" ]]; then
    echo "  OPENCLAW SERVICE PARADO:"
    echo "    systemctl start openclaw"
    echo "    systemctl status openclaw"
    echo "    journalctl -u openclaw --no-pager -n 50"
    echo ""
  fi

  if [[ "$doctor_result" == "FAIL" ]]; then
    echo "  OPENCLAW DOCTOR FALHOU:"
    echo "    cd /opt/openclaw && pnpm openclaw doctor --verbose"
    echo "    # Verificar dependencias:"
    echo "    node --version  # deve ser >= 22"
    echo "    pnpm --version"
    echo ""
  fi

  if [[ "$health_result" == "FAIL" ]]; then
    echo "  HEALTH CHECK FALHOU:"
    echo "    # Verificar se porta esta escutando:"
    echo "    ss -tlnp | grep ${porta}"
    echo "    # Verificar logs:"
    echo "    journalctl -u openclaw -f"
    echo "    # Restart:"
    echo "    systemctl restart openclaw"
    echo ""
  fi

  if [[ "$mensagem_result" == "FAIL" ]]; then
    echo "  TESTE DE MENSAGEM FALHOU:"
    echo "    cd /opt/openclaw"
    echo "    pnpm openclaw agent --message \"Teste\" --thinking high --verbose"
    echo "    # Verificar configuracao de LLM providers"
    echo "    # Verificar logs: journalctl -u openclaw -f"
    echo ""
  fi

  echo "=============================================="
  echo ""
}

# Hint de proximos passos para whitelabel
# Uso: hint_whitelabel "$nome_agente"
hint_whitelabel() {
  local nome_agente="${1:-meu-agente}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Configurar LLM Router:"
  echo "     deployer.sh → Ferramenta [08]"
  echo ""
  echo "  2. Editar credenciais no config.js:"
  echo "     apps/${nome_agente}/skills/config.js"
  echo ""
  echo "  3. Criar definicao AIOS do agente no desktop:"
  echo "     No Claude Code: @aios-master *create agent"
  echo "     Ou manualmente: .aios-core/development/agents/${nome_agente}.md"
  echo "     (requer AIOS Core instalado no projeto)"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de debug e proximos passos para LLM Router
# Uso: hint_llm_router "$nome_agente"
hint_llm_router() {
  local nome_agente="${1:-meu-agente}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: LLM ROUTER — DEBUG E PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Verificar keys configuradas:"
  echo "     grep API_KEY /opt/openclaw/.env"
  echo ""
  echo "  2. Testar manualmente:"
  echo "     curl -H 'Authorization: Bearer \$OPENROUTER_API_KEY' \\"
  echo "       https://openrouter.ai/api/v1/models"
  echo ""
  echo "  3. Config do router:"
  echo "     apps/${nome_agente}/config/llm-router-config.yaml"
  echo ""
  echo "  4. Proximo: configurar skills do agente (Epics futuros)"
  echo ""
  echo "=============================================="
  echo ""
}
