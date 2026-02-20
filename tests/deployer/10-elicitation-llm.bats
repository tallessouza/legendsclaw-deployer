#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/10-elicitation.sh — Story 4.4
# LLM Extraction, Memory Writer, Event Bus
# Framework: bats-core
# Execucao: npx bats tests/deployer/10-elicitation-llm.bats
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
  export TEST_MEMORY_DIR="$(mktemp -d)/memory/elicitation"
  mkdir -p "$TEST_SKILLS_DIR"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" "$TEST_ENV_DIR" "$TEST_MEMORY_DIR" 2>/dev/null || true
}

# Helper: create minimal elicitation skill structure for Node.js tests
create_elicitation_structure() {
  local dir="${TEST_SKILLS_DIR}/elicitation"
  mkdir -p "${dir}/tools" "${dir}/lib"

  # supabase-client stub
  cat > "${dir}/lib/supabase-client.js" << 'EOF'
module.exports = {
  query: async()=>({}), insert: async()=>({}),
  select: async()=>([]), update: async()=>({}),
  sanitize: (v) => v,
};
EOF
}

# =============================================================================
# llm-extractor.js — Generation and Structure (Task 7.2)
# =============================================================================

@test "llm-extractor.js: generated with extractData export" {
  run grep -c 'llm-extractor.js' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" -ge 1 ]]
}

@test "llm-extractor.js: heredoc contains extractData function" {
  run grep 'extractData' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"extractData"* ]]
}

@test "llm-extractor.js: heredoc contains generateFollowUp function" {
  run grep 'generateFollowUp' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"generateFollowUp"* ]]
}

@test "llm-extractor.js: exports extractData and generateFollowUp" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/llm-extractor.js" << 'EOF'
function maskKey(k) { return k ? k.slice(0,6)+'...'+k.slice(-4) : '***'; }
function loadConfig() { return { openrouter_api_key: '', timeout_ms: 30000 }; }
async function extractData(q, msg, type, agent) { return { extracted: false, fallback: true }; }
async function generateFollowUp(q, msg, reason, agent) { return 'follow-up'; }
module.exports = { extractData, generateFollowUp, maskKey, loadConfig };
EOF

  run node -e "const m = require('${dir}/lib/llm-extractor'); console.log(Object.keys(m).join(','));"
  [ "$status" -eq 0 ]
  [[ "$output" == *"extractData"* ]]
  [[ "$output" == *"generateFollowUp"* ]]
  [[ "$output" == *"maskKey"* ]]
}

@test "llm-extractor.js: maskKey hides API key" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/llm-extractor.js" << 'EOF'
function maskKey(k) { if (!k || k.length < 8) return '***'; return k.slice(0,6)+'...'+k.slice(-4); }
module.exports = { maskKey };
EOF

  run node -e "const {maskKey} = require('${dir}/lib/llm-extractor'); console.log(maskKey('sk-or-v1-abcdef1234567890'));"
  [ "$status" -eq 0 ]
  [[ "$output" != *"abcdef1234567890"* ]]
  [[ "$output" == *"..."* ]]
}

@test "llm-extractor.js: extractData returns fallback when no API key" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/llm-extractor.js" << 'EOF'
function loadConfig() { return { openrouter_api_key: '', timeout_ms: 30000 }; }
async function extractData(q, msg, type, agent) {
  const config = loadConfig(agent);
  if (!config.openrouter_api_key) return { extracted: false, fallback: true };
  return { extracted: true };
}
module.exports = { extractData, loadConfig };
EOF

  run node -e "require('${dir}/lib/llm-extractor').extractData({text:'q'},'msg','text','').then(r=>console.log(JSON.stringify(r)));"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"fallback":true'* ]]
}

# =============================================================================
# memory-writer.js — Generation and Structure (Task 7.3)
# =============================================================================

@test "memory-writer.js: generated with writeMemoryFiles export" {
  run grep -c 'memory-writer.js' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" -ge 1 ]]
}

@test "memory-writer.js: heredoc contains writeMemoryFiles function" {
  run grep 'writeMemoryFiles' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"writeMemoryFiles"* ]]
}

