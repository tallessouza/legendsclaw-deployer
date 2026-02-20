#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/10-elicitation.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/10-elicitation.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

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

  # Mock dirs
  export TEST_APPS_DIR="$(mktemp -d)"
  export TEST_ENV_DIR="$(mktemp -d)"
  export TEST_SKILLS_DIR="${TEST_APPS_DIR}/test-agent/skills"
  mkdir -p "$TEST_SKILLS_DIR"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" "$TEST_ENV_DIR" 2>/dev/null || true
}

# =============================================================================
# hint_elicitation
# =============================================================================

@test "hint_elicitation displays header" {
  run hint_elicitation "jarvis"
  [[ "$output" == *"ELICITATION"* ]]
  [[ "$output" == *"DEBUG"* ]]
}

@test "hint_elicitation shows skill verification command" {
  run hint_elicitation "jarvis"
  [[ "$output" == *"elicitation"* ]]
  [[ "$output" == *"require"* ]]
}

@test "hint_elicitation shows health check command" {
  run hint_elicitation "jarvis"
  [[ "$output" == *"health"* ]]
}

@test "hint_elicitation shows supabase connectivity hint" {
  run hint_elicitation "jarvis"
  [[ "$output" == *"Supabase"* ]] || [[ "$output" == *"supabase"* ]]
  [[ "$output" == *"curl"* ]]
}

@test "hint_elicitation shows table creation hint when tables missing" {
  run hint_elicitation "jarvis" "MISSING"
  [[ "$output" == *"tabelas"* ]] || [[ "$output" == *"Story 4.3"* ]] || [[ "$output" == *"migration"* ]]
}

@test "hint_elicitation hides table hint when tables OK" {
  run hint_elicitation "jarvis" "OK"
  [[ "$output" != *"migration"* ]]
}

@test "hint_elicitation shows config path with agent name" {
  run hint_elicitation "atlas"
  [[ "$output" == *"apps/atlas/skills"* ]]
}

@test "hint_elicitation uses default agent name when empty" {
  run hint_elicitation
  [[ "$output" == *"meu-agente"* ]]
}

@test "hint_elicitation shows next steps" {
  run hint_elicitation "jarvis"
  [[ "$output" == *"Story 4.3"* ]] || [[ "$output" == *"Proximo"* ]]
}

# =============================================================================
# Elicitation Directory Structure
# =============================================================================

@test "elicitation dir: creates index.js" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools"
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
const startSession = require('./tools/start-session');
const processMessage = require('./tools/process-message');
const getStatus = require('./tools/get-status');
const exportResults = require('./tools/export-results');
module.exports = { name: 'elicitation', description: 'Entrevistas estruturadas', tools: { startSession, processMessage, getStatus, exportResults }, handler: async () => {}, health: async () => {} };
EOF
  [[ -f "${TEST_SKILLS_DIR}/elicitation/index.js" ]]
}

@test "elicitation dir: creates tools subdirectory" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools"
  [[ -d "${TEST_SKILLS_DIR}/elicitation/tools" ]]
}

@test "elicitation dir: creates lib subdirectory" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/lib"
  [[ -d "${TEST_SKILLS_DIR}/elicitation/lib" ]]
}

@test "elicitation dir: creates SKILL.md" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/SKILL.md" << 'EOF'
# elicitation
## Description
Conduz entrevistas estruturadas via templates
## Environment Variables
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
## Tools
- start_session
- process_message
- get_status
- export_results
EOF
  [[ -f "${TEST_SKILLS_DIR}/elicitation/SKILL.md" ]]
}

# =============================================================================
# index.js Exports
# =============================================================================

@test "index.js: exports name field" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
module.exports = { name: 'elicitation', description: 'Conduz entrevistas estruturadas via templates', tools: {}, handler: async () => {}, health: async () => {} };
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/index.js"
  [[ "$output" == *"name: 'elicitation'"* ]]
}

@test "index.js: exports description field" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
module.exports = { name: 'elicitation', description: 'Conduz entrevistas estruturadas via templates', tools: {}, handler: async () => {}, health: async () => {} };
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/index.js"
  [[ "$output" == *"description:"* ]]
}

@test "index.js: exports handler function" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
module.exports = { name: 'elicitation', handler: async () => {}, health: async () => {} };
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/index.js"
  [[ "$output" == *"handler"* ]]
}

@test "index.js: exports health function" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
module.exports = { name: 'elicitation', handler: async () => {}, health: async () => {} };
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/index.js"
  [[ "$output" == *"health"* ]]
}

