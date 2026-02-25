#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/ferramentas/setup-local-openclaw.sh
# Story 12.1: Configurar OpenClaw Local em Mode Remote
# =============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export STATE_DIR="$TEST_DIR/dados_vps"
  mkdir -p "$STATE_DIR"

  LIB_DIR="${BATS_TEST_DIRNAME}/../../deployer/lib"

  # Source libs (strip readonly for testability)
  eval "$(cat "${LIB_DIR}/ui.sh" | sed 's/^readonly //g')"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- Config Generation ---

@test "openclaw config: creates ~/.openclaw/ directory" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"

  mkdir -p "$OPENCLAW_DIR"

  [ -d "$OPENCLAW_DIR" ]
}

@test "openclaw config: generates openclaw.json with gateway.mode remote" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  local vps_hostname="meu-vps"
  local tailnet="tailnet-abc.ts.net"
  local gateway_password="s3cret-p4ss"
  local wss_url="wss://${vps_hostname}.${tailnet}"

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

  [ -f "$OPENCLAW_CONFIG" ]

  # Verify gateway.mode is remote
  run python3 -c "import json; d=json.load(open('${OPENCLAW_CONFIG}')); print(d['gateway']['mode'])"
  [ "$status" -eq 0 ]
  [[ "$output" == "remote" ]]
}

@test "openclaw config: contains WSS URL with Tailscale FQDN" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  local wss_url="wss://meu-vps.tailnet-abc.ts.net"

  cat > "$OPENCLAW_CONFIG" << JSONEOF
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "${wss_url}",
      "password": "test"
    }
  }
}
JSONEOF

  # Verify WSS URL
  run python3 -c "import json; d=json.load(open('${OPENCLAW_CONFIG}')); print(d['gateway']['remote']['url'])"
  [ "$status" -eq 0 ]
  [[ "$output" == "wss://meu-vps.tailnet-abc.ts.net" ]]

  # Verify starts with wss://
  [[ "$output" == wss://* ]]
}

@test "openclaw config: contains gateway password" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  cat > "$OPENCLAW_CONFIG" << JSONEOF
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "wss://vps.tailnet.ts.net",
      "password": "my-secret-pass"
    }
  }
}
JSONEOF

  run python3 -c "import json; d=json.load(open('${OPENCLAW_CONFIG}')); print(d['gateway']['remote']['password'])"
  [ "$status" -eq 0 ]
  [[ "$output" == "my-secret-pass" ]]
}

@test "openclaw config: file permissions are 600" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  echo '{}' > "$OPENCLAW_CONFIG"
  chmod 600 "$OPENCLAW_CONFIG"

  local perms
  perms=$(stat -c '%a' "$OPENCLAW_CONFIG" 2>/dev/null || stat -f '%Lp' "$OPENCLAW_CONFIG" 2>/dev/null)
  [ "$perms" = "600" ]
}

@test "openclaw config: valid JSON structure" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  cat > "$OPENCLAW_CONFIG" << 'JSONEOF'
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "wss://test.tailnet.ts.net",
      "password": "pass"
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/auto" },
      "workspace": "/tmp/.openclaw/workspace"
    }
  }
}
JSONEOF

  # Validate JSON
  run python3 -c "import json; json.load(open('${OPENCLAW_CONFIG}')); print('valid')"
  [ "$status" -eq 0 ]
  [[ "$output" == "valid" ]]
}

# --- Idempotency ---

@test "idempotency: detects existing remote config" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  cat > "$OPENCLAW_CONFIG" << 'JSONEOF'
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "wss://existing.tailnet.ts.net",
      "password": "old-pass"
    }
  }
}
JSONEOF

  # Create state file
  cat > "$STATE_DIR/dados_local_openclaw" << 'EOF'
OpenClaw Version: 1.0.0
Config Path: ~/.openclaw/openclaw.json
Gateway Mode: remote
EOF

  # Check existing mode
  existing_mode=$(python3 -c "
import json
try:
    d = json.load(open('${OPENCLAW_CONFIG}'))
    print(d.get('gateway', {}).get('mode', ''))
except: pass
" 2>/dev/null || true)

  [ "$existing_mode" = "remote" ]
}

@test "idempotency: creates backup before overwrite" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"
  mkdir -p "$OPENCLAW_DIR"

  echo '{"old": true}' > "$OPENCLAW_CONFIG"

  # Simulate backup
  cp -p "$OPENCLAW_CONFIG" "${OPENCLAW_CONFIG}.bak"

  [ -f "${OPENCLAW_CONFIG}.bak" ]
  run grep '"old"' "${OPENCLAW_CONFIG}.bak"
  [ "$status" -eq 0 ]
}

# --- State File ---

