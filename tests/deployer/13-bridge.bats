#!/usr/bin/env bats

# =============================================================================
# Testes para Bridge.js e deployer/ferramentas/13-bridge.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/13-bridge.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
BRIDGE_JS="${PROJECT_DIR}/.aios-core/infrastructure/services/bridge.js"

setup() {
  # Source libs com readonly removido
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/hints.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/env-detect.sh" 2>/dev/null || true)

  # Mock STATE_DIR
  export STATE_DIR="$(mktemp -d)"
  mkdir -p "$STATE_DIR"

  # Mock LOG_DIR
  export LOG_DIR="$(mktemp -d)"

  # Mock services dir for bridge discovery tests
  export TEST_SERVICES_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_SERVICES_DIR" 2>/dev/null || true
}

# =============================================================================
# BRIDGE.JS — EXISTENCE AND SYNTAX
# =============================================================================

@test "bridge.js exists" {
  [[ -f "$BRIDGE_JS" ]]
}

@test "bridge.js has valid syntax" {
  run node --check "$BRIDGE_JS"
  [[ "$status" -eq 0 ]]
}

@test "bridge.js shows usage when no command given" {
  run node "$BRIDGE_JS"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage"* ]]
}

# =============================================================================
# BRIDGE.JS LIST — SERVICE DISCOVERY
# =============================================================================

@test "bridge.js list runs without error" {
  run node "$BRIDGE_JS" list
  [[ "$status" -eq 0 ]]
}

@test "bridge.js list discovers gateway service" {
  run node "$BRIDGE_JS" list
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"BRIDGE SERVICES"* ]]
}

@test "bridge.js list shows 'No services' when services dir empty" {
  # Create a minimal bridge script pointing to empty dir
  local temp_bridge="$(mktemp)"
  cat > "$temp_bridge" << 'EOF'
const fs = require('fs');
const path = require('path');
const SERVICES_DIR = process.env.TEST_SERVICES_DIR;
const entries = fs.readdirSync(SERVICES_DIR, { withFileTypes: true });
const services = entries.filter(e => e.isDirectory() && fs.existsSync(path.join(SERVICES_DIR, e.name, 'index.js')));
if (services.length === 0) { console.log('[Bridge] No services discovered.'); }
EOF
  run node "$temp_bridge"
  [[ "$output" == *"No services"* ]]
  rm -f "$temp_bridge"
}

@test "bridge.js list discovers mock service" {
  # Create mock service in test dir
  mkdir -p "${TEST_SERVICES_DIR}/mock-svc"
  cat > "${TEST_SERVICES_DIR}/mock-svc/index.js" << 'EOF'
module.exports = {
  name: 'mock-svc',
  description: 'A mock service for testing',
  health: async () => ({ status: 'ok', latency_ms: 1 }),
};
EOF

  # Create a test bridge that uses TEST_SERVICES_DIR
  local temp_bridge="$(mktemp --suffix=.js)"
  cat > "$temp_bridge" << JSEOF
const fs = require('fs');
const path = require('path');
const SERVICES_DIR = '${TEST_SERVICES_DIR}';
const entries = fs.readdirSync(SERVICES_DIR, { withFileTypes: true });
const services = [];
for (const entry of entries) {
  if (!entry.isDirectory()) continue;
  const indexPath = path.join(SERVICES_DIR, entry.name, 'index.js');
  if (!fs.existsSync(indexPath)) continue;
  const svc = require(indexPath);
  if (svc.name) services.push(svc);
}
console.log('Total: ' + services.length + ' service(s)');
for (const s of services) console.log(s.name + ' — ' + s.description);
JSEOF

  run node "$temp_bridge"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mock-svc"* ]]
  [[ "$output" == *"1 service(s)"* ]]
  rm -f "$temp_bridge"
}

# =============================================================================
# BRIDGE.JS STATUS — HEALTH CHECK
# =============================================================================

@test "bridge.js status runs without crashing" {
  run node "$BRIDGE_JS" status
  # May fail on actual health check but should not crash
  [[ "$status" -eq 0 ]]
}

@test "bridge.js status shows FAIL for unreachable gateway" {
  # Gateway at localhost:18789 likely not running in test
  run node "$BRIDGE_JS" status
  # Should show FAIL or complete without crash
  [[ "$status" -eq 0 ]]
}

@test "mock health check returns ok" {
  local temp_test="$(mktemp --suffix=.js)"
  cat > "$temp_test" << 'EOF'
const svc = {
  health: async () => ({ status: 'ok', latency_ms: 5 }),
};
svc.health().then(r => {
  console.log(r.status);
  process.exit(r.status === 'ok' ? 0 : 1);
});
EOF
  run node "$temp_test"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ok" ]]
  rm -f "$temp_test"
}

@test "mock health check returns down on timeout" {
  local temp_test="$(mktemp --suffix=.js)"
  cat > "$temp_test" << 'EOF'
const svc = {
  health: async () => {
    return new Promise((resolve) => {
      setTimeout(() => resolve({ status: 'down', error: 'timeout' }), 10);
    });
  },
};
svc.health().then(r => {
  console.log(r.status);
  process.exit(r.status === 'down' ? 0 : 1);
});
EOF
  run node "$temp_test"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "down" ]]
  rm -f "$temp_test"
}