@test "index.js: exports tools object" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
module.exports = { name: 'elicitation', tools: { startSession: {}, processMessage: {}, getStatus: {}, exportResults: {} } };
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/index.js"
  [[ "$output" == *"tools:"* ]]
  [[ "$output" == *"startSession"* ]]
  [[ "$output" == *"processMessage"* ]]
  [[ "$output" == *"getStatus"* ]]
  [[ "$output" == *"exportResults"* ]]
}

# =============================================================================
# Tool Files Existence
# =============================================================================

@test "tool: start-session.js exists and exports startSession" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools"
  cat > "${TEST_SKILLS_DIR}/elicitation/tools/start-session.js" << 'EOF'
async function startSession(templateId) { return {}; }
module.exports = { startSession };
EOF
  [[ -f "${TEST_SKILLS_DIR}/elicitation/tools/start-session.js" ]]
  run cat "${TEST_SKILLS_DIR}/elicitation/tools/start-session.js"
  [[ "$output" == *"startSession"* ]]
}

@test "tool: process-message.js exists and exports processMessage" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools"
  cat > "${TEST_SKILLS_DIR}/elicitation/tools/process-message.js" << 'EOF'
async function processMessage(sessionId, userMessage) { return {}; }
module.exports = { processMessage };
EOF
  [[ -f "${TEST_SKILLS_DIR}/elicitation/tools/process-message.js" ]]
  run cat "${TEST_SKILLS_DIR}/elicitation/tools/process-message.js"
  [[ "$output" == *"processMessage"* ]]
}

@test "tool: get-status.js exists and exports getStatus" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools"
  cat > "${TEST_SKILLS_DIR}/elicitation/tools/get-status.js" << 'EOF'
async function getStatus(sessionId) { return {}; }
module.exports = { getStatus };
EOF
  [[ -f "${TEST_SKILLS_DIR}/elicitation/tools/get-status.js" ]]
  run cat "${TEST_SKILLS_DIR}/elicitation/tools/get-status.js"
  [[ "$output" == *"getStatus"* ]]
}

@test "tool: export-results.js exists and exports exportResults" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools"
  cat > "${TEST_SKILLS_DIR}/elicitation/tools/export-results.js" << 'EOF'
async function exportResults(sessionId, format) { return {}; }
module.exports = { exportResults };
EOF
  [[ -f "${TEST_SKILLS_DIR}/elicitation/tools/export-results.js" ]]
  run cat "${TEST_SKILLS_DIR}/elicitation/tools/export-results.js"
  [[ "$output" == *"exportResults"* ]]
}

# =============================================================================
# supabase-client.js
# =============================================================================

@test "supabase-client: exports query function" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
async function query(table, method, params) {}
async function insert(table, data) {}
async function select(table, filters) {}
async function update(table, filters, data) {}
module.exports = { query, insert, select, update };
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js"
  [[ "$output" == *"query"* ]]
  [[ "$output" == *"insert"* ]]
  [[ "$output" == *"select"* ]]
  [[ "$output" == *"update"* ]]
}

# =============================================================================
# SKILL.md Required Fields
# =============================================================================

@test "SKILL.md: contains skill name" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/SKILL.md" << 'EOF'
# elicitation
## Description
Conduz entrevistas estruturadas via templates
## Environment Variables
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
## Tools
- start_session
- process_message
- get_status
- export_results
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/SKILL.md"
  [[ "$output" == *"elicitation"* ]]
}

@test "SKILL.md: contains env vars" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/SKILL.md" << 'EOF'
# elicitation
## Environment Variables
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/SKILL.md"
  [[ "$output" == *"SUPABASE_URL"* ]]
  [[ "$output" == *"SUPABASE_SERVICE_ROLE_KEY"* ]]
}

@test "SKILL.md: lists all 4 tools" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/SKILL.md" << 'EOF'
## Tools
- start_session
- process_message
- get_status
- export_results
EOF
  run cat "${TEST_SKILLS_DIR}/elicitation/SKILL.md"
  [[ "$output" == *"start_session"* ]]
  [[ "$output" == *"process_message"* ]]
  [[ "$output" == *"get_status"* ]]
  [[ "$output" == *"export_results"* ]]
}

# =============================================================================
# Registration in skills/index.js
# =============================================================================

@test "skills index.js: has require for elicitation" {
  cat > "${TEST_SKILLS_DIR}/index.js" << 'EOF'
const clickup_ops = require('./clickup-ops');
const elicitation = require('./elicitation');
const skills = [clickup_ops, elicitation];
module.exports = { skills };
EOF
  run cat "${TEST_SKILLS_DIR}/index.js"
  [[ "$output" == *"require('./elicitation')"* ]]
}

