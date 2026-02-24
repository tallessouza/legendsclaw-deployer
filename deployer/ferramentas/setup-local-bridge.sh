#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Setup Local Bridge
# Story 11.2: Bridge Local→VPS Bidirecional via Tailscale
# Configura bridge entre maquina local e gateway OpenClaw na VPS
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
# Repo root — deployer/ esta um nivel abaixo do repo
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
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "setup-local-bridge"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init 10

# =============================================================================
# STEP 2: VERIFICAR DEPENDENCIAS
# =============================================================================

# Node.js >= 18
if ! command -v node &>/dev/null; then
  step_fail "Node.js nao encontrado (requer v18+)"
  echo "  Execute primeiro: ferramentas/setup-local.sh"
  exit 1
fi

node_version=$(node --version | sed 's/v//' | cut -d. -f1)
if [[ "$node_version" -lt 18 ]]; then
  step_fail "Node.js versao ${node_version} (requer v18+)"
  exit 1
fi

# Tailscale
tailscale_installed="false"
tailscale_connected="false"

if command -v tailscale &>/dev/null; then
  tailscale_installed="true"
  if tailscale status &>/dev/null; then
    tailscale_connected="true"
  fi
fi

if [[ "$tailscale_installed" == "false" ]]; then
  step_fail "Tailscale nao instalado"
  echo "  Execute primeiro: ferramentas/setup-local.sh"
  exit 1
fi

if [[ "$tailscale_connected" == "true" ]]; then
  step_ok "Dependencias verificadas — Node $(node --version), Tailscale conectado"
else
  step_fail "Tailscale instalado mas NAO conectado"
  echo -e "  ${UI_YELLOW}WARNING: Tailscale nao conectado. Bridge sera configurada offline.${UI_NC}"
  echo "  Para conectar: sudo tailscale up"
fi

# jq (necessario para merge de settings.json e Tailscale JSON)
jq_available="false"
if command -v jq &>/dev/null; then
  jq_available="true"
fi

if [[ "$jq_available" == "false" ]]; then
  # Verificar se Python3 esta disponivel como fallback
  if ! command -v python3 &>/dev/null; then
    step_fail "Nem jq nem python3 encontrados (necessario para merge de settings.json)"
    echo "  Instale jq: sudo apt-get install -y jq (Linux) | brew install jq (macOS)"
    exit 1
  fi
  echo -e "  ${UI_YELLOW}jq nao encontrado — usando Python3 como fallback para JSON${UI_NC}"
fi

# =============================================================================
# STEP 3: COLETA DE DADOS — HOSTNAME, PORTA, AGENTE
# =============================================================================

