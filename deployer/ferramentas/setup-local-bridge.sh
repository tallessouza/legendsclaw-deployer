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

# Adicionar paths comuns do Tailscale (Homebrew macOS, Linux)
for _tp in /opt/homebrew/bin /usr/local/bin /usr/bin /usr/sbin; do
  if [[ -x "$_tp/tailscale" ]] && ! command -v tailscale &>/dev/null; then
    export PATH="$_tp:$PATH"
  fi
done

if command -v tailscale &>/dev/null; then
  tailscale_installed="true"
  if tailscale status &>/dev/null 2>&1; then
    tailscale_connected="true"
  fi
fi

if [[ "$tailscale_installed" == "false" ]]; then
  echo ""
  echo -e "  ${UI_YELLOW}Tailscale nao encontrado.${UI_NC}"
  echo ""
  echo "  [1] Instalar agora"
  echo "  [2] Continuar sem Tailscale (bridge offline)"
  echo ""
  ts_install_opcao=""
  input "bridge.ts_install" "Opcao [1]: " ts_install_opcao --default=1

  if [[ "$ts_install_opcao" == "1" ]]; then
    echo ""
    so_detect=""
    so_detect=$(detectar_so 2>/dev/null || echo "linux")
    case "$so_detect" in
      linux|wsl)
        echo "  Instalando Tailscale..."
        # Forcar reinstall se binario ausente (ex: removido manualmente)
        if ! command -v tailscale &>/dev/null && [[ ! -x /usr/bin/tailscale ]]; then
          sudo apt-get install --reinstall tailscale -y 2>/dev/null || true
        fi
        if ! command -v tailscale &>/dev/null && [[ ! -x /usr/bin/tailscale ]]; then
          curl -fsSL https://tailscale.com/install.sh | sh 2>/dev/null || true
        fi
        hash -r 2>/dev/null || true
        export PATH="/usr/bin:/usr/sbin:/usr/local/bin:$PATH"
        if command -v tailscale &>/dev/null || [[ -x /usr/bin/tailscale ]]; then
          tailscale_installed="true"
          step_ok "Tailscale instalado"
        else
          echo -e "  ${UI_RED}Falha ao instalar Tailscale.${UI_NC}"
          echo "  Instale manualmente: https://tailscale.com/download"
          step_ok "Continuando sem Tailscale (bridge offline)"
        fi
        ;;
      macos)
        if command -v brew &>/dev/null; then
          echo "  Instalando Tailscale via Homebrew..."
          if brew install tailscale 2>/dev/null; then
            tailscale_installed="true"
            step_ok "Tailscale instalado via Homebrew"
          else
            echo -e "  ${UI_RED}Falha ao instalar Tailscale.${UI_NC}"
            echo "  Baixe em: https://tailscale.com/download/mac"
            step_ok "Continuando sem Tailscale (bridge offline)"
          fi
        else
          echo -e "  ${UI_YELLOW}Homebrew nao encontrado.${UI_NC}"
          echo "  Baixe em: https://tailscale.com/download/mac"
          step_ok "Continuando sem Tailscale (bridge offline)"
        fi
        ;;
    esac
  else
    step_ok "Continuando sem Tailscale (bridge offline)"
  fi
fi

if [[ "$tailscale_connected" == "true" ]]; then
  step_ok "Dependencias verificadas — Node $(node --version), Tailscale conectado"
else
  echo ""
  echo -e "  ${UI_YELLOW}Tailscale instalado mas NAO conectado.${UI_NC}"
  echo ""
  echo "  [1] Conectar agora (sudo tailscale up)"
  echo "  [2] Continuar offline (configurar bridge sem testar)"
  echo ""
  ts_opcao=""
  input "bridge.ts_connect" "Opcao [1]: " ts_opcao --default=1

  if [[ "$ts_opcao" == "1" ]]; then
    echo ""
    echo "  Executando: sudo tailscale up"
    echo "  (siga as instrucoes de login no navegador)"
    echo ""
    # Resolver path do tailscale (pode nao estar no PATH do sudo)
    ts_bin=$(command -v tailscale 2>/dev/null || true)
    if [[ -z "$ts_bin" ]]; then
      for _p in /opt/homebrew/bin/tailscale /usr/local/bin/tailscale /usr/bin/tailscale; do
        if [[ -x "$_p" ]]; then ts_bin="$_p"; break; fi
      done
    fi
    ts_bin="${ts_bin:-tailscale}"
    if sudo "$ts_bin" up 2>&1; then
      # Re-verificar conexao
      sleep 2
      if "$ts_bin" status &>/dev/null; then
        tailscale_connected="true"
        step_ok "Tailscale conectado com sucesso"
      else
        echo -e "  ${UI_YELLOW}Tailscale login executado mas status nao confirmado.${UI_NC}"
        echo "  Continuando em modo offline."
        step_ok "Dependencias verificadas — Node $(node --version), Tailscale offline"
      fi
    else
      echo -e "  ${UI_YELLOW}Falha ao conectar Tailscale. Continuando offline.${UI_NC}"
      step_ok "Dependencias verificadas — Node $(node --version), Tailscale offline"
    fi
  else
    echo -e "  Continuando em modo offline."
    step_ok "Dependencias verificadas — Node $(node --version), Tailscale offline"
  fi
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