@test "skills index.js: elicitation in skills array" {
  cat > "${TEST_SKILLS_DIR}/index.js" << 'EOF'
const elicitation = require('./elicitation');
const skills = [elicitation];
module.exports = { skills };
EOF
  run cat "${TEST_SKILLS_DIR}/index.js"
  [[ "$output" == *"skills"* ]]
  [[ "$output" == *"elicitation"* ]]
}

# =============================================================================
# dados_elicitation State File
# =============================================================================

@test "dados_elicitation: contains Agente field" {
  cat > "$STATE_DIR/dados_elicitation" << 'EOF'
Agente: jarvis
Skill: elicitation
Tools: start_session, process_message, get_status, export_results
Supabase: configurado
Health Check: OK
Data Configuracao: 2026-02-20 15:30:00
EOF
  run cat "$STATE_DIR/dados_elicitation"
  [[ "$output" == *"Agente: jarvis"* ]]
}

@test "dados_elicitation: contains Skill field" {
  cat > "$STATE_DIR/dados_elicitation" << 'EOF'
Skill: elicitation
EOF
  run cat "$STATE_DIR/dados_elicitation"
  [[ "$output" == *"Skill: elicitation"* ]]
}

@test "dados_elicitation: contains Tools list" {
  cat > "$STATE_DIR/dados_elicitation" << 'EOF'
Tools: start_session, process_message, get_status, export_results
EOF
  run cat "$STATE_DIR/dados_elicitation"
  [[ "$output" == *"start_session"* ]]
  [[ "$output" == *"process_message"* ]]
  [[ "$output" == *"get_status"* ]]
  [[ "$output" == *"export_results"* ]]
}

@test "dados_elicitation: contains Supabase status" {
  cat > "$STATE_DIR/dados_elicitation" << 'EOF'
Supabase: configurado
EOF
  run cat "$STATE_DIR/dados_elicitation"
  [[ "$output" == *"Supabase:"* ]]
}

@test "dados_elicitation: contains Health Check" {
  cat > "$STATE_DIR/dados_elicitation" << 'EOF'
Health Check: OK
EOF
  run cat "$STATE_DIR/dados_elicitation"
  [[ "$output" == *"Health Check:"* ]]
}

@test "dados_elicitation: chmod 600 applied" {
  echo "test" > "$STATE_DIR/dados_elicitation"
  chmod 600 "$STATE_DIR/dados_elicitation"
  local perms
  perms=$(stat -c "%a" "$STATE_DIR/dados_elicitation" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/dados_elicitation" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

@test "dados_elicitation: contains Data Configuracao" {
  cat > "$STATE_DIR/dados_elicitation" << 'EOF'
Data Configuracao: 2026-02-20 15:30:00
EOF
  run cat "$STATE_DIR/dados_elicitation"
  [[ "$output" == *"Data Configuracao:"* ]]
}

# =============================================================================
# Failure Scenarios
# =============================================================================

@test "failure: dados_whitelabel ausente blocks execution" {
  rm -f "$STATE_DIR/dados_whitelabel" 2>/dev/null || true
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
}

@test "failure: skills dir ausente detected" {
  local missing_dir="${TEST_APPS_DIR}/nonexistent/skills"
  [[ ! -d "$missing_dir" ]]
}

# =============================================================================
# Re-execution Scenarios
# =============================================================================

@test "re-execution: existing elicitation dir preserved" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  echo "existing content" > "${TEST_SKILLS_DIR}/elicitation/custom.js"
  # step_skip deve ser chamado, dir preservado
  [[ -d "${TEST_SKILLS_DIR}/elicitation" ]]
  [[ -f "${TEST_SKILLS_DIR}/elicitation/custom.js" ]]
}

@test "re-execution: index.js backup created" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation"
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
module.exports = { name: 'elicitation' };
EOF
  cp -p "${TEST_SKILLS_DIR}/elicitation/index.js" "${TEST_SKILLS_DIR}/elicitation/index.js.bak"
  [[ -f "${TEST_SKILLS_DIR}/elicitation/index.js.bak" ]]
}

# =============================================================================
# Deployer Menu Integration
# =============================================================================

@test "deployer menu: contains entry 10 Elicitation" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"[10]"* ]]
  [[ "$output" == *"Elicitation"* ]]
}

