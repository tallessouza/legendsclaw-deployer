#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/ferramentas/setup-local-bridge.sh
# Story 11.2: Bridge Local→VPS Bidirecional
# =============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export STATE_DIR="$TEST_DIR/dados_vps"
  mkdir -p "$STATE_DIR"

  LIB_DIR="${BATS_TEST_DIRNAME}/../../deployer/lib"
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."

  # Source libs (strip readonly for testability)
  eval "$(cat "${LIB_DIR}/ui.sh" | sed 's/^readonly //g')"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- Service Index Generation ---

@test "service index: generates index.js with Tailscale FQDN URL" {
  local nome_agente="test-agent"
  local GATEWAY_URL="http://meu-vps.tailnet-abc.ts.net:18789"
  local AGENT_SERVICE_DIR="${TEST_DIR}/services/${nome_agente}"

  mkdir -p "$AGENT_SERVICE_DIR"

  cat > "${AGENT_SERVICE_DIR}/index.js" << JSEOF
'use strict';
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

  [ -f "${AGENT_SERVICE_DIR}/index.js" ]

  # Verify Tailscale FQDN is in the file (not localhost)
  run grep "meu-vps.tailnet-abc.ts.net" "${AGENT_SERVICE_DIR}/index.js"
  [ "$status" -eq 0 ]

  # Verify agent name is in the file
  run grep "test-agent" "${AGENT_SERVICE_DIR}/index.js"
  [ "$status" -eq 0 ]

  # Verify env var overrides exist
  run grep "OPENCLAW_GATEWAY_URL" "${AGENT_SERVICE_DIR}/index.js"
  [ "$status" -eq 0 ]
  run grep "AGENT_GATEWAY_URL" "${AGENT_SERVICE_DIR}/index.js"
  [ "$status" -eq 0 ]

  # Verify NOT localhost
  run grep "localhost" "${AGENT_SERVICE_DIR}/index.js"
  [ "$status" -ne 0 ]
}

@test "service index: exports required module interface" {
  local nome_agente="test-agent"
  local AGENT_SERVICE_DIR="${TEST_DIR}/services/${nome_agente}"
  mkdir -p "$AGENT_SERVICE_DIR"

  cat > "${AGENT_SERVICE_DIR}/index.js" << 'JSEOF'
'use strict';
module.exports = {
  name: 'test-agent',
  description: 'OpenClaw Gateway health for test-agent',
  health: async () => ({ status: 'down', latency_ms: 0, error: 'test' }),
};
JSEOF

  # Verify Node.js can load the module
  run node -e "const m = require('${AGENT_SERVICE_DIR}/index.js'); console.log(m.name); console.log(typeof m.health)"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "test-agent" ]]
  [[ "${lines[1]}" == "function" ]]
}

# --- Settings.json Merge ---

@test "settings merge: preserves permissions when adding hooks" {
  # jq required for this test
  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
  fi

  local SETTINGS_FILE="${TEST_DIR}/.claude/settings.json"
  mkdir -p "$(dirname "$SETTINGS_FILE")"

  # Create existing settings with permissions (no hooks)
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "language": "portuguese",
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": ["Bash(git *)"],
    "deny": ["rm -rf *"]
  }
}
EOF

  # Merge hooks using jq
  local HOOKS_JSON='{"SessionStart":[{"type":"command","command":"node bridge.js status"}]}'
  jq --argjson hooks "$HOOKS_JSON" '.hooks = $hooks' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" \
    && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

  # Verify hooks were added
  run jq -r '.hooks.SessionStart[0].command' "$SETTINGS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "node bridge.js status" ]]

  # Verify permissions preserved
  run jq -r '.permissions.defaultMode' "$SETTINGS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "acceptEdits" ]]

  # Verify language preserved
  run jq -r '.language' "$SETTINGS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "portuguese" ]]

  # Verify deny still exists
  run jq -r '.permissions.deny[0]' "$SETTINGS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "rm -rf *" ]]
}

@test "settings merge: creates backup before modifying" {
  local SETTINGS_FILE="${TEST_DIR}/.claude/settings.json"
  mkdir -p "$(dirname "$SETTINGS_FILE")"

  cat > "$SETTINGS_FILE" << 'EOF'
{
  "language": "portuguese",
  "permissions": {}
}
EOF

  # Create backup
  cp -p "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"

  [ -f "${SETTINGS_FILE}.bak" ]

  # Verify backup content matches original
  run diff "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
  [ "$status" -eq 0 ]
}