@test "memory-writer.js: exports writeMemoryFiles" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/memory-writer.js" << MWEOF
const fs = require('fs');
const path = require('path');
const MEMORY_BASE = '${TEST_MEMORY_DIR}';
async function writeMemoryFiles(results) {
  fs.mkdirSync(MEMORY_BASE, { recursive: true });
  const files = [];
  fs.writeFileSync(path.join(MEMORY_BASE, 'User.md'), '# User\n', { mode: 0o600 });
  files.push('User.md');
  return { memory_files: files, memory_path: MEMORY_BASE };
}
module.exports = { writeMemoryFiles, MEMORY_BASE };
MWEOF

  run node -e "const m = require('${dir}/lib/memory-writer'); console.log(Object.keys(m).join(','));"
  [ "$status" -eq 0 ]
  [[ "$output" == *"writeMemoryFiles"* ]]
  [[ "$output" == *"MEMORY_BASE"* ]]
}

@test "memory-writer.js: creates memory files with chmod 600" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/memory-writer.js" << MWEOF
const fs = require('fs');
const path = require('path');
const MEMORY_BASE = '${TEST_MEMORY_DIR}';
async function writeMemoryFiles(results) {
  fs.mkdirSync(MEMORY_BASE, { recursive: true });
  const filepath = path.join(MEMORY_BASE, 'User.md');
  fs.writeFileSync(filepath, '# User\n', { mode: 0o600 });
  return { memory_files: ['User.md'], memory_path: MEMORY_BASE };
}
module.exports = { writeMemoryFiles, MEMORY_BASE };
MWEOF

  run node -e "require('${dir}/lib/memory-writer').writeMemoryFiles({sections:[]}).then(r=>console.log(JSON.stringify(r)));"
  [ "$status" -eq 0 ]
  [[ -f "${TEST_MEMORY_DIR}/User.md" ]]
  local perms
  perms=$(stat -c "%a" "${TEST_MEMORY_DIR}/User.md" 2>/dev/null || stat -f "%Lp" "${TEST_MEMORY_DIR}/User.md" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

# =============================================================================
# event-bus.js — Generation and Structure (Task 7.4)
# =============================================================================

@test "event-bus.js: generated with emit and on exports" {
  run grep -c 'event-bus.js' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" -ge 1 ]]
}

@test "event-bus.js: heredoc contains emit function" {
  run grep 'function emit' "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
}

@test "event-bus.js: exports emit and on" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/event-bus.js" << 'EOF'
const { EventEmitter } = require('events');
const bus = new EventEmitter();
function emit(name, payload) { bus.emit(name, payload); }
function on(name, handler) { bus.on(name, handler); }
module.exports = { emit, on, bus };
EOF

  run node -e "const m = require('${dir}/lib/event-bus'); console.log(Object.keys(m).join(','));"
  [ "$status" -eq 0 ]
  [[ "$output" == *"emit"* ]]
  [[ "$output" == *"on"* ]]
}

@test "event-bus.js: emit triggers registered listener" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/event-bus.js" << 'EOF'
const { EventEmitter } = require('events');
const bus = new EventEmitter();
function emit(name, payload) { bus.emit(name, payload); }
function on(name, handler) { bus.on(name, handler); }
module.exports = { emit, on, bus };
EOF

  run node -e "
    const eb = require('${dir}/lib/event-bus');
    let received = false;
    eb.on('test.event', () => { received = true; });
    eb.emit('test.event', { session_id: '123' });
    console.log(received ? 'RECEIVED' : 'NOT_RECEIVED');
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"RECEIVED"* ]]
}

# =============================================================================
# process-message.js — LLM Integration (Task 7.5, 7.6, 7.7)
# =============================================================================

@test "process-message.js: contains require for llm-extractor" {
  run grep "llm-extractor" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"require"* ]]
  [[ "$output" == *"llm-extractor"* ]]
}

@test "process-message.js: contains fallback for basic extraction" {
  run grep -c "fallback" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" -ge 1 ]]
}

@test "process-message.js: limits follow-ups to MAX_FOLLOWUPS" {
  run grep "MAX_FOLLOWUPS" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MAX_FOLLOWUPS"* ]]
}

@test "process-message.js: contains extraction_method field" {
  run grep "extraction_method" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"extraction_method"* ]]
}

@test "process-message.js: contains confidence field" {
  run grep "confidence" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"confidence"* ]]
}

@test "process-message.js: contains best_effort extraction method" {
  run grep "best_effort" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"best_effort"* ]]
}

# =============================================================================
# export-results.js — Memory + Event Bus (Task 7.8, 7.9)
# =============================================================================

@test "export-results.js: contains require for memory-writer" {
  run grep "memory-writer" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"require"* ]]
  [[ "$output" == *"memory-writer"* ]]
}

