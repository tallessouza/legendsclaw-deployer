#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 03: OpenClaw Gateway
# Story 2.1: Build & deploy OpenClaw como systemd service
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"
source "${LIB_DIR}/deploy.sh"
source "${LIB_DIR}/auto.sh"

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "openclaw"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init 13

# Versao estavel do OpenClaw (v2026.2.22+ quebra channels.whatsapp.enabled)
readonly OPENCLAW_TAG="v2026.2.21"

# =============================================================================
# STEP 2: RESOURCE GATE — 2 vCPU, 4GB RAM
# =============================================================================
if recursos 2 4; then
  step_ok "Recursos verificados (2 vCPU, 4GB RAM minimo)"
else
  step_fail "Recursos insuficientes — minimo 2 vCPU e 4GB RAM"
  exit 1
fi

# =============================================================================
# STEP 3: LOAD STATE + VERIFICAR DEPENDENCIA BASE
# =============================================================================
dados
if [[ ! -f "$STATE_DIR/dados_portainer" ]]; then
  step_skip "Traefik + Portainer nao encontrados (opcional — OpenClaw funciona sem eles)"
  echo "  Para HTTPS com dominio publico, execute: Ferramenta [01] Traefik + Portainer"
else
  step_ok "Estado carregado — dados_portainer encontrado"
fi

# =============================================================================
# STEP 4: CHECK DEPENDENCIES — Node.js >= 22, pnpm, git (Traefik/Portainer opcional)
# =============================================================================
deps_ok=true

# Verificar stacks Docker (opcional — apenas aviso)
if ! verificar_stack "traefik" 2>/dev/null; then
  echo "  INFO: Stack Traefik nao encontrada (opcional — HTTPS via dominio nao disponivel)"
fi
if ! verificar_stack "portainer" 2>/dev/null; then
  echo "  INFO: Stack Portainer nao encontrada (opcional — gestao Docker via UI nao disponivel)"
fi

# Verificar Node.js >= 22
if command -v node &>/dev/null; then
  node_version=$(node --version | sed 's/v//' | cut -d. -f1)
  if [[ "$node_version" -lt 22 ]]; then
    echo "  AVISO: Node.js v${node_version} encontrado, mas >= 22 e obrigatorio"
    deps_ok=false
  fi
else
  echo "  AVISO: Node.js nao encontrado"
  deps_ok=false
fi

# Verificar pnpm
if ! command -v pnpm &>/dev/null; then
  echo "  AVISO: pnpm nao encontrado"
  deps_ok=false
fi

# Verificar git
if ! command -v git &>/dev/null; then
  echo "  AVISO: git nao encontrado"
  deps_ok=false
fi

if $deps_ok; then
  step_ok "Dependencias verificadas (Node.js >= 22, pnpm, git)"
else
  step_fail "Dependencias faltando — verifique os avisos acima"
  echo "  Execute: setup.sh (instala Node.js, pnpm, git automaticamente)"
  exit 1
fi

# =============================================================================
# STEP 5: VERIFICAR SE OPENCLAW JA ESTA INSTALADO
# =============================================================================
if [[ -d "/opt/openclaw" ]] && systemctl is-active openclaw &>/dev/null; then
  step_skip "OpenClaw ja instalado e ativo"
  echo ""
  echo "  Service: $(systemctl is-active openclaw)"
  echo "  Path:    /opt/openclaw"
  echo "  Dados:   ~/dados_vps/dados_openclaw"
  echo ""
  auto_confirm "Deseja reinstalar o OpenClaw do zero? (s/n): " reinstalar
  if [[ ! "$reinstalar" =~ ^[Ss]$ ]]; then
    hint_troubleshoot_openclaw "" ""
    resumo_final
    log_finish
    exit 0
  fi
  echo "  Removendo instalacao anterior..."
  sudo systemctl stop openclaw 2>/dev/null || true
  sudo systemctl disable openclaw 2>/dev/null || true
  sudo rm -f /etc/systemd/system/openclaw.service
  sudo systemctl daemon-reload
  sudo rm -rf /opt/openclaw
  step_ok "Instalacao anterior removida — reinstalando"
else
  step_ok "OpenClaw nao instalado — prosseguindo com instalacao"
fi

# =============================================================================
# STEP 6: INPUT COLLECTION — dominio, porta, repo URL
# =============================================================================
while true; do
  echo ""
  input "openclaw.dominio" "Dominio para o OpenClaw Gateway (ex: gw.exemplo.com): " dominio_openclaw --required
  if [[ -z "$dominio_openclaw" ]]; then
    echo "Dominio nao pode ser vazio."
    continue
  fi

  input "openclaw.porta" "Porta do gateway (default 18789): " porta_input --default=18789
  porta_openclaw="${porta_input:-18789}"

  input "openclaw.repo" "URL do repositorio (default https://github.com/openclaw/openclaw.git): " repo_input --default=https://github.com/openclaw/openclaw.git
  repo_url="${repo_input:-https://github.com/openclaw/openclaw.git}"

  conferindo_as_info \
    "Dominio=${dominio_openclaw}" \
    "Porta=${porta_openclaw}" \
    "Repositorio=${repo_url}" \
    "Install Path=/opt/openclaw"

  auto_confirm "As informacoes estao corretas? (s/n): " confirma
  if [[ "$confirma" =~ ^[Ss]$ ]]; then
    break
  fi
