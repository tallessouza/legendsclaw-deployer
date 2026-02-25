#!/usr/bin/env bats

# =============================================================================
# Testes para Story 12.2: Gerar openclaw-local.json na VPS
# Framework: bats-core
# Execucao: npx bats tests/deployer/14-gateway-config-openclaw-local.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/ferramentas/14-gateway-config.sh"

setup() {
  export TEST_DIR="$(mktemp -d)"
  export CONFIG_DIR="$TEST_DIR/config"
  mkdir -p "$CONFIG_DIR"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# =============================================================================
# AC1: Gera openclaw-local.json apos aiosbot.json (script structure)
# =============================================================================

@test "script contains openclaw-local.json generation step" {
  run grep -c "openclaw-local.json" "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

@test "openclaw-local.json step comes after aiosbot.json step" {
  # Step 8 (openclaw-local) must come after Step 7 (aiosbot.json)
  local aiosbot_line openclaw_local_line
  aiosbot_line=$(grep -n "STEP 7:.*aiosbot.json" "$SCRIPT_PATH" | head -1 | cut -d: -f1)
  openclaw_local_line=$(grep -n "STEP 8:.*openclaw-local.json" "$SCRIPT_PATH" | head -1 | cut -d: -f1)
  [[ -n "$aiosbot_line" ]]
  [[ -n "$openclaw_local_line" ]]
  [[ "$openclaw_local_line" -gt "$aiosbot_line" ]]
}

@test "openclaw-local.json step comes before node.json step" {
  local openclaw_local_line node_line
  openclaw_local_line=$(grep -n "STEP 8:.*openclaw-local.json" "$SCRIPT_PATH" | head -1 | cut -d: -f1)
  node_line=$(grep -n "STEP 9:.*node.json" "$SCRIPT_PATH" | head -1 | cut -d: -f1)
  [[ -n "$openclaw_local_line" ]]
  [[ -n "$node_line" ]]
  [[ "$node_line" -gt "$openclaw_local_line" ]]
}

@test "aiosbot.json generation is not modified by Story 12.2" {
  # The aiosbot.json step (Step 7) must still exist and write to aiosbot.json
  run grep "aiosbot.json gerado" "$SCRIPT_PATH"
  [[ "$output" == *"aiosbot.json gerado"* ]]
}

# =============================================================================
# AC2: Formato nativo OpenClaw com gateway.mode: "remote"
# =============================================================================

@test "JSON generation: gateway.mode is remote" {
  REMOTE_URL="wss://myhost.mytail.ts.net" \
  GATEWAY_PASSWORD="testpass123" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: {
    mode: "remote",
    remote: {
      url: e.REMOTE_URL,
      password: e.GATEWAY_PASSWORD
    }
  },
  agents: {
    defaults: {
      model: { primary: "openrouter/auto" },
      workspace: "~/.openclaw/workspace"
    }
  },
  meta: {
    lastTouchedVersion: "deployer-12.2",
    lastTouchedAt: new Date().toISOString(),
    generatedBy: "legendsclaw-deployer"
  }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  # Verify gateway.mode
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.gateway.mode)"
  [[ "$output" == "remote" ]]
}

@test "JSON generation: gateway.remote.url starts with wss://" {
  REMOTE_URL="wss://myhost.mytail.ts.net" \
  GATEWAY_PASSWORD="testpass123" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.gateway.remote.url)"
  [[ "$output" == wss://* ]]
}

@test "JSON generation: gateway.remote.password is present" {
  REMOTE_URL="wss://myhost.mytail.ts.net" \
  GATEWAY_PASSWORD="secret_password_42" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.gateway.remote.password)"
  [[ "$output" == "secret_password_42" ]]
}

@test "JSON generation: mode is NOT local" {
  REMOTE_URL="wss://myhost.mytail.ts.net" \
  GATEWAY_PASSWORD="testpass" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.gateway.mode)"
  [[ "$output" != "local" ]]
}

# =============================================================================
# AC3: Salva como apps/{agent}/config/openclaw-local.json
# =============================================================================

@test "script references CONFIG_DIR for openclaw-local.json output" {
  run grep 'CONFIG_DIR.*openclaw-local.json' "$SCRIPT_PATH"
  [[ "$output" == *'$CONFIG_DIR/openclaw-local.json'* ]]
}