# Hostname Tailscale da VPS — auto-detectar peers se Tailscale conectado
vps_hostname=""
tailnet=""

if [[ "$tailscale_connected" == "true" ]]; then
  # Detectar tailnet suffix
  if [[ "$jq_available" == "true" ]]; then
    tailnet=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix' 2>/dev/null || true)
  else
    tailnet=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('MagicDNSSuffix',''))" 2>/dev/null || true)
  fi

  # Listar peers disponiveis
  declare -a peer_names=()
  declare -a peer_ips=()
  declare -a peer_os=()

  if [[ "$jq_available" == "true" ]]; then
    while IFS=$'\t' read -r _name _ip _os; do
      [[ -z "$_name" ]] && continue
      peer_names+=("$_name")
      peer_ips+=("$_ip")
      peer_os+=("$_os")
    done < <(tailscale status --json 2>/dev/null | jq -r '.Peer | to_entries[] | select(.value.Online == true) | [(.value.HostName // .value.DNSName | split(".")[0]), (.value.TailscaleIPs[0] // ""), (.value.OS // "")] | @tsv' 2>/dev/null || true)
  else
    while IFS=$'\t' read -r _name _ip _os; do
      [[ -z "$_name" ]] && continue
      peer_names+=("$_name")
      peer_ips+=("$_ip")
      peer_os+=("$_os")
    done < <(tailscale status --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for k, v in (data.get('Peer') or {}).items():
    if v.get('Online'):
        name = v.get('HostName') or v.get('DNSName','').split('.')[0]
        ip = (v.get('TailscaleIPs') or [''])[0]
        os_name = v.get('OS','')
        print(f'{name}\t{ip}\t{os_name}')
" 2>/dev/null || true)
  fi

  if [[ ${#peer_names[@]} -gt 0 ]]; then
    echo ""
    echo -e "  ${UI_BOLD:-\033[1m}Peers Tailscale online:${UI_NC:-\033[0m}"
    echo ""
    for i in "${!peer_names[@]}"; do
      printf "    [%d] %-25s %-18s %s\n" "$((i+1))" "${peer_names[$i]}" "${peer_ips[$i]}" "${peer_os[$i]}"
    done
    echo "    [0] Digitar manualmente"
    echo ""

    peer_choice=""
    input "bridge.peer_choice" "Selecione a VPS [1]: " peer_choice --default=1

    if [[ "$peer_choice" =~ ^[0-9]+$ ]] && [[ "$peer_choice" -ge 1 ]] && [[ "$peer_choice" -le ${#peer_names[@]} ]]; then
      vps_hostname="${peer_names[$((peer_choice-1))]}"
      echo -e "  Selecionado: ${UI_GREEN:-\033[0;32m}${vps_hostname}${UI_NC:-\033[0m}"
    fi
    # peer_choice == 0 ou invalido → cai no input manual abaixo
  fi
fi

# Fallback: input manual se nao auto-detectou
if [[ -z "$vps_hostname" ]]; then
  input "bridge.vps_hostname" "Hostname Tailscale da VPS (sem .ts.net): " vps_hostname --required
  while [[ ! "$vps_hostname" =~ ^[a-zA-Z0-9-]+$ ]]; do
    echo -e "  ${UI_RED}Hostname invalido: apenas letras, numeros e hifens permitidos${UI_NC}"
    input "bridge.vps_hostname" "Hostname Tailscale da VPS (sem .ts.net): " vps_hostname --required
  done
fi

# Montar GATEWAY_URL
# O gateway na VPS faz bind em loopback (127.0.0.1) por seguranca.
# Acesso remoto DEVE ser via Tailscale Serve (HTTPS proxy → localhost).
# Porta direta via IP Tailscale NAO funciona com bind loopback.
porta_gateway=""
if [[ -n "$tailnet" ]]; then
  # Tailscale conectado — usar HTTPS via Tailscale Serve (unica via com loopback bind)
  GATEWAY_URL="https://${vps_hostname}.${tailnet}"
  porta_gateway="443"

  # Teste de conectividade (informativo, nao bloqueia configuracao)
  echo "  Testando Tailscale Serve (${GATEWAY_URL})..."
  if curl -skf --max-time 10 "${GATEWAY_URL}/health" &>/dev/null 2>&1; then
    echo -e "  ${UI_GREEN:-\033[0;32m}Tailscale Serve respondeu — conexao OK!${UI_NC:-\033[0m}"
  else
    echo -e "  ${UI_YELLOW:-\033[0;33m}Tailscale Serve nao respondeu agora — URL sera configurada mesmo assim.${UI_NC:-\033[0m}"
    echo -e "  ${UI_YELLOW:-\033[0;33m}Dica: Verifique na VPS se Tailscale Serve esta ativo (sudo tailscale serve status).${UI_NC:-\033[0m}"
    echo -e "  ${UI_YELLOW:-\033[0;33m}      O gateway faz bind em loopback — porta direta via IP nao funciona.${UI_NC:-\033[0m}"
  fi
else
  echo ""
  echo -e "  ${UI_YELLOW}Nao foi possivel detectar o tailnet automaticamente.${UI_NC}"
  input "bridge.tailnet_fqdn" "FQDN completo da VPS (ex: meu-vps.tailnet-name.ts.net): " fqdn_completo --required
  while [[ ! "$fqdn_completo" =~ ^[a-zA-Z0-9-]+\..+\.ts\.net$ ]]; do
    echo -e "  ${UI_RED}Formato invalido. Esperado: hostname.tailnet-name.ts.net${UI_NC}"
    input "bridge.tailnet_fqdn" "FQDN completo da VPS: " fqdn_completo --required
  done
  # Com FQDN manual, usar HTTPS (Tailscale Serve) por padrao
  GATEWAY_URL="https://${fqdn_completo}"
  porta_gateway="443"
  tailnet=$(echo "$fqdn_completo" | sed "s/^${vps_hostname}\.//" || echo "$fqdn_completo")

  echo -e "  ${UI_YELLOW:-\033[0;33m}Dica: Certifique-se que Tailscale Serve esta configurado na VPS.${UI_NC:-\033[0m}"
  echo -e "  ${UI_YELLOW:-\033[0;33m}      O gateway faz bind em loopback — porta direta via IP nao funciona.${UI_NC:-\033[0m}"
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
  health_response=$(curl -sk --max-time 10 "${GATEWAY_URL}/health" 2>/dev/null || true)
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

# Limpar servicos antigos (manter apenas o agente atual)
if [[ -d "$SERVICES_DIR" ]]; then
  for old_svc in "$SERVICES_DIR"/*/; do
    [[ -d "$old_svc" ]] || continue
    local_name=$(basename "$old_svc")
    if [[ "$local_name" != "$nome_agente" ]]; then
      rm -rf "$old_svc"
      echo "  Servico antigo removido: ${local_name}"
    fi
  done
fi

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
      const req = mod.get(url, { timeout: 5000, rejectUnauthorized: false }, (res) => {
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

# Session check script — Story 12.3: 4 verificacoes no SessionStart hook
SESSION_CHECK="${SERVICES_DIR}/session-check.sh"

cat > "$SESSION_CHECK" << CHECKEOF
#!/usr/bin/env bash
# Session check — Tailscale, Gateway, OpenClaw config, Bridge services
# Generated by setup-local-bridge.sh (Story 12.3)

# 1. Tailscale
TS="offline"
if command -v tailscale &>/dev/null; then
  backend=\$(tailscale status --json 2>/dev/null | node -pe 'JSON.parse(require("fs").readFileSync("/dev/stdin","utf8")).BackendState' 2>/dev/null || true)
  [[ "\$backend" == "Running" ]] && TS="OK"
fi

# 2. Gateway health (HTTP, timeout 5s)
GW="offline"
if curl -sk --max-time 5 "${GATEWAY_URL}/health" &>/dev/null; then
  GW="OK"
fi

# 3. OpenClaw config
OC="not configured"
oc_file="\$HOME/.openclaw/openclaw.json"
if [[ -f "\$oc_file" ]]; then
  mode=\$(node -pe "JSON.parse(require('fs').readFileSync('\$oc_file','utf8')).gateway?.mode" 2>/dev/null || true)
  [[ -n "\$mode" && "\$mode" != "undefined" ]] && OC="\$mode"
fi

# 4. Bridge services
svc_count=\$(node .aios-core/infrastructure/services/bridge.js list 2>/dev/null | grep -c "  [a-z]" || echo "0")

echo "[Bridge] Tailscale: \$TS | Gateway: \$GW | OpenClaw: \$OC | Services: \$svc_count"
CHECKEOF

chmod +x "$SESSION_CHECK"
step_ok "Session check criado: ${SESSION_CHECK}"

# =============================================================================
# STEP 7: CONFIGURAR CLAUDE CODE HOOKS — MERGE
# =============================================================================
SETTINGS_FILE=".claude/settings.json"

# Hooks JSON a configurar
HOOKS_JSON='{
  "SessionStart": [
    {
      "type": "command",
      "command": "bash .aios-core/infrastructure/services/session-check.sh 2>/dev/null || echo '\''[Bridge] Session check unavailable'\''"
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
        "command": "bash .aios-core/infrastructure/services/session-check.sh 2>/dev/null || echo '[Bridge] Session check unavailable'"
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

log_finish