done

step_ok "Inputs coletados"

# Hint de DNS
hint_dns_openclaw "$dominio_openclaw"

# =============================================================================
# STEP 7: CLONAR REPOSITORIO
# =============================================================================
if [[ -d "/opt/openclaw/.git" ]]; then
  # Repositorio ja existe — atualizar
  echo "  Repositorio ja existe em /opt/openclaw — atualizando..."
  if sudo git -C /opt/openclaw pull --ff-only 2>&1; then
    step_ok "Repositorio atualizado em /opt/openclaw (git pull)"
  else
    step_skip "Repositorio ja existe em /opt/openclaw (pull falhou — usando versao atual)"
  fi
else
  # Limpar diretorio nao-git se existir
  if [[ -d "/opt/openclaw" ]]; then
    sudo rm -rf /opt/openclaw
  fi

  clonado=false
  for tentativa in 1 2 3; do
    echo "  Tentativa ${tentativa}/3: Clonando ${repo_url}..."
    if sudo git clone --branch "$OPENCLAW_TAG" --depth 1 "$repo_url" /opt/openclaw 2>&1; then
      clonado=true
      break
    else
      echo "  Falha na tentativa ${tentativa}/3"
      sudo rm -rf /opt/openclaw
      if [[ "$tentativa" -lt 3 ]]; then
        sleep 5
      fi
    fi
  done

  if $clonado; then
    # Dar ownership ao user atual para que pnpm/build funcione sem sudo
    sudo chown -R "$(id -u):$(id -g)" /opt/openclaw
    step_ok "Repositorio clonado em /opt/openclaw"
  else
    step_fail "Falha ao clonar repositorio apos 3 tentativas"
    exit 1
  fi
fi

# =============================================================================
# STEP 8: BUILD — pnpm install + ui:build + build
# =============================================================================
pushd /opt/openclaw > /dev/null

# 8a: pnpm install (retry 3x, shamefully-hoist para vendor/a2ui ver deps)
instalado=false
for tentativa in 1 2 3; do
  echo "  Tentativa ${tentativa}/3: pnpm install --shamefully-hoist..."
  if pnpm install --shamefully-hoist 2>&1; then
    instalado=true
    break
  else
    echo "  Falha na tentativa ${tentativa}/3"
    if [[ "$tentativa" -lt 3 ]]; then
      sleep 5
    fi
  fi
done

if $instalado; then
  step_ok "pnpm install concluido"
else
  step_fail "pnpm install falhou apos 3 tentativas"
  exit 1
fi

# 8b: pnpm ui:build
if pnpm ui:build 2>&1; then
  step_ok "pnpm ui:build concluido"
else
  step_fail "pnpm ui:build falhou"
  echo "  Verifique os logs acima para detalhes"
  exit 1
fi

# 8c: pnpm build
if pnpm build 2>&1; then
  step_ok "pnpm build concluido"
else
  step_fail "pnpm build falhou"
  echo "  Verifique os logs acima para detalhes"
  exit 1
fi

# =============================================================================
# STEP 9: ONBOARD INTERATIVO — credenciais, gateway, canais, skills, hooks
# =============================================================================
current_user="$(whoami)"

# --no-install-daemon: evita systemd user service que falha como root
# Gateway port passada como sugestao (usuario pode alterar no wizard)
if pnpm openclaw onboard --no-install-daemon --gateway-port "${porta_openclaw}" 2>&1; then
  step_ok "OpenClaw onboard concluido"
else
  step_fail "OpenClaw onboard falhou"
  echo "  Voce pode tentar novamente depois com:"
  echo "    cd /opt/openclaw && pnpm openclaw onboard --no-install-daemon"
fi

popd > /dev/null

# =============================================================================
# STEP 9b: GARANTIR PORTA NO openclaw.json
# O onboard pode ignorar --gateway-port e usar a porta padrao no config.
# Forcamos a porta definida pelo usuario no openclaw.json.
# =============================================================================
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  if command -v jq &>/dev/null; then
    jq --argjson port "${porta_openclaw}" '.gateway.port = $port' "$OPENCLAW_CONFIG" > "${OPENCLAW_CONFIG}.tmp" \
      && mv "${OPENCLAW_CONFIG}.tmp" "$OPENCLAW_CONFIG"
  elif command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$OPENCLAW_CONFIG') as f: cfg = json.load(f)