# Nome do agente
dados
nome_agente=""
if [[ -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
fi

if [[ -z "$nome_agente" ]]; then
  input "bridge.nome_agente" "Nome do agente: " nome_agente --required
fi

# Hostname Tailscale da VPS
vps_hostname=""
input "bridge.vps_hostname" "Hostname Tailscale da VPS (sem .ts.net): " vps_hostname --required

# Validar hostname (regex: apenas alfanumerico e hifens)
while [[ ! "$vps_hostname" =~ ^[a-zA-Z0-9-]+$ ]]; do
  echo -e "  ${UI_RED}Hostname invalido: apenas letras, numeros e hifens permitidos${UI_NC}"
  input "bridge.vps_hostname" "Hostname Tailscale da VPS (sem .ts.net): " vps_hostname --required
done

# Porta do gateway
porta_gateway=""
input "bridge.porta_gateway" "Porta do gateway OpenClaw [18789]: " porta_gateway --default=18789

# Detectar tailnet suffix
tailnet=""
if [[ "$tailscale_connected" == "true" && "$jq_available" == "true" ]]; then
  tailnet=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix' 2>/dev/null || true)
fi

if [[ -z "$tailnet" ]]; then
  if [[ "$tailscale_connected" == "true" && "$jq_available" == "false" ]]; then
    # Fallback Python para extrair MagicDNSSuffix
    tailnet=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('MagicDNSSuffix',''))" 2>/dev/null || true)
  fi
fi

if [[ -z "$tailnet" ]]; then
  echo ""
  echo -e "  ${UI_YELLOW}Nao foi possivel detectar o tailnet automaticamente.${UI_NC}"
  input "bridge.tailnet_fqdn" "FQDN completo da VPS (ex: meu-vps.tailnet-name.ts.net): " fqdn_completo --required
  # Validar formato hostname.tailnet.ts.net
  while [[ ! "$fqdn_completo" =~ ^[a-zA-Z0-9-]+\..+\.ts\.net$ ]]; do
    echo -e "  ${UI_RED}Formato invalido. Esperado: hostname.tailnet-name.ts.net${UI_NC}"
    input "bridge.tailnet_fqdn" "FQDN completo da VPS: " fqdn_completo --required
  done
  GATEWAY_URL="http://${fqdn_completo}:${porta_gateway}"
  # Extrair tailnet do FQDN para state file
  tailnet=$(echo "$fqdn_completo" | sed "s/^${vps_hostname}\.//" || echo "$fqdn_completo")
else
  GATEWAY_URL="http://${vps_hostname}.${tailnet}:${porta_gateway}"
fi

step_ok "Dados coletados"

# =============================================================================
# STEP 4: CONFIRMAR INFORMACOES
# =============================================================================
conferindo_as_info \
  "Agente=${nome_agente}" \
  "VPS Hostname=${vps_hostname}" \
  "Tailnet=${tailnet:-nao detectado}" \
  "Gateway URL=${GATEWAY_URL}" \
  "Tailscale=${tailscale_connected}"

auto_confirm "As informacoes estao corretas? (s/n): " confirma
if ! [[ "$confirma" =~ ^[Ss]$ ]]; then
  echo "Cancelado pelo usuario."
  exit 0
fi
step_ok "Informacoes confirmadas"

# =============================================================================
# STEP 5: VERIFICAR CONECTIVIDADE TAILSCALE
# =============================================================================
if [[ "$tailscale_connected" == "true" ]]; then
  # Tailscale ping
  echo ""
  echo "  Verificando conectividade Tailscale..."
  if tailscale ping --timeout 30s -c 1 "$vps_hostname" &>/dev/null; then
    step_ok "Tailscale ping para '${vps_hostname}' OK"
  else
    step_fail "Tailscale ping para '${vps_hostname}' falhou"
    echo -e "  ${UI_YELLOW}Dica: Se firewall corporativo bloqueia UDP, Tailscale usa DERP relay (HTTPS).${UI_NC}"
    echo "  Verifique: tailscale status"
  fi

  # Health check do gateway
  echo "  Verificando saude do gateway remoto..."
  health_start=$(date +%s%N 2>/dev/null || date +%s)
  health_response=$(curl -s --max-time 10 "${GATEWAY_URL}/health" 2>/dev/null || true)
  health_end=$(date +%s%N 2>/dev/null || date +%s)

  if [[ -n "$health_response" ]]; then
    # Calcular latencia (em ms se nanosegundos disponivel)
    if [[ "$health_start" =~ ^[0-9]{10,}$ ]]; then
      latency_ms=$(( (health_end - health_start) / 1000000 ))
    else
      latency_ms=$(( health_end - health_start ))
      latency_ms=$(( latency_ms * 1000 ))
    fi
    step_ok "Gateway remoto respondeu (${latency_ms}ms)"
  else
    step_ok "Gateway remoto nao respondeu (pode estar offline — bridge sera configurada mesmo assim)"
    echo -e "  ${UI_YELLOW}Dica: Gateway pode estar desligado na VPS. Bridge funciona quando voltar.${UI_NC}"
  fi
else
  step_skip "Tailscale ping — Tailscale offline"
  step_skip "Gateway health — Tailscale offline"
fi

# =============================================================================
# STEP 6: CRIAR SERVICE INDEX
# =============================================================================
SERVICES_DIR=".aios-core/infrastructure/services"
AGENT_SERVICE_DIR="${SERVICES_DIR}/${nome_agente}"

mkdir -p "$AGENT_SERVICE_DIR"

cat > "${AGENT_SERVICE_DIR}/index.js" << JSEOF
'use strict';

// Service: ${nome_agente} — OpenClaw Gateway Health Check (Local→VPS via Tailscale)
// Generated by Legendsclaw Deployer (Story 11.2)

const http = require('http');
const https = require('https');

const GATEWAY_URL = process.env.OPENCLAW_GATEWAY_URL
  || process.env.AGENT_GATEWAY_URL
  || '${GATEWAY_URL}';

const DEGRADED_THRESHOLD_MS = 2000;

module.exports = {
  name: '${nome_agente}',
  description: 'OpenClaw Gateway health for ${nome_agente}',

  health: async () => {
    const url = new URL(GATEWAY_URL + '/health');
    const mod = url.protocol === 'https:' ? https : http;

    const start = Date.now();

    return new Promise((resolve) => {
      const req = mod.get(url, { timeout: 5000 }, (res) => {
        const latency_ms = Date.now() - start;
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200) {
            const status = latency_ms > DEGRADED_THRESHOLD_MS ? 'degraded' : 'ok';
            resolve({ status, latency_ms, details: body.slice(0, 100) });
          } else {
            resolve({ status: 'down', latency_ms, details: 'HTTP ' + res.statusCode });
          }
        });
      });

      req.on('error', (err) => {
        const latency_ms = Date.now() - start;
        resolve({ status: 'down', latency_ms, error: err.message });
      });

      req.on('timeout', () => {
        req.destroy();
        const latency_ms = Date.now() - start;
        resolve({ status: 'down', latency_ms, error: 'timeout' });
      });
    });
  },
};
JSEOF

