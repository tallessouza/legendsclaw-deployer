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