cfg.setdefault('gateway', {})['port'] = ${porta_openclaw}
with open('$OPENCLAW_CONFIG', 'w') as f: json.dump(cfg, f, indent=2)
"
  else
    # Fallback: sed simples
    sed -i "s/\"port\": [0-9]*/\"port\": ${porta_openclaw}/" "$OPENCLAW_CONFIG"
  fi
  echo "  Porta ${porta_openclaw} configurada em ${OPENCLAW_CONFIG}"
fi

# =============================================================================
# STEP 10: SYSTEMD SERVICE
# =============================================================================
# Parar service anterior se existir
sudo systemctl stop openclaw 2>/dev/null || true

echo "  Instalando systemd system service..."
sudo tee /etc/systemd/system/openclaw.service > /dev/null << SVCEOF
[Unit]
Description=OpenClaw Gateway
After=network.target tailscaled.service

[Service]
Type=simple
User=${current_user}
WorkingDirectory=/opt/openclaw
ExecStart=$(command -v node) openclaw.mjs gateway --port ${porta_openclaw}
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable --now openclaw
sleep 3
if systemctl is-active openclaw &>/dev/null; then
  step_ok "OpenClaw rodando como system service (porta ${porta_openclaw})"
else
  step_fail "Falha ao iniciar OpenClaw system service"
  echo "  Verifique com: sudo journalctl -u openclaw -n 20"
  exit 1
fi

# =============================================================================
# STEP 11: HEALTH CHECK (retry 5x, 10s intervalo)
# =============================================================================
health_ok=false
for tentativa in 1 2 3 4 5; do
  echo "  Health check ${tentativa}/5..."
  if curl -sf "http://localhost:${porta_openclaw}/health" &>/dev/null; then
    health_ok=true
    break
  fi
  if [[ "$tentativa" -lt 5 ]]; then
    sleep 10
  fi
done

if $health_ok; then
  step_ok "Health check OK — gateway respondendo na porta ${porta_openclaw}"
else
  step_fail "Health check falhou apos 5 tentativas"
  echo ""
  hint_troubleshoot_openclaw "$porta_openclaw" ""
  exit 1
fi

# =============================================================================
# STEP 12: TAILSCALE SERVE — expor gateway via Tailscale (sem abrir firewall)
# =============================================================================
tailscale_serve_url=""
if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
  echo ""
  echo "  Configurando Tailscale Serve para expor gateway na tailnet..."
  if sudo tailscale serve --bg "${porta_openclaw}" 2>/dev/null; then
    # Extrair hostname Tailscale
    ts_hostname=$(tailscale status --json 2>/dev/null | grep -o '"Self":{"ID[^}]*"HostName":"[^"]*"' | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || true)
    ts_tailnet=$(tailscale status --json 2>/dev/null | grep -o '"MagicDNSSuffix":"[^"]*"' | cut -d'"' -f4 || true)
    if [[ -n "$ts_hostname" && -n "$ts_tailnet" ]]; then
      tailscale_serve_url="https://${ts_hostname}.${ts_tailnet}"
    fi
    step_ok "Tailscale Serve ativo — gateway acessivel via tailnet na porta ${porta_openclaw}"
  else
    step_skip "Tailscale Serve nao disponivel (gateway acessivel apenas localmente)"
  fi
else
  step_skip "Tailscale nao conectado — Serve nao configurado"
fi

# =============================================================================
# SALVAR ESTADO
# =============================================================================
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/dados_openclaw" << EOF
Porta: ${porta_openclaw}
Tailscale Serve URL: ${tailscale_serve_url:-N/A}
Dominio: ${dominio_openclaw}
Repo: ${repo_url}
Install Path: /opt/openclaw
Systemd Unit: ~/.config/systemd/user/openclaw-gateway.service (via onboard)
EOF
chmod 600 "$STATE_DIR/dados_openclaw"

# =============================================================================
# RESUMO FINAL
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  OpenClaw Gateway${UI_NC}"
echo ""
if [[ -n "$tailscale_serve_url" ]]; then
  echo "  Tailscale: ${tailscale_serve_url}"
fi
echo "  Dominio:   https://${dominio_openclaw}"
echo "  Porta:     ${porta_openclaw}"
echo "  Repo:      ${repo_url}"
echo "  Path:      /opt/openclaw"
echo "  Service:   openclaw.service"
echo ""
echo "  Dados:     ~/dados_vps/dados_openclaw"
echo "  Log:       ${LOG_FILE}"
echo ""

# Hints de troubleshooting
hint_troubleshoot_openclaw "$porta_openclaw" "$dominio_openclaw"

# Oferecer validacao end-to-end
echo ""
input "openclaw.validar_agora" "Deseja executar a validacao end-to-end agora? [S/n]: " validar --default=s
if [[ ! "$validar" =~ ^[Nn]$ ]]; then
  log_finish
  bash "${SCRIPT_DIR}/04-validacao-gw.sh"
else
  log_finish
fi