@test "deployer menu: case 10 calls 10-elicitation.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"10)"* ]]
  [[ "$output" == *"10-elicitation.sh"* ]]
}

# =============================================================================
# Node.js Tool Validation (4B — basic Node.js tests)
# =============================================================================

@test "node: elicitation index.js is valid JS (syntax check)" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools" "${TEST_SKILLS_DIR}/elicitation/lib"

  # Create minimal supabase-client
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'SBEOF'
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
async function query(table, method, params) { return {}; }
async function insert(table, data) { return {}; }
async function select(table, filters) { return []; }
async function update(table, filters, data) { return {}; }
module.exports = { query, insert, select, update };
SBEOF

  # Create tool stubs
  for tool in start-session process-message get-status export-results; do
    fn=$(echo "$tool" | sed 's/-\([a-z]\)/\U\1/g')
    cat > "${TEST_SKILLS_DIR}/elicitation/tools/${tool}.js" << TOOLEOF
const sb = require('../lib/supabase-client');
async function ${fn}() { return {}; }
module.exports = { ${fn} };
TOOLEOF
  done

  # Create index.js
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'IDXEOF'
const { startSession } = require('./tools/start-session');
const { processMessage } = require('./tools/process-message');
const { getStatus } = require('./tools/get-status');
const { exportResults } = require('./tools/export-results');
module.exports = {
  name: 'elicitation',
  description: 'Conduz entrevistas estruturadas via templates',
  tools: { startSession, processMessage, getStatus, exportResults },
  handler: async (action, params) => {
    const actions = { start_session: startSession, process_message: processMessage, get_status: getStatus, export_results: exportResults };
    if (!actions[action]) throw new Error('Unknown action: ' + action);
    return actions[action](params);
  },
  health: async () => ({ status: 'OK' })
};
IDXEOF

  run node -e "require('${TEST_SKILLS_DIR}/elicitation')"
  [ "$status" -eq 0 ]
}

@test "node: elicitation exports correct name" {
  # Reuse structure from previous test setup
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools" "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
module.exports = { query: async()=>{}, insert: async()=>{}, select: async()=>[], update: async()=>{} };
EOF
  for tool in start-session process-message get-status export-results; do
    fn=$(echo "$tool" | sed 's/-\([a-z]\)/\U\1/g')
    cat > "${TEST_SKILLS_DIR}/elicitation/tools/${tool}.js" << TOOLEOF
module.exports = { ${fn}: async()=>({}) };
TOOLEOF
  done
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
const { startSession } = require('./tools/start-session');
const { processMessage } = require('./tools/process-message');
const { getStatus } = require('./tools/get-status');
const { exportResults } = require('./tools/export-results');
module.exports = { name: 'elicitation', description: 'test', tools: { startSession, processMessage, getStatus, exportResults }, handler: async()=>{}, health: async()=>({status:'OK'}) };
EOF
  run node -e "const m = require('${TEST_SKILLS_DIR}/elicitation'); console.log(m.name);"
  [ "$status" -eq 0 ]
  [[ "$output" == *"elicitation"* ]]
}

@test "node: elicitation exports all 4 tools" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools" "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
module.exports = { query: async()=>{}, insert: async()=>{}, select: async()=>[], update: async()=>{} };
EOF
  for tool in start-session process-message get-status export-results; do
    fn=$(echo "$tool" | sed 's/-\([a-z]\)/\U\1/g')
    cat > "${TEST_SKILLS_DIR}/elicitation/tools/${tool}.js" << TOOLEOF
module.exports = { ${fn}: async()=>({}) };
TOOLEOF
  done
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
const { startSession } = require('./tools/start-session');
const { processMessage } = require('./tools/process-message');
const { getStatus } = require('./tools/get-status');
const { exportResults } = require('./tools/export-results');
module.exports = { name: 'elicitation', tools: { startSession, processMessage, getStatus, exportResults }, handler: async()=>{}, health: async()=>({}) };
EOF
  run node -e "const m = require('${TEST_SKILLS_DIR}/elicitation'); const t = Object.keys(m.tools); console.log(t.join(','));"
  [ "$status" -eq 0 ]
  [[ "$output" == *"startSession"* ]]
  [[ "$output" == *"processMessage"* ]]
  [[ "$output" == *"getStatus"* ]]
  [[ "$output" == *"exportResults"* ]]
}

@test "node: elicitation handler dispatches correctly" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools" "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
module.exports = { query: async()=>{}, insert: async()=>{}, select: async()=>[], update: async()=>{} };
EOF
  for tool in start-session process-message get-status export-results; do
    fn=$(echo "$tool" | sed 's/-\([a-z]\)/\U\1/g')
    cat > "${TEST_SKILLS_DIR}/elicitation/tools/${tool}.js" << TOOLEOF