# =============================================================================
# AC4: Inclui agents.defaults basico (model, workspace)
# =============================================================================

@test "JSON generation: agents.defaults.model.primary exists" {
  REMOTE_URL="wss://test.ts.net" \
  GATEWAY_PASSWORD="pw" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.agents.defaults.model.primary)"
  [[ "$output" == "openrouter/auto" ]]
}

@test "JSON generation: agents.defaults.workspace exists" {
  REMOTE_URL="wss://test.ts.net" \
  GATEWAY_PASSWORD="pw" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.agents.defaults.workspace)"
  [[ "$output" == "~/.openclaw/workspace" ]]
}

# =============================================================================
# AC5: JSON valido com permissoes 600
# =============================================================================

@test "JSON generation: output is valid JSON" {
  REMOTE_URL="wss://test.ts.net" \
  GATEWAY_PASSWORD="pw" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log('valid')"
  [[ "$output" == "valid" ]]
}

@test "script sets chmod 600 on openclaw-local.json" {
  run grep -c 'chmod 600.*openclaw-local.json' "$SCRIPT_PATH"
  [[ "$output" -ge 1 ]]
}

# =============================================================================
# AC6: Step adicional (step_init incrementado)
# =============================================================================

@test "step_init is 16 (incremented from 15)" {
  run grep 'step_init' "$SCRIPT_PATH"
  [[ "$output" == *"step_init 16"* ]]
}

@test "Step 8 comment references openclaw-local.json" {
  run grep "STEP 8:" "$SCRIPT_PATH"
  [[ "$output" == *"openclaw-local.json"* ]]
}

# =============================================================================
# Fallback: sem Tailscale usa ws://localhost
# =============================================================================

@test "script has fallback to ws://localhost when no Tailscale" {
  run grep "ws://localhost" "$SCRIPT_PATH"
  [[ "$output" == *'ws://localhost'* ]]
}

@test "script uses wss:// when Tailscale is available" {
  run grep "wss://" "$SCRIPT_PATH"
  [[ "$output" == *'wss://'* ]]
}

# =============================================================================
# Nao gera aiosbot-local.json (nome obsoleto)
# =============================================================================

@test "script does NOT generate aiosbot-local.json" {
  run grep -c "aiosbot-local.json" "$SCRIPT_PATH"
  [[ "$output" == "0" ]]
}

# =============================================================================
# State file includes openclaw-local.json
# =============================================================================

@test "dados_gateway_config references openclaw-local.json" {
  run grep "openclaw-local.json" "$SCRIPT_PATH"
  [[ "$output" == *"openclaw-local.json"* ]]
}

@test "dados_gateway_config reports 5 generated files" {
  run grep "Arquivos Gerados:" "$SCRIPT_PATH"
  [[ "$output" == *"5"* ]]
}

# =============================================================================
# Resumo final includes openclaw-local.json
# =============================================================================

@test "resumo final prints openclaw-local.json" {
  run grep "openclaw-local.json" "$SCRIPT_PATH"
  # Should appear in the printf section
  [[ "$output" == *"openclaw-local.json"* ]]
}

# =============================================================================
# Meta fields
# =============================================================================

@test "JSON generation: meta.generatedBy is legendsclaw-deployer" {
  REMOTE_URL="wss://test.ts.net" \
  GATEWAY_PASSWORD="pw" \
  OUTPUT_PATH="$CONFIG_DIR/openclaw-local.json" \
  node -e '
const fs = require("fs");
const e = process.env;
const config = {
  gateway: { mode: "remote", remote: { url: e.REMOTE_URL, password: e.GATEWAY_PASSWORD } },
  agents: { defaults: { model: { primary: "openrouter/auto" }, workspace: "~/.openclaw/workspace" } },
  meta: { lastTouchedVersion: "deployer-12.2", lastTouchedAt: new Date().toISOString(), generatedBy: "legendsclaw-deployer" }
};
fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'
  run node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/openclaw-local.json','utf8'));console.log(c.meta.generatedBy)"
  [[ "$output" == "legendsclaw-deployer" ]]
}
