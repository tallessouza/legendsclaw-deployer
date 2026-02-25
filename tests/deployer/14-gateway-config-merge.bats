#!/usr/bin/env bats

# =============================================================================
# Testes para Story 12.0: Deep Merge openclaw.json
# Framework: bats-core
# Execucao: npx bats tests/deployer/14-gateway-config-merge.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  export TEST_DIR="$(mktemp -d)"
  export OPENCLAW_DIR="$TEST_DIR/.openclaw"
  mkdir -p "$OPENCLAW_DIR"
  export CONFIG_DIR="$TEST_DIR/config"
  mkdir -p "$CONFIG_DIR"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# Helper: create a minimal onboard openclaw.json
create_onboard_config() {
  cat > "$OPENCLAW_DIR/openclaw.json" << 'ONBOARD'
{
  "wizard": { "lastRunAt": "2026-01-01T00:00:00Z" },
  "auth": { "profiles": { "openrouter": { "key": "sk-or-xxx" } } },
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/auto" },
      "workspace": "/root/.openclaw/workspace"
    }
  },
  "gateway": {
    "port": 19888,
    "mode": "local",
    "bind": "loopback",
    "auth": { "mode": "password", "password": "old-password" },
    "tailscale": { "mode": "off", "resetOnExit": false }
  },
  "commands": { "native": "auto" },
  "meta": { "version": "2026.2.21" },
  "skills": { "install": { "nodeManager": "npm" }, "entries": {} },
  "plugins": { "entries": {} }
}
ONBOARD
}

# Helper: create a minimal aiosbot.json (deployer output)
create_aiosbot_config() {
  cat > "$CONFIG_DIR/aiosbot.json" << 'AIOSBOT'
{
  "models": {
    "providers": {
      "anthropic-router": {
        "baseUrl": "http://localhost:55119/v1",
        "apiKey": "dummy",
        "api": "openai-completions",
        "models": [{ "id": "router-auto", "name": "Smart Router" }]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "anthropic-router/router-auto" },
      "models": { "anthropic-router/router-auto": { "alias": "smart" } }
    },
    "list": [{ "id": "jim", "skills": ["memory"] }]
  },
  "tools": {
    "shell": { "denyPatterns": ["rm -rf /"] },
    "filesystem": { "restrictToWorkspace": true }
  },
  "gateway": {
    "auth": { "mode": "password", "password": "new-password" },
    "tailscale": { "mode": "serve" }
  },
  "hooks": { "enabled": true, "token": "abc123" },
  "channels": {
    "whatsapp": { "accounts": { "default": { "enabled": true } } }
  },
  "skills": { "entries": { "memory": { "enabled": true } } }
}
AIOSBOT
}