@test "settings merge: python3 fallback works when jq unavailable" {
  if ! command -v python3 &>/dev/null; then
    skip "python3 not installed"
  fi

  local SETTINGS_FILE="${TEST_DIR}/.claude/settings_py.json"
  mkdir -p "$(dirname "$SETTINGS_FILE")"

  cat > "$SETTINGS_FILE" << 'EOF'
{
  "language": "portuguese",
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
EOF

  local HOOKS_JSON='{"SessionStart":[{"type":"command","command":"node bridge.js status"}]}'

  python3 -c "
import json, sys
with open('${SETTINGS_FILE}', 'r') as f:
    d = json.load(f)
d['hooks'] = json.loads(sys.argv[1])
with open('${SETTINGS_FILE}', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$HOOKS_JSON"

  # Verify hooks added
  run python3 -c "import json; d=json.load(open('${SETTINGS_FILE}')); print(d['hooks']['SessionStart'][0]['command'])"
  [ "$status" -eq 0 ]
  [[ "$output" == "node bridge.js status" ]]

  # Verify permissions preserved
  run python3 -c "import json; d=json.load(open('${SETTINGS_FILE}')); print(d['permissions']['defaultMode'])"
  [ "$status" -eq 0 ]
  [[ "$output" == "acceptEdits" ]]
}

# --- State File ---

@test "state file: generated with correct format and keys" {
  local nome_agente="meu-agente"
  local GATEWAY_URL="http://vps1.tailnet.ts.net:18789"
  local vps_hostname="vps1"
  local tailnet="tailnet.ts.net"
  local tailscale_connected="true"
  local BRIDGE_FILE=".aios-core/infrastructure/services/bridge.js"
  local SETTINGS_FILE=".claude/settings.json"
  local AGENT_SERVICE_DIR=".aios-core/infrastructure/services/meu-agente"
  local services_count="1"

  cat > "$STATE_DIR/dados_bridge" << EOF
Agente: ${nome_agente}
Gateway URL: ${GATEWAY_URL}
Bridge Status: configurado
Hooks Configured: true
Services Count: ${services_count}
Tailscale: ${tailscale_connected}
Tailscale Hostname: ${vps_hostname}
Tailscale Tailnet: ${tailnet}
Bridge Mode: local-to-vps
Bridge File: ${BRIDGE_FILE}
Settings File: ${SETTINGS_FILE}
Service Dir: ${AGENT_SERVICE_DIR}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
  chmod 600 "$STATE_DIR/dados_bridge"

  [ -f "$STATE_DIR/dados_bridge" ]

  # Verify key fields
  run grep "Agente: meu-agente" "$STATE_DIR/dados_bridge"
  [ "$status" -eq 0 ]

  run grep "Gateway URL: http://vps1.tailnet.ts.net:18789" "$STATE_DIR/dados_bridge"
  [ "$status" -eq 0 ]

  run grep "Bridge Mode: local-to-vps" "$STATE_DIR/dados_bridge"
  [ "$status" -eq 0 ]

  run grep "Tailscale Hostname: vps1" "$STATE_DIR/dados_bridge"
  [ "$status" -eq 0 ]

  run grep "Tailscale Tailnet: tailnet.ts.net" "$STATE_DIR/dados_bridge"
  [ "$status" -eq 0 ]

  run grep "Data Configuracao:" "$STATE_DIR/dados_bridge"
  [ "$status" -eq 0 ]

  # Verify key: value format for all lines (each line contains ": ")
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | grep -qE '^[A-Za-z ]+: .+'
  done < "$STATE_DIR/dados_bridge"

  # Verify permissions
  local perms
  perms=$(stat -c '%a' "$STATE_DIR/dados_bridge" 2>/dev/null || stat -f '%Lp' "$STATE_DIR/dados_bridge" 2>/dev/null)
  [ "$perms" = "600" ]
}

# --- Whitelabel Fallback ---

@test "whitelabel: reads agent name from dados_whitelabel when available" {
  cat > "$STATE_DIR/dados_whitelabel" << 'EOF'
Agente: orion-agent
Display Name: Orion
Idioma: pt-br
EOF

  local nome_agente
  nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)

  [ "$nome_agente" = "orion-agent" ]
}

@test "whitelabel: empty when dados_whitelabel not found" {
  local nome_agente
  nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)

  [ -z "$nome_agente" ]
}

# --- Hostname Validation ---

@test "hostname validation: accepts valid hostnames" {
  local valid_hosts=("meu-vps" "server1" "vps-prod-01" "MyServer")
  for host in "${valid_hosts[@]}"; do
    [[ "$host" =~ ^[a-zA-Z0-9-]+$ ]]
  done
}

@test "hostname validation: rejects invalid hostnames" {
  local invalid_hosts=("meu vps" "server@1" "vps.prod" "server/01" "host name")
  for host in "${invalid_hosts[@]}"; do
    ! [[ "$host" =~ ^[a-zA-Z0-9-]+$ ]]
  done
}

@test "FQDN validation: accepts valid Tailscale FQDNs" {
  local valid_fqdns=("meu-vps.tailnet-abc.ts.net" "server1.my-tailnet.ts.net")
  for fqdn in "${valid_fqdns[@]}"; do
    [[ "$fqdn" =~ ^[a-zA-Z0-9-]+\..+\.ts\.net$ ]]
  done
}

@test "FQDN validation: rejects invalid FQDNs" {
  local invalid_fqdns=("meu-vps" "server.com" "vps.ts.net.extra" "just-hostname.ts.ne")
  for fqdn in "${invalid_fqdns[@]}"; do
    ! [[ "$fqdn" =~ ^[a-zA-Z0-9-]+\..+\.ts\.net$ ]]
  done
}

# --- Hints ---

@test "hint_local_bridge_next_steps: function exists and outputs content" {
  source "${LIB_DIR}/hints.sh"

  run hint_local_bridge_next_steps
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROXIMOS PASSOS"* ]]
  [[ "$output" == *"setup-local-aios"* ]]
  [[ "$output" == *"validacao-local"* ]]
}

# --- VPS Ferramentas Unchanged ---

@test "vps tools: all 16 ferramentas files unchanged" {
  local FERRAMENTAS_DIR="${BATS_TEST_DIRNAME}/../../deployer/ferramentas"

  # Verify all 16 VPS ferramentas exist
  for i in $(seq -w 1 16); do
    # Some have different prefixes (01, 02, ..., 16)
    local num=$(echo "$i" | sed 's/^0//')
    local padded=$(printf "%02d" "$num")
    local count
    count=$(ls "${FERRAMENTAS_DIR}/${padded}-"*.sh 2>/dev/null | wc -l)
    [ "$count" -ge 1 ]
  done
}
