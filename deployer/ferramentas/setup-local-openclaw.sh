#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Setup Local OpenClaw (Mode Remote)
# Story 12.1: Instala OpenClaw e gera ~/.openclaw/openclaw.json com mode:remote
# Conecta ao gateway na VPS via WSS/Tailscale
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/auto.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# CONSTANTS
# =============================================================================
readonly OPENCLAW_DIR="$HOME/.openclaw"
readonly OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
readonly STATE_FILE_NAME="dados_local_openclaw"
readonly NODE_MIN_VERSION=18

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "setup-local-openclaw"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init 8

# =============================================================================
# STEP 2: IDEMPOTENCIA — SKIP SE JA CONFIGURADO
# =============================================================================
if [[ -f "$OPENCLAW_CONFIG" ]] && [[ -f "$STATE_DIR/${STATE_FILE_NAME}" ]]; then
  existing_mode=$(python3 -c "
import json, sys
try:
    d = json.load(open('${OPENCLAW_CONFIG}'))
    print(d.get('gateway', {}).get('mode', ''))
except: pass
" 2>/dev/null || true)

  if [[ "$existing_mode" == "remote" ]]; then
    step_skip "OpenClaw ja configurado em mode:remote (${OPENCLAW_CONFIG})"
    echo ""
    echo "  Para reconfigurar, remova: rm ${OPENCLAW_CONFIG}"
    echo "  e re-execute este script."
    echo ""
    resumo_final
    log_finish
    exit 0
  fi
fi

# =============================================================================
# STEP 3: VERIFICAR NODE.JS >= 18
# =============================================================================
if ! command -v node &>/dev/null; then
  step_fail "Node.js nao encontrado (requer v${NODE_MIN_VERSION}+)"
  echo "  Execute primeiro: ferramentas/setup-local.sh"
  exit 1
fi

node_version=$(node --version | sed 's/v//' | cut -d. -f1)
if [[ "$node_version" -lt "$NODE_MIN_VERSION" ]]; then
  step_fail "Node.js versao ${node_version} (requer v${NODE_MIN_VERSION}+)"
  exit 1
fi
step_ok "Node.js $(node --version) verificado"

# =============================================================================
# STEP 4: LER DADOS DO BRIDGE (hostname, tailnet, password)
# =============================================================================
dados

vps_hostname=""
tailnet=""
gateway_password=""
gateway_url=""

if [[ -f "$STATE_DIR/dados_bridge" ]]; then
  vps_hostname=$(grep "Tailscale Hostname:" "$STATE_DIR/dados_bridge" 2>/dev/null | awk -F': ' '{print $2}' || true)
  tailnet=$(grep "Tailscale Tailnet:" "$STATE_DIR/dados_bridge" 2>/dev/null | awk -F': ' '{print $2}' || true)
  gateway_url=$(grep "Gateway URL:" "$STATE_DIR/dados_bridge" 2>/dev/null | awk -F': ' '{print $2}' || true)
fi

# Fallback interativo se dados_bridge nao disponivel
if [[ -z "$vps_hostname" ]]; then
  echo ""
  echo -e "  ${UI_YELLOW:-\033[1;33m}dados_bridge nao encontrado — coleta manual.${UI_NC:-\033[0m}"
  echo ""
  input "openclaw.vps_hostname" "Hostname Tailscale da VPS (sem .ts.net): " vps_hostname --required
fi

if [[ -z "$tailnet" ]] || [[ "$tailnet" == "nao detectado" ]]; then
  input "openclaw.tailnet" "Tailnet (ex: tailnet-abc.ts.net): " tailnet --required
fi

if [[ -z "$gateway_password" ]]; then
  # Tentar ler do dados_gateway se existir
  if [[ -f "$STATE_DIR/dados_gateway" ]]; then
    gateway_password=$(grep "Gateway Password:" "$STATE_DIR/dados_gateway" 2>/dev/null | awk -F': ' '{print $2}' || true)
  fi
  if [[ -z "$gateway_password" ]]; then
    input "openclaw.gateway_password" "Password do gateway (WSS auth): " gateway_password --required --secret
  fi
fi

# Ler nome do agente
nome_agente=""
if [[ -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
fi
if [[ -z "$nome_agente" ]]; then
  input "openclaw.nome_agente" "Nome do agente: " nome_agente --required
fi

# Montar WSS URL
wss_url="wss://${vps_hostname}.${tailnet}"

step_ok "Dados coletados — VPS: ${vps_hostname}, Tailnet: ${tailnet}"

# =============================================================================
# STEP 5: INSTALAR/VERIFICAR OPENCLAW CLI
# =============================================================================
openclaw_version="unknown"

if command -v openclaw &>/dev/null; then
  openclaw_version=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
  step_ok "OpenClaw CLI ja instalado (${openclaw_version})"
else
  echo ""
  echo "  Instalando OpenClaw CLI..."

  install_ok="false"

  # Tentativa 1: installer oficial (recomendado)
  if curl -fsSL https://openclaw.ai/install.sh | bash --no-onboard 2>&1; then
    command -v openclaw &>/dev/null && install_ok="true"
  fi

  # Tentativa 2: npm global
  if [[ "$install_ok" == "false" ]] && command -v npm &>/dev/null; then
    echo "  Installer oficial falhou — tentando npm install..."
    if npm install -g openclaw 2>&1 | tail -5; then
      command -v openclaw &>/dev/null && install_ok="true"
    fi
  fi

  if [[ "$install_ok" == "true" ]]; then
    openclaw_version=$(openclaw --version 2>/dev/null | head -1 || echo "installed")
    step_ok "OpenClaw CLI instalado (${openclaw_version})"
  else
    step_ok "OpenClaw CLI nao instalado — config sera gerado mesmo assim"
    echo -e "  ${UI_YELLOW:-\033[1;33m}Instale manualmente: npm install -g openclaw${UI_NC:-\033[0m}"
  fi
fi

# =============================================================================
# STEP 6: CRIAR ~/.openclaw/ E GERAR openclaw.json
# =============================================================================
mkdir -p "$OPENCLAW_DIR"

# Backup se config existente
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  cp -p "$OPENCLAW_CONFIG" "${OPENCLAW_CONFIG}.bak"
  echo "  Backup criado: ${OPENCLAW_CONFIG}.bak"
fi

# Gerar openclaw.json com mode:remote
cat > "$OPENCLAW_CONFIG" << JSONEOF
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "${wss_url}",
      "password": "${gateway_password}"
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/auto" },
      "workspace": "${OPENCLAW_DIR}/workspace"
    }
  }
}
JSONEOF