step_ok "Service index criado: ${AGENT_SERVICE_DIR}/index.js"

# =============================================================================
# STEP 7: CONFIGURAR CLAUDE CODE HOOKS — MERGE
# =============================================================================
SETTINGS_FILE=".claude/settings.json"

# Hooks JSON a configurar
HOOKS_JSON='{
  "SessionStart": [
    {
      "type": "command",
      "command": "node .aios-core/infrastructure/services/bridge.js status 2>/dev/null || echo '\''[Bridge] Offline — VPN may be disconnected'\''"
    }
  ],
  "PreToolUse(Bash)": [
    {
      "type": "command",
      "command": "node .aios-core/infrastructure/services/bridge.js validate-call 2>/dev/null || true"
    }
  ],
  "PostToolUse(Bash)": [
    {
      "type": "command",
      "command": "node .aios-core/infrastructure/services/bridge.js log-execution 2>/dev/null || true"
    }
  ]
}'

if [[ -f "$SETTINGS_FILE" ]]; then
  # Verificar se hooks ja configurados
  if grep -q "bridge.js" "$SETTINGS_FILE" 2>/dev/null; then
    step_skip "Hooks ja configurados em ${SETTINGS_FILE}"
  else
    # Backup
    cp -p "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
    echo "  Backup criado: ${SETTINGS_FILE}.bak"

    # Merge hooks mantendo outras configs
    if [[ "$jq_available" == "true" ]]; then
      jq --argjson hooks "$HOOKS_JSON" '.hooks = $hooks' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" \
        && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    else
      # Fallback Python
      python3 -c "
import json, sys
with open('${SETTINGS_FILE}', 'r') as f:
    d = json.load(f)
