#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Test Suite: Gateway (VPS)
# Smoke test: gateway health, Tailscale, WSS, agents.list, llm-router
# Uso: ./test-gateway.sh [agente]
# Story: 12.9
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYER_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${DEPLOYER_DIR}/lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"

log_init "test-gateway"
setup_trap

# --- Detectar agente ---
nome_agente="${1:-}"
if [[ -z "$nome_agente" && -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
fi

if [[ -z "$nome_agente" ]]; then
  echo "ERRO: Nome do agente nao informado e dados_whitelabel nao encontrado."
  echo "Uso: $0 [agente]"
  exit 1
fi

OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"

echo "Test Suite Gateway — Agente: ${nome_agente}"
echo ""

# --- Determinar total de checks ---
total_checks=3  # health + agents.list + llm-router
has_tailscale=false
has_wss=false

if [[ -f "$STATE_DIR/dados_tailscale" ]]; then
  has_tailscale=true
  total_checks=$((total_checks + 1))
fi

if [[ -f "$OPENCLAW_CONFIG" ]]; then
  ts_mode=$(node -e "
    try {
      const c = require('$OPENCLAW_CONFIG');
      console.log((c.gateway && c.gateway.tailscale && c.gateway.tailscale.mode) || '');
    } catch(e) { console.log(''); }
  " 2>/dev/null || true)
  if [[ "$ts_mode" == "serve" ]]; then
    has_wss=true
    total_checks=$((total_checks + 1))
  fi
fi

step_init "$total_checks"

# --- CHECK 1: Gateway health (localhost) ---
gw_port=$(grep "Porta:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}' || echo "19888")

if curl -sf --max-time 5 "http://localhost:${gw_port}/health" >/dev/null 2>&1; then
  step_ok "Gateway acessivel em localhost:${gw_port}/health"
else
  step_fail "Gateway inacessivel em localhost:${gw_port}/health"
fi

# --- CHECK 2: Tailscale endpoint (condicional) ---
if [[ "$has_tailscale" == "true" ]]; then
  ts_hostname=$(grep "hostname_tailscale:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ts_tailnet=$(grep "tailnet:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)

  if [[ -n "$ts_hostname" && -n "$ts_tailnet" ]]; then
    ts_url="http://${ts_hostname}.${ts_tailnet}:${gw_port}/health"
    if curl -sf --max-time 5 "$ts_url" >/dev/null 2>&1; then
      step_ok "Tailscale endpoint acessivel: ${ts_url}"
    else
      step_fail "Tailscale endpoint inacessivel: ${ts_url}"
    fi
  else
    step_fail "dados_tailscale incompleto (hostname_tailscale ou tailnet ausente)"
  fi
else
  # Nao contabilizado — nao incrementa
  :
fi

# --- CHECK 3: WSS endpoint (condicional) ---
if [[ "$has_wss" == "true" ]]; then
  ts_hostname=$(grep "hostname_tailscale:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ts_tailnet=$(grep "tailnet:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)

  if [[ -n "$ts_hostname" && -n "$ts_tailnet" ]]; then
    wss_url="https://${ts_hostname}.${ts_tailnet}"
    # WSS usa HTTPS — testar com curl
    if curl -sf --max-time 5 "${wss_url}/health" >/dev/null 2>&1; then
      step_ok "WSS endpoint acessivel: ${wss_url}"
    else
      step_fail "WSS endpoint inacessivel: ${wss_url}"
    fi
  else
    step_fail "Nao foi possivel construir WSS URL (dados_tailscale incompleto)"
  fi
fi

# --- CHECK 4: Agente registrado em agents.list ---
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  agent_found=$(node -e "
    try {
      const c = require('$OPENCLAW_CONFIG');
      const list = (c.agents && c.agents.list) || [];
      const found = list.some(a => a.id === '${nome_agente}');
      console.log(found ? 'yes' : 'no');
    } catch(e) { console.log('error'); }
  " 2>/dev/null || echo "error")

  if [[ "$agent_found" == "yes" ]]; then
    step_ok "Agente '${nome_agente}' registrado em agents.list[]"
  else
    step_fail "Agente '${nome_agente}' NAO encontrado em agents.list[]"
  fi
else
  step_fail "openclaw.json nao encontrado: ${OPENCLAW_CONFIG}"
fi

# --- CHECK 5: LLM Router como provider ---
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  router_found=$(node -e "
    try {
      const c = require('$OPENCLAW_CONFIG');
      const has = c.models && c.models.providers && c.models.providers['llm-router'];
      console.log(has ? 'yes' : 'no');
    } catch(e) { console.log('error'); }
  " 2>/dev/null || echo "error")

  if [[ "$router_found" == "yes" ]]; then
    step_ok "models.providers.llm-router registrado no openclaw.json"
  else
    step_fail "models.providers.llm-router NAO encontrado no openclaw.json"
  fi
else
  step_fail "openclaw.json nao encontrado: ${OPENCLAW_CONFIG}"
fi

# --- Resumo ---
resumo_final
log_finish

if [[ "$STEP_FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
