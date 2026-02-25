#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Test Suite: Local Setup
# Smoke test: OpenClaw CLI, bridge, hooks, config, gateway mode remote, WSS URL
# Uso: ./test-local.sh
# Story: 12.9
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYER_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${DEPLOYER_DIR}/lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"

log_init "test-local"
setup_trap

OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
BRIDGE_SCRIPT="${SCRIPT_DIR}/../../.aios-core/infrastructure/services/bridge.js"

echo "Test Suite Local Setup"
echo ""

step_init 6

# --- CHECK 1: OpenClaw CLI instalado ---
if command -v openclaw >/dev/null 2>&1; then
  step_ok "OpenClaw CLI instalado ($(command -v openclaw))"
elif [[ -d "/opt/openclaw" ]]; then
  step_ok "OpenClaw instalado em /opt/openclaw"
else
  step_fail "OpenClaw nao encontrado (nem CLI nem /opt/openclaw)"
fi

# --- CHECK 2: Bridge funcional ---
if [[ -f "$BRIDGE_SCRIPT" ]]; then
  if node "$BRIDGE_SCRIPT" status >/dev/null 2>&1; then
    step_ok "Bridge funcional (status OK)"
  else
    step_fail "Bridge reportou erro (execute: node $BRIDGE_SCRIPT status)"
  fi
else
  step_fail "Bridge script nao encontrado: ${BRIDGE_SCRIPT}"
fi

# --- CHECK 3: Hooks configurados ---
SETTINGS_FILE="${HOME}/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  if grep -q "bridge.js" "$SETTINGS_FILE" 2>/dev/null; then
    step_ok "Hooks configurados (.claude/settings.json contem bridge.js)"
  else
    step_fail "Hooks NAO configurados (.claude/settings.json nao contem bridge.js)"
  fi
else
  step_fail "settings.json nao encontrado: ${SETTINGS_FILE}"
fi

# --- CHECK 4: Config JSON valido ---
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  if node -e "JSON.parse(require('fs').readFileSync('$OPENCLAW_CONFIG', 'utf8'))" >/dev/null 2>&1; then
    step_ok "openclaw.json valido (JSON parse OK)"
  else
    step_fail "openclaw.json invalido (JSON parse falhou)"
  fi
else
  step_fail "openclaw.json nao encontrado: ${OPENCLAW_CONFIG}"
fi

# --- CHECK 5: gateway.mode == "remote" ---
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  gw_mode=$(node -e "
    try {
      const c = require('$OPENCLAW_CONFIG');
      console.log((c.gateway && c.gateway.mode) || '');
    } catch(e) { console.log(''); }
  " 2>/dev/null || true)

  if [[ "$gw_mode" == "remote" ]]; then
    step_ok "gateway.mode == \"remote\""
  else
    step_fail "gateway.mode == \"${gw_mode:-<nao definido>}\" (esperado: \"remote\")"
  fi
else
  step_fail "openclaw.json nao encontrado: ${OPENCLAW_CONFIG}"
fi

# --- CHECK 6: gateway.remote.url começa com wss:// ---
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  remote_url=$(node -e "
    try {
      const c = require('$OPENCLAW_CONFIG');
      console.log((c.gateway && c.gateway.remote && c.gateway.remote.url) || '');
    } catch(e) { console.log(''); }
  " 2>/dev/null || true)

  if [[ "$remote_url" == wss://* ]]; then
    step_ok "gateway.remote.url comeca com wss:// (${remote_url})"
  else
    step_fail "gateway.remote.url = \"${remote_url:-<nao definido>}\" (esperado: wss://...)"
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