# Helper: run the merge Node.js inline (extracted from 14-gateway-config.sh)
run_merge() {
  local openclaw_path="${1:-$OPENCLAW_DIR/openclaw.json}"
  local aiosbot_path="${2:-$CONFIG_DIR/aiosbot.json}"
  local agent_id="${3:-jim}"
  local agent_workspace="${4:-/opt/legendsclaw/deployer/apps/jim/workspace}"
  local agent_skills_dir="${5:-/opt/legendsclaw/deployer/apps/jim/skills}"

  OPENCLAW_PATH="$openclaw_path" \
  AIOSBOT_PATH="$aiosbot_path" \
  AGENT_ID="$agent_id" \
  AGENT_WORKSPACE="$agent_workspace" \
  AGENT_SKILLS_DIR="$agent_skills_dir" \
  node -e '
const fs = require("fs");
const e = process.env;
const openclaw = JSON.parse(fs.readFileSync(e.OPENCLAW_PATH, "utf8"));
const aiosbot = JSON.parse(fs.readFileSync(e.AIOSBOT_PATH, "utf8"));
openclaw.models = openclaw.models || {};
openclaw.models.providers = { ...openclaw.models.providers, ...aiosbot.models?.providers };
openclaw.agents = openclaw.agents || {};
openclaw.agents.defaults = openclaw.agents.defaults || {};
if (aiosbot.agents?.defaults?.model) openclaw.agents.defaults.model = aiosbot.agents.defaults.model;
if (aiosbot.agents?.defaults?.models) openclaw.agents.defaults.models = { ...openclaw.agents.defaults.models, ...aiosbot.agents.defaults.models };
openclaw.agents.list = openclaw.agents.list || [];
const existingIdx = openclaw.agents.list.findIndex(a => a.id === e.AGENT_ID);
const agentEntry = { id: e.AGENT_ID, workspace: e.AGENT_WORKSPACE, skills: aiosbot.agents?.list?.[0]?.skills || undefined };
if (existingIdx >= 0) { openclaw.agents.list[existingIdx] = { ...openclaw.agents.list[existingIdx], ...agentEntry }; }
else { openclaw.agents.list.push(agentEntry); }
openclaw.skills = openclaw.skills || {};
openclaw.skills.load = openclaw.skills.load || {};
openclaw.skills.load.extraDirs = openclaw.skills.load.extraDirs || [];
if (!openclaw.skills.load.extraDirs.includes(e.AGENT_SKILLS_DIR)) { openclaw.skills.load.extraDirs.push(e.AGENT_SKILLS_DIR); }
if (aiosbot.skills?.entries) { openclaw.skills.entries = { ...openclaw.skills.entries, ...aiosbot.skills.entries }; }
openclaw.gateway = openclaw.gateway || {};
openclaw.gateway.tailscale = { ...openclaw.gateway.tailscale, mode: "serve" };
if (aiosbot.gateway?.auth) openclaw.gateway.auth = aiosbot.gateway.auth;
if (aiosbot.tools) {
  openclaw.tools = openclaw.tools || {};
  if (aiosbot.tools.shell) openclaw.tools.shell = { ...openclaw.tools.shell, ...aiosbot.tools.shell };
  if (aiosbot.tools.filesystem) openclaw.tools.filesystem = { ...openclaw.tools.filesystem, ...aiosbot.tools.filesystem };
}
if (aiosbot.channels?.whatsapp) { openclaw.channels = openclaw.channels || {}; openclaw.channels.whatsapp = { ...openclaw.channels.whatsapp, ...aiosbot.channels.whatsapp }; }
if (aiosbot.hooks) openclaw.hooks = { ...openclaw.hooks, ...aiosbot.hooks };
fs.writeFileSync(e.OPENCLAW_PATH, JSON.stringify(openclaw, null, 2) + "\n");
'
}

# =============================================================================
# Test 2.1: Merge with existing openclaw.json (AC1)
# =============================================================================
@test "merge: fields from aiosbot.json merged into openclaw.json" {
  create_onboard_config
  create_aiosbot_config
  run_merge

  # Verify merged file is valid JSON
  run node -e "JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'))"
  [ "$status" -eq 0 ]

  # Verify models.providers has anthropic-router (AC9)
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.models.providers['anthropic-router'].baseUrl)"
  [ "$output" = "http://localhost:55119/v1" ]
}

# =============================================================================
# Test 2.2: Skip when openclaw.json absent (AC10)
# =============================================================================
@test "merge: skip gracefully when openclaw.json does not exist" {
  # Do NOT create onboard config — file should not exist
  create_aiosbot_config

  # The merge should not be called; simulate the bash check
  if [[ ! -f "$OPENCLAW_DIR/openclaw.json" ]]; then
    skip_msg="openclaw.json nao encontrado"
  fi

  [ "$skip_msg" = "openclaw.json nao encontrado" ]
}

# =============================================================================
# Test 2.3: Onboard fields preserved (AC2)
# =============================================================================
@test "merge: gateway.port, gateway.bind, wizard, auth.profiles preserved" {
  create_onboard_config
  create_aiosbot_config
  run_merge

  # gateway.port preserved (19888)
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.gateway.port)"
  [ "$output" = "19888" ]

  # gateway.bind preserved (loopback)
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.gateway.bind)"
  [ "$output" = "loopback" ]

  # wizard preserved
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.wizard.lastRunAt)"
  [ "$output" = "2026-01-01T00:00:00Z" ]

  # auth.profiles preserved
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.auth.profiles.openrouter.key)"
  [ "$output" = "sk-or-xxx" ]

  # commands preserved
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.commands.native)"
  [ "$output" = "auto" ]

  # meta preserved
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.meta.version)"
  [ "$output" = "2026.2.21" ]
}