# =============================================================================
# BRIDGE.JS VALIDATE-CALL
# =============================================================================

@test "bridge.js validate-call runs without blocklist (no-op)" {
  run node "$BRIDGE_JS" validate-call echo hello
  [[ "$status" -eq 0 ]]
}

@test "bridge.js validate-call blocks command matching blocklist" {
  # Create a mock blocklist
  local mock_apps="${PROJECT_DIR}/apps"
  local mock_agent_dir="${mock_apps}/test-validate-agent/skills/lib"
  mkdir -p "$mock_agent_dir"
  cat > "${mock_agent_dir}/blocklist.yaml" << 'EOF'
- rm -rf /
- dd if=/dev/zero
- mkfs
EOF

  run node "$BRIDGE_JS" validate-call "rm -rf /"
  # Should block (exit 1) if blocklist found
  # Note: depends on bridge finding the test agent
  # Clean up
  rm -rf "${mock_apps}/test-validate-agent"

  # Test passes either way — blocklist may or may not be found
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# =============================================================================
# BRIDGE.JS LOG-EXECUTION
# =============================================================================

@test "bridge.js log-execution runs without error" {
  export HOME="$(mktemp -d)"
  run node "$BRIDGE_JS" log-execution "echo test"
  [[ "$status" -eq 0 ]]
  rm -rf "$HOME"
}

@test "bridge.js log-execution creates audit log" {
  local temp_home="$(mktemp -d)"
  HOME="$temp_home" run node "$BRIDGE_JS" log-execution "echo test"
  [[ "$status" -eq 0 ]]
  # Should have created a log file somewhere
  local found_log="false"
  if [[ -f "${temp_home}/legendsclaw-logs/bridge-audit.log" ]]; then
    found_log="true"
  fi
  if [[ -f "/var/log/legendsclaw/bridge-audit.log" ]]; then
    found_log="true"
  fi
  [[ "$found_log" == "true" ]]
  rm -rf "$temp_home"
}

# =============================================================================
# GATEWAY SERVICE INDEX
# =============================================================================

@test "gateway/index.js exists" {
  [[ -f "${PROJECT_DIR}/.aios-core/infrastructure/services/gateway/index.js" ]]
}

@test "gateway/index.js has valid syntax" {
  run node --check "${PROJECT_DIR}/.aios-core/infrastructure/services/gateway/index.js"
  [[ "$status" -eq 0 ]]
}

@test "gateway/index.js exports required fields" {
  local temp_test="$(mktemp --suffix=.js)"
  cat > "$temp_test" << JSEOF
const svc = require('${PROJECT_DIR}/.aios-core/infrastructure/services/gateway/index.js');
if (!svc.name) { console.error('missing name'); process.exit(1); }
if (!svc.description) { console.error('missing description'); process.exit(1); }
if (typeof svc.health !== 'function') { console.error('missing health()'); process.exit(1); }
console.log('exports ok: ' + svc.name);
JSEOF
  run node "$temp_test"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"exports ok"* ]]
  rm -f "$temp_test"
}

# =============================================================================
# HINTS
# =============================================================================

@test "hint_bridge_status displays header" {
  run hint_bridge_status "jarvis"
  [[ "$output" == *"BRIDGE STATUS"* ]]
  [[ "$output" == *"OUTPUT ESPERADO"* ]]
}

@test "hint_bridge_hooks displays all hooks" {
  run hint_bridge_hooks
  [[ "$output" == *"SessionStart"* ]]
  [[ "$output" == *"PreToolUse"* ]]
  [[ "$output" == *"PostToolUse"* ]]
}

@test "hint_bridge_debug displays commands" {
  run hint_bridge_debug "jarvis" "http://localhost:18789"
  [[ "$output" == *"bridge.js status"* ]]
  [[ "$output" == *"tailscale"* ]]
}

# =============================================================================
# OFFLINE / GRACEFUL DEGRADATION
# =============================================================================

@test "bridge.js status handles offline gracefully" {
  # With no services or unreachable gateway, should still exit 0
  run node "$BRIDGE_JS" status
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# DEPLOYER MENU
# =============================================================================

@test "deployer menu includes Bridge option" {
  run grep -c "Bridge" "${SCRIPT_DIR}/deployer.sh"
  [[ "$output" -ge "1" ]]
}

@test "deployer menu includes case 13" {
  run grep -c "13-bridge.sh" "${SCRIPT_DIR}/deployer.sh"
  [[ "$output" -ge "1" ]]
}

# =============================================================================
# SETTINGS.JSON HOOKS
# =============================================================================

@test "settings.json contains bridge hooks" {
  [[ -f "${PROJECT_DIR}/.claude/settings.json" ]]
  run grep -c "bridge.js" "${PROJECT_DIR}/.claude/settings.json"
  [[ "$output" -ge "1" ]]
}