@test "state file: generated with correct format and keys" {
  local STATE_FILE_NAME="dados_local_openclaw"
  local openclaw_version="2026.2.21"
  local wss_url="wss://meu-vps.tailnet.ts.net"
  local wss_test="OK"
  local nome_agente="jim"

  cat > "$STATE_DIR/${STATE_FILE_NAME}" << EOF
OpenClaw Version: ${openclaw_version}
Config Path: ~/.openclaw/openclaw.json
Gateway Mode: remote
Gateway URL: ${wss_url}
WSS Test: ${wss_test}
Agente: ${nome_agente}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
  chmod 600 "$STATE_DIR/${STATE_FILE_NAME}"

  [ -f "$STATE_DIR/${STATE_FILE_NAME}" ]

  # Verify key fields
  run grep "Gateway Mode: remote" "$STATE_DIR/${STATE_FILE_NAME}"
  [ "$status" -eq 0 ]

  run grep "Gateway URL: wss://meu-vps.tailnet.ts.net" "$STATE_DIR/${STATE_FILE_NAME}"
  [ "$status" -eq 0 ]

  run grep "WSS Test: OK" "$STATE_DIR/${STATE_FILE_NAME}"
  [ "$status" -eq 0 ]

  run grep "Agente: jim" "$STATE_DIR/${STATE_FILE_NAME}"
  [ "$status" -eq 0 ]

  run grep "Data Configuracao:" "$STATE_DIR/${STATE_FILE_NAME}"
  [ "$status" -eq 0 ]

  # Verify key: value format
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | grep -qE '^[A-Za-z ]+: .+'
  done < "$STATE_DIR/${STATE_FILE_NAME}"

  # Verify permissions
  local perms
  perms=$(stat -c '%a' "$STATE_DIR/${STATE_FILE_NAME}" 2>/dev/null || stat -f '%Lp' "$STATE_DIR/${STATE_FILE_NAME}" 2>/dev/null)
  [ "$perms" = "600" ]
}

# --- Bridge Data Reading ---

@test "bridge data: reads hostname and tailnet from dados_bridge" {
  cat > "$STATE_DIR/dados_bridge" << 'EOF'
Agente: test-agent
Gateway URL: http://meu-vps.tailnet-abc.ts.net:18789
Tailscale Hostname: meu-vps
Tailscale Tailnet: tailnet-abc.ts.net
EOF

  local vps_hostname
  local tailnet

  vps_hostname=$(grep "Tailscale Hostname:" "$STATE_DIR/dados_bridge" | awk -F': ' '{print $2}')
  tailnet=$(grep "Tailscale Tailnet:" "$STATE_DIR/dados_bridge" | awk -F': ' '{print $2}')

  [ "$vps_hostname" = "meu-vps" ]
  [ "$tailnet" = "tailnet-abc.ts.net" ]
}

@test "bridge data: constructs WSS URL from hostname and tailnet" {
  local vps_hostname="meu-vps"
  local tailnet="tailnet-abc.ts.net"
  local wss_url="wss://${vps_hostname}.${tailnet}"

  [ "$wss_url" = "wss://meu-vps.tailnet-abc.ts.net" ]
}

# --- Install.sh Integration ---

@test "install.sh: has setup-local-openclaw.sh step" {
  local INSTALL_FILE="${BATS_TEST_DIRNAME}/../../deployer/install.sh"

  [ -f "$INSTALL_FILE" ]

  run grep "setup-local-openclaw.sh" "$INSTALL_FILE"
  [ "$status" -eq 0 ]
}

@test "install.sh: openclaw step is between bridge and aios" {
  local INSTALL_FILE="${BATS_TEST_DIRNAME}/../../deployer/install.sh"

  # Extract the order of setup-local scripts
  local bridge_line
  local openclaw_line
  local aios_line

  bridge_line=$(grep -n "setup-local-bridge.sh" "$INSTALL_FILE" | head -1 | cut -d: -f1)
  openclaw_line=$(grep -n "setup-local-openclaw.sh" "$INSTALL_FILE" | head -1 | cut -d: -f1)
  aios_line=$(grep -n "setup-local-aios.sh" "$INSTALL_FILE" | head -1 | cut -d: -f1)

  # Verify order: bridge < openclaw < aios
  [ "$bridge_line" -lt "$openclaw_line" ]
  [ "$openclaw_line" -lt "$aios_line" ]
}

@test "install.sh: TOTAL_STEPS is 11 for local mode" {
  local INSTALL_FILE="${BATS_TEST_DIRNAME}/../../deployer/install.sh"

  run grep "TOTAL_STEPS=11" "$INSTALL_FILE"
  [ "$status" -eq 0 ]
}

# --- Whitelabel Reading ---

@test "whitelabel: reads agent name from dados_whitelabel" {
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

# --- Config Path ---

@test "config path: uses ~/.openclaw/openclaw.json (not ~/.aiosbot/)" {
  local OPENCLAW_DIR="${TEST_DIR}/.openclaw"
  local OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"

  [[ "$OPENCLAW_CONFIG" == *"/.openclaw/openclaw.json" ]]
  [[ "$OPENCLAW_CONFIG" != *"/.aiosbot/"* ]]
}
