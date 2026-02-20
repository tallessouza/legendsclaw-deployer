#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 05: OpenClaw Gateway
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

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "openclaw"
step_init 13

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
  step_fail "Traefik + Portainer nao encontrados (~/dados_vps/dados_portainer ausente)"
  echo "  Execute primeiro: Ferramenta [01] Traefik + Portainer (base)"
  exit 1
fi
step_ok "Estado carregado — dados_portainer encontrado"

# =============================================================================
# STEP 4: CHECK DEPENDENCIES — Traefik, Portainer, Node.js >= 22, pnpm, git
# =============================================================================
deps_ok=true

# Verificar stacks Docker
if ! verificar_stack "traefik"; then
  echo "  AVISO: Stack Traefik nao encontrada no Docker Swarm"
  deps_ok=false
fi
if ! verificar_stack "portainer"; then
  echo "  AVISO: Stack Portainer nao encontrada no Docker Swarm"
  deps_ok=false
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
  step_ok "Dependencias verificadas (Traefik, Portainer, Node.js >= 22, pnpm, git)"
else
  step_fail "Dependencias faltando — verifique os avisos acima"
  echo "  Execute primeiro: Ferramenta [01] (base) e setup.sh (bootstrap)"
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
  hint_troubleshoot_openclaw "" ""
  resumo_final
  log_finish
  exit 0
fi

step_ok "OpenClaw nao instalado — prosseguindo com instalacao"

# =============================================================================
# STEP 6: INPUT COLLECTION — dominio, porta, repo URL
# =============================================================================
while true; do
  echo ""
  read -rp "Dominio para o OpenClaw Gateway (ex: gw.exemplo.com): " dominio_openclaw
  if [[ -z "$dominio_openclaw" ]]; then
    echo "Dominio nao pode ser vazio."
    continue
  fi

  read -rp "Porta do gateway (default 18789): " porta_input
  porta_openclaw="${porta_input:-18789}"

  read -rp "URL do repositorio (default https://github.com/openclaw/openclaw.git): " repo_input
  repo_url="${repo_input:-https://github.com/openclaw/openclaw.git}"

  conferindo_as_info \
    "Dominio=${dominio_openclaw}" \
    "Porta=${porta_openclaw}" \
    "Repositorio=${repo_url}" \
    "Install Path=/opt/openclaw"

  read -rp "As informacoes estao corretas? (s/n): " confirma
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
clonado=false
for tentativa in 1 2 3; do
  echo "  Tentativa ${tentativa}/3: Clonando ${repo_url}..."
  if git clone "$repo_url" /opt/openclaw 2>&1; then
    clonado=true
    break
  else
    echo "  Falha na tentativa ${tentativa}/3"
    # Limpar diretorio parcial se existir
    rm -rf /opt/openclaw
    if [[ "$tentativa" -lt 3 ]]; then
      sleep 5
    fi
  fi
done

if $clonado; then
  step_ok "Repositorio clonado em /opt/openclaw"
else
  step_fail "Falha ao clonar repositorio apos 3 tentativas"
  exit 1
fi

# =============================================================================
# STEP 8: BUILD — pnpm install + ui:build + build
# =============================================================================
pushd /opt/openclaw > /dev/null

# 8a: pnpm install (retry 3x)
instalado=false
for tentativa in 1 2 3; do
  echo "  Tentativa ${tentativa}/3: pnpm install..."
  if pnpm install 2>&1; then
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
# STEP 9: ONBOARD
# =============================================================================
if pnpm openclaw onboard --install-daemon 2>&1; then
  step_ok "OpenClaw onboard concluido"
else
  step_fail "OpenClaw onboard falhou"
  exit 1
fi

popd > /dev/null

# =============================================================================
# STEP 10: VERIFICAR PORTA LIVRE
# =============================================================================
if ss -tlnp 2>/dev/null | grep -q ":${porta_openclaw} "; then
  step_fail "Porta ${porta_openclaw} ja esta em uso"
  echo "  Verifique com: ss -tlnp | grep ${porta_openclaw}"
  echo "  Considere usar uma porta diferente"
  exit 1
fi
step_ok "Porta ${porta_openclaw} disponivel"

# =============================================================================
# STEP 11: GERAR SYSTEMD UNIT
# =============================================================================
cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=OpenClaw Gateway
After=network.target tailscaled.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw
ExecStart=/usr/bin/node openclaw.mjs gateway --port ${porta_openclaw}
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

step_ok "Systemd unit criada (/etc/systemd/system/openclaw.service)"

# =============================================================================
# STEP 12: ENABLE + START SERVICE
# =============================================================================
systemctl daemon-reload
systemctl enable openclaw
systemctl start openclaw

step_ok "Servico openclaw habilitado e iniciado"

# =============================================================================
# STEP 13: HEALTH CHECK (retry 5x, 10s intervalo)
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
# SALVAR ESTADO
# =============================================================================
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/dados_openclaw" << EOF
URL Gateway: https://${dominio_openclaw}
Porta: ${porta_openclaw}
Repo: ${repo_url}
Install Path: /opt/openclaw
Systemd Unit: /etc/systemd/system/openclaw.service
EOF
chmod 600 "$STATE_DIR/dados_openclaw"

# =============================================================================
# RESUMO FINAL
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  OpenClaw Gateway${UI_NC}"
echo ""
echo "  URL:       https://${dominio_openclaw}"
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
read -rp "Deseja executar a validacao end-to-end agora? [S/n]: " validar
if [[ ! "$validar" =~ ^[Nn]$ ]]; then
  log_finish
  bash "${SCRIPT_DIR}/06-validacao-gw.sh"
else
  log_finish
fi