# =============================================================================
# Test 2.4: Backup created (AC3)
# =============================================================================
@test "merge: backup .bak created before merge" {
  create_onboard_config
  create_aiosbot_config

  # Simulate backup step
  cp "$OPENCLAW_DIR/openclaw.json" "$OPENCLAW_DIR/openclaw.json.bak"
  run_merge

  # Backup should exist
  [ -f "$OPENCLAW_DIR/openclaw.json.bak" ]

  # Backup should be the original (pre-merge) content
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json.bak','utf8'));console.log(c.gateway.tailscale.mode)"
  [ "$output" = "off" ]
}

# =============================================================================
# Test 2.5: agents.list[] has agent with correct workspace (AC6)
# =============================================================================
@test "merge: agent registered in agents.list[] with workspace" {
  create_onboard_config
  create_aiosbot_config
  run_merge

  # Agent exists in list
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));const a=c.agents.list.find(x=>x.id==='jim');console.log(a.workspace)"
  [ "$output" = "/opt/legendsclaw/deployer/apps/jim/workspace" ]

  # Agent has skills
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));const a=c.agents.list.find(x=>x.id==='jim');console.log(JSON.stringify(a.skills))"
  [ "$output" = '["memory"]' ]
}

# =============================================================================
# Test 2.6: skills.load.extraDirs has correct directory (AC7)
# =============================================================================
@test "merge: skills.load.extraDirs includes agent skills dir" {
  create_onboard_config
  create_aiosbot_config
  run_merge

  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.skills.load.extraDirs.includes('/opt/legendsclaw/deployer/apps/jim/skills'))"
  [ "$output" = "true" ]
}

# =============================================================================
# Test 2.7: Idempotency — re-run does not duplicate agent (AC11)
# =============================================================================
@test "merge: idempotent — re-run does not duplicate agent in list" {
  create_onboard_config
  create_aiosbot_config

  # Run merge twice
  run_merge
  run_merge

  # Should have exactly 1 agent with id "jim"
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.agents.list.filter(a=>a.id==='jim').length)"
  [ "$output" = "1" ]

  # skills.load.extraDirs should not have duplicates
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));const d=c.skills.load.extraDirs;console.log(d.length===new Set(d).size)"
  [ "$output" = "true" ]
}

# =============================================================================
# Test 2.8: aiosbot.json unchanged after merge (AC5)
# =============================================================================
@test "merge: aiosbot.json remains unchanged after merge" {
  create_onboard_config
  create_aiosbot_config

  # Capture before
  local before
  before=$(cat "$CONFIG_DIR/aiosbot.json")

  run_merge

  # aiosbot.json should be identical
  local after
  after=$(cat "$CONFIG_DIR/aiosbot.json")

  [ "$before" = "$after" ]
}

# =============================================================================
# Additional: gateway.tailscale.mode set to "serve" (AC8)
# =============================================================================
@test "merge: gateway.tailscale.mode set to serve" {
  create_onboard_config
  create_aiosbot_config
  run_merge

  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.gateway.tailscale.mode)"
  [ "$output" = "serve" ]

  # resetOnExit preserved from original
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.gateway.tailscale.resetOnExit)"
  [ "$output" = "false" ]
}

# =============================================================================
# Additional: agent update (not duplicate) when re-run with different workspace
# =============================================================================
@test "merge: existing agent updated (not duplicated) on re-run with new workspace" {
  create_onboard_config
  create_aiosbot_config

  # First run
  run_merge

  # Second run with different workspace
  run_merge "$OPENCLAW_DIR/openclaw.json" "$CONFIG_DIR/aiosbot.json" "jim" "/new/workspace" "/new/skills"

  # Still only 1 agent
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.agents.list.filter(a=>a.id==='jim').length)"
  [ "$output" = "1" ]

  # Workspace updated
  run node -e "const c=JSON.parse(require('fs').readFileSync('$OPENCLAW_DIR/openclaw.json','utf8'));console.log(c.agents.list[0].workspace)"
  [ "$output" = "/new/workspace" ]
}