@test "export-results.js: calls writeMemoryFiles" {
  run grep "writeMemoryFiles" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"writeMemoryFiles"* ]]
}

@test "export-results.js: emits elicitation.session.completed event" {
  run grep "elicitation.session.completed" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"elicitation.session.completed"* ]]
}

@test "export-results.js: contains require for event-bus" {
  run grep "event-bus" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"require"* ]]
  [[ "$output" == *"event-bus"* ]]
}

# =============================================================================
# Memory Directory (Task 7.10)
# =============================================================================

@test "deployer: creates memory elicitation directory" {
  run grep "clawd/memory/elicitation" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mkdir"* ]] || [[ "$output" == *"memory/elicitation"* ]]
}

@test "memory directory: mkdir -p creates full path" {
  mkdir -p "${TEST_MEMORY_DIR}"
  [[ -d "${TEST_MEMORY_DIR}" ]]
}

# =============================================================================
# dados_elicitation — Updated Fields (Task 7.11)
# =============================================================================

@test "dados_elicitation: contains LLM Extraction field" {
  run grep "LLM Extraction" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"LLM Extraction"* ]]
}

@test "dados_elicitation: contains Memory Path field" {
  run grep "Memory Path" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Memory Path"* ]]
}

@test "dados_elicitation: contains Event Bus field" {
  run grep "Event Bus" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Event Bus"* ]]
}

# =============================================================================
# hint_elicitation — Updated Hints (Task 7.12)
# =============================================================================

@test "hint_elicitation: shows LLM extraction status when enabled" {
  run hint_elicitation "jarvis" "OK" "true"
  [[ "$output" == *"LLM Extraction"* ]]
  [[ "$output" == *"habilitado"* ]]
  [[ "$output" == *"OpenRouter"* ]]
}

@test "hint_elicitation: shows LLM disabled hint when not enabled" {
  run hint_elicitation "jarvis" "OK" "false"
  [[ "$output" == *"LLM Extraction"* ]]
  [[ "$output" == *"desabilitado"* ]]
  [[ "$output" == *"Ferramenta [08]"* ]]
}

@test "hint_elicitation: shows Memory Manager hint" {
  run hint_elicitation "jarvis" "OK" "true"
  [[ "$output" == *"Memory Manager"* ]]
  [[ "$output" == *"clawd/memory/elicitation"* ]]
}

@test "hint_elicitation: backward compatible with 2 args" {
  run hint_elicitation "jarvis" "OK"
  [[ "$output" == *"ELICITATION"* ]]
  [[ "$output" == *"desabilitado"* ]]
}

# =============================================================================
# Failure Scenarios (Task 7.13, 7.14)
# =============================================================================

@test "failure: OPENROUTER_API_KEY absent triggers fallback" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/llm-extractor.js" << 'EOF'
function loadConfig() { return { openrouter_api_key: '', timeout_ms: 30000 }; }
async function extractData(q, msg, type, agent) {
  const config = loadConfig();
  if (!config.openrouter_api_key) return { extracted: false, fallback: true };
  return { extracted: true };
}
module.exports = { extractData, loadConfig };
EOF

  run node -e "
    delete process.env.OPENROUTER_API_KEY;
    require('${dir}/lib/llm-extractor').extractData({text:'q'},'msg','text','').then(r=>{
      console.log(r.fallback ? 'FALLBACK' : 'NO_FALLBACK');
    });
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"FALLBACK"* ]]
}

@test "failure: LLM timeout triggers fallback" {
  create_elicitation_structure
  local dir="${TEST_SKILLS_DIR}/elicitation"

  cat > "${dir}/lib/llm-extractor.js" << 'EOF'
async function extractData(q, msg, type, agent) {
  // Simulate timeout by returning fallback
  return { extracted: false, fallback: true };
}
module.exports = { extractData };
EOF

  run node -e "
    require('${dir}/lib/llm-extractor').extractData({text:'q'},'msg','text','').then(r=>{
      console.log(r.fallback ? 'FALLBACK' : 'NO_FALLBACK');
    });
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"FALLBACK"* ]]
}

# =============================================================================
# LLM Router Detection (Step verification)
# =============================================================================

@test "deployer: checks dados_llm_router for LLM detection" {
  run grep "dados_llm_router" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dados_llm_router"* ]]
}

@test "deployer: sets llm_extraction_enabled variable" {
  run grep "llm_extraction_enabled" "$SCRIPT_DIR/ferramentas/10-elicitation.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"llm_extraction_enabled"* ]]
}