chmod 600 "$OPENCLAW_CONFIG"
step_ok "Config gerado: ${OPENCLAW_CONFIG} (mode:remote)"

# =============================================================================
# STEP 7: TESTAR CONEXAO WSS (GRACEFUL FALLBACK)
# =============================================================================
wss_test="SKIP"

# Testar via HTTPS health (proxy do WSS)
https_url="https://${vps_hostname}.${tailnet}"
echo ""
echo "  Testando conexao ao gateway (${https_url}/health)..."

health_response=$(curl -sk --max-time 10 "${https_url}/health" 2>/dev/null || true)

if [[ -n "$health_response" ]]; then
  wss_test="OK"
  step_ok "Gateway remoto respondeu — WSS deve funcionar"
else
  # Tentar HTTP direto se Tailscale Serve nao ativo
  if [[ -n "$gateway_url" ]]; then
    health_response=$(curl -sk --max-time 10 "${gateway_url}/health" 2>/dev/null || true)
    if [[ -n "$health_response" ]]; then
      wss_test="OK"
      step_ok "Gateway remoto respondeu via HTTP direto"
    fi
  fi

  if [[ "$wss_test" != "OK" ]]; then
    wss_test="FAIL"
    step_ok "Gateway nao respondeu (pode estar offline — config salvo mesmo assim)"
    echo -e "  ${UI_YELLOW:-\033[1;33m}Dica: Verifique se o gateway esta rodando na VPS.${UI_NC:-\033[0m}"
    echo "  Teste manual: curl -sk ${https_url}/health"
  fi
fi

# =============================================================================
# STEP 8: SALVAR ESTADO + HINTS
# =============================================================================
mkdir -p "$STATE_DIR"

cat > "$STATE_DIR/${STATE_FILE_NAME}" << EOF
OpenClaw Version: ${openclaw_version}
Config Path: ${OPENCLAW_CONFIG}
Gateway Mode: remote
Gateway URL: ${wss_url}
WSS Test: ${wss_test}
Agente: ${nome_agente}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/${STATE_FILE_NAME}"

step_ok "Estado salvo em ~/dados_vps/${STATE_FILE_NAME}"

# --- Hints ---
echo ""
echo -e "${UI_BOLD:-\033[1m}=============================================="
echo "  HINT: PROXIMOS PASSOS — OPENCLAW REMOTE"
echo -e "==============================================${UI_NC:-\033[0m}"
echo ""
echo "  1. Verificar conexao ao gateway:"
echo "     openclaw status"
echo ""
echo "  2. Continuar setup local (AIOS init):"
echo "     O install.sh executara setup-local-aios.sh em seguida"
echo ""
echo "  Config: ${OPENCLAW_CONFIG}"
echo "  Estado: ~/dados_vps/${STATE_FILE_NAME}"
echo ""
echo "=============================================="
echo ""

resumo_final

echo ""
echo -e "${UI_BOLD:-\033[1m}  Setup Local OpenClaw — Configuracao Completa${UI_NC:-\033[0m}"
echo ""
echo "  Agente:        ${nome_agente}"
echo "  Gateway WSS:   ${wss_url}"
echo "  Config:        ${OPENCLAW_CONFIG}"
echo "  WSS Test:      ${wss_test}"
echo "  Estado:        ~/dados_vps/${STATE_FILE_NAME}"
echo "  Log:           ${LOG_FILE}"

log_finish