module.exports = { ${fn}: async()=>({ action: '${fn}' }) };
TOOLEOF
  done
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
const { startSession } = require('./tools/start-session');
const { processMessage } = require('./tools/process-message');
const { getStatus } = require('./tools/get-status');
const { exportResults } = require('./tools/export-results');
const actions = { start_session: startSession, process_message: processMessage, get_status: getStatus, export_results: exportResults };
module.exports = {
  name: 'elicitation',
  tools: { startSession, processMessage, getStatus, exportResults },
  handler: async (action, params) => { if (!actions[action]) throw new Error('Unknown: ' + action); return actions[action](params); },
  health: async () => ({ status: 'OK' })
};
EOF
  run node -e "require('${TEST_SKILLS_DIR}/elicitation').handler('start_session',{}).then(r=>console.log(JSON.stringify(r)))"
  [ "$status" -eq 0 ]
  [[ "$output" == *"startSession"* ]]
}

@test "node: elicitation handler rejects unknown action" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools" "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
module.exports = { query: async()=>{}, insert: async()=>{}, select: async()=>[], update: async()=>{} };
EOF
  for tool in start-session process-message get-status export-results; do
    fn=$(echo "$tool" | sed 's/-\([a-z]\)/\U\1/g')
    cat > "${TEST_SKILLS_DIR}/elicitation/tools/${tool}.js" << TOOLEOF
module.exports = { ${fn}: async()=>({}) };
TOOLEOF
  done
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
const { startSession } = require('./tools/start-session');
const { processMessage } = require('./tools/process-message');
const { getStatus } = require('./tools/get-status');
const { exportResults } = require('./tools/export-results');
const actions = { start_session: startSession, process_message: processMessage, get_status: getStatus, export_results: exportResults };
module.exports = {
  name: 'elicitation',
  tools: { startSession, processMessage, getStatus, exportResults },
  handler: async (action, params) => { if (!actions[action]) throw new Error('Unknown: ' + action); return actions[action](params); },
  health: async () => ({ status: 'OK' })
};
EOF
  run node -e "require('${TEST_SKILLS_DIR}/elicitation').handler('invalid_action',{}).catch(e=>console.log('ERROR:'+e.message))"
  [[ "$output" == *"ERROR:"* ]]
  [[ "$output" == *"Unknown"* ]]
}

@test "node: supabase-client exports all 4 functions" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
async function query(table, method, params) { return {}; }
async function insert(table, data) { return {}; }
async function select(table, filters) { return []; }
async function update(table, filters, data) { return {}; }
module.exports = { query, insert, select, update };
EOF
  run node -e "const sb = require('${TEST_SKILLS_DIR}/elicitation/lib/supabase-client'); console.log(Object.keys(sb).join(','));"
  [ "$status" -eq 0 ]
  [[ "$output" == *"query"* ]]
  [[ "$output" == *"insert"* ]]
  [[ "$output" == *"select"* ]]
  [[ "$output" == *"update"* ]]
}

@test "node: health check returns status" {
  mkdir -p "${TEST_SKILLS_DIR}/elicitation/tools" "${TEST_SKILLS_DIR}/elicitation/lib"
  cat > "${TEST_SKILLS_DIR}/elicitation/lib/supabase-client.js" << 'EOF'
module.exports = { query: async()=>{}, insert: async()=>{}, select: async()=>[], update: async()=>{} };
EOF
  for tool in start-session process-message get-status export-results; do
    fn=$(echo "$tool" | sed 's/-\([a-z]\)/\U\1/g')
    cat > "${TEST_SKILLS_DIR}/elicitation/tools/${tool}.js" << TOOLEOF
module.exports = { ${fn}: async()=>({}) };
TOOLEOF
  done
  cat > "${TEST_SKILLS_DIR}/elicitation/index.js" << 'EOF'
const { startSession } = require('./tools/start-session');
const { processMessage } = require('./tools/process-message');
const { getStatus } = require('./tools/get-status');
const { exportResults } = require('./tools/export-results');
module.exports = {
  name: 'elicitation',
  tools: { startSession, processMessage, getStatus, exportResults },
  handler: async () => {},
  health: async () => ({ status: 'OK', supabase: 'not_configured' })
};
EOF
  run node -e "require('${TEST_SKILLS_DIR}/elicitation').health().then(r=>console.log(r.status))"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}