d['hooks'] = json.loads(sys.argv[1])
with open('${SETTINGS_FILE}', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$HOOKS_JSON"
    fi
    step_ok "Hooks configurados em ${SETTINGS_FILE} (backup em .bak)"
  fi
else
  # Criar novo settings.json
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  cat > "$SETTINGS_FILE" << JSONEOF
{
  "language": "portuguese",
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "node .aios-core/infrastructure/services/bridge.js status 2>/dev/null || echo '[Bridge] Offline — VPN may be disconnected'"
      }
    ],
    "PreToolUse(Bash)": [
      {
        "type": "command",
        "command": "node .aios-core/infrastructure/services/bridge.js validate-call 2>/dev/null || true"
      }
    ],
    "PostToolUse(Bash)": [
      {
        "type": "command",
        "command": "node .aios-core/infrastructure/services/bridge.js log-execution 2>/dev/null || true"
      }
    ]
  }
}
JSONEOF
  step_ok "Hooks configurados em ${SETTINGS_FILE} (novo arquivo)"
fi

# =============================================================================
# STEP 8: VERIFICAR BRIDGE.JS CORE E TESTAR
# =============================================================================
BRIDGE_FILE="${SERVICES_DIR}/bridge.js"

if [[ ! -f "$BRIDGE_FILE" ]]; then
  step_fail "bridge.js nao encontrado em ${BRIDGE_FILE}"
  echo "  Copie do repositorio: .aios-core/infrastructure/services/bridge.js"
  exit 1
fi

echo ""
echo "  Testando bridge.js..."

bridge_list_ok="false"
bridge_status_ok="false"

# Test list
if node "${BRIDGE_FILE}" list 2>/dev/null; then
  bridge_list_ok="true"
fi

# Test status (pode falhar se gateway offline — OK)
if node "${BRIDGE_FILE}" status 2>/dev/null; then
  bridge_status_ok="true"
fi

if [[ "$bridge_list_ok" == "true" ]]; then
  step_ok "bridge.js list funcional"
else
  step_fail "bridge.js list falhou"
fi

if [[ "$bridge_status_ok" == "true" ]]; then
  step_ok "bridge.js status funcional"
else
  step_ok "bridge.js status executou (gateway pode estar offline — normal)"
fi

# =============================================================================
# STEP 9: SALVAR ESTADO
# =============================================================================
mkdir -p "$STATE_DIR"

services_count=$(node "${BRIDGE_FILE}" list 2>/dev/null | grep -c "  [a-z]" || echo "0")

cat > "$STATE_DIR/dados_bridge" << EOF
Agente: ${nome_agente}
Gateway URL: ${GATEWAY_URL}
Bridge Status: configurado
Hooks Configured: true
Services Count: ${services_count}
Tailscale: ${tailscale_connected}
Tailscale Hostname: ${vps_hostname}
Tailscale Tailnet: ${tailnet:-nao detectado}
Bridge Mode: local-to-vps
Bridge File: ${BRIDGE_FILE}
Settings File: ${SETTINGS_FILE}
Service Dir: ${AGENT_SERVICE_DIR}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_bridge"

step_ok "Estado salvo em ~/dados_vps/dados_bridge"

# =============================================================================
# STEP 10: HINTS + RESUMO FINAL
# =============================================================================
hint_bridge_status "${nome_agente}"
hint_bridge_debug "${nome_agente}" "${GATEWAY_URL}"
hint_local_bridge_next_steps

resumo_final

echo -e "${UI_BOLD}  Setup Local Bridge — Configuracao Completa${UI_NC}"
echo ""
echo "  Agente:        ${nome_agente}"
echo "  Gateway:       ${GATEWAY_URL}"
echo "  Tailscale:     ${tailscale_connected}"
echo "  Services:      ${services_count}"
echo ""
echo "  Bridge:        ${BRIDGE_FILE}"
echo "  Service:       ${AGENT_SERVICE_DIR}/index.js"
echo "  Settings:      ${SETTINGS_FILE}"
echo "  Estado:        ~/dados_vps/dados_bridge"
echo "  Log:           ${LOG_FILE}"
echo ""

log_finish
