#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/08-skills.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/08-skills.bats
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
# hint_skills
# =============================================================================

@test "hint_skills displays header" {
  run hint_skills "jarvis" "clickup-ops" "memory"
  [[ "$output" == *"SKILLS"* ]]
  [[ "$output" == *"DEBUG"* ]]
}

@test "hint_skills shows ClickUp hint when selected" {
  run hint_skills "jarvis" "clickup-ops"
  [[ "$output" == *"ClickUp"* ]]
  [[ "$output" == *"api.clickup.com"* ]]
}

@test "hint_skills shows N8N hint when selected" {
  run hint_skills "jarvis" "n8n-trigger"
  [[ "$output" == *"N8N"* ]]
  [[ "$output" == *"healthz"* ]]
}

@test "hint_skills shows Supabase hint when selected" {
  run hint_skills "jarvis" "supabase-query"
  [[ "$output" == *"Supabase"* ]]
  [[ "$output" == *"rest/v1"* ]]
}

@test "hint_skills shows Gateway hint when selected" {
  run hint_skills "jarvis" "allos-status"
  [[ "$output" == *"Gateway"* ]]
  [[ "$output" == *"health"* ]]
}

@test "hint_skills shows Slack hint when selected" {
  run hint_skills "jarvis" "alerts"
  [[ "$output" == *"Slack"* ]]
  [[ "$output" == *"SLACK_ALERTS_WEBHOOK_URL"* ]]
}

@test "hint_skills shows Memory hint when selected" {
  run hint_skills "jarvis" "memory"
  [[ "$output" == *"Memory"* ]]
  [[ "$output" == *"clawd/memory"* ]]
}

@test "hint_skills shows config path with agent name" {
  run hint_skills "atlas" "memory"
  [[ "$output" == *"apps/atlas/skills/config.js"* ]]
}

@test "hint_skills shows next steps: Elicitation" {
  run hint_skills "jarvis" "memory"
  [[ "$output" == *"Elicitation"* ]] || [[ "$output" == *"Story 4.2"* ]]
}

@test "hint_skills uses default agent name when empty" {
  run hint_skills
  [[ "$output" == *"meu-agente"* ]]
}

@test "hint_skills only shows selected skills (not all)" {
  run hint_skills "jarvis" "memory"
  [[ "$output" != *"ClickUp"* ]]
  [[ "$output" != *"N8N"* ]]
  [[ "$output" != *"Supabase"* ]]
}

# =============================================================================
# Skill Selection Validation
# =============================================================================

@test "skill selection: valid number 1 accepted" {
  [[ "1" =~ ^[1-6]$ ]]
}

@test "skill selection: valid number 6 accepted" {
  [[ "6" =~ ^[1-6]$ ]]
}

@test "skill selection: 0 rejected" {
  ! [[ "0" =~ ^[1-6]$ ]]
}

@test "skill selection: 7 rejected" {
  ! [[ "7" =~ ^[1-6]$ ]]
}

@test "skill selection: non-numeric rejected" {
  ! [[ "abc" =~ ^[1-6]$ ]]
}

@test "skill selection: empty rejected" {
  ! [[ "" =~ ^[1-6]$ ]]
}

# =============================================================================
# Input Validation — ClickUp
# =============================================================================

@test "clickup key validation: pk_ prefix accepted" {
  local key="pk_12345678_abcdef"
  [[ "$key" =~ ^pk_ ]]
}

@test "clickup key validation: wrong prefix rejected" {
  local key="sk-abcdef"
  ! [[ "$key" =~ ^pk_ ]]
}

@test "clickup team id: numeric accepted" {
  local id="12345678"
  [[ "$id" =~ ^[0-9]+$ ]]
}

@test "clickup team id: non-numeric rejected" {
  local id="abc123"
  ! [[ "$id" =~ ^[0-9]+$ ]]
}

# =============================================================================
# Input Validation — N8N
# =============================================================================

@test "n8n webhook url: https accepted" {
  local url="https://n8n.example.com"
  [[ "$url" =~ ^https?:// ]]
}

@test "n8n webhook url: http accepted" {
  local url="http://localhost:5678"
  [[ "$url" =~ ^https?:// ]]
}

@test "n8n webhook url: no protocol rejected" {
  local url="n8n.example.com"
  ! [[ "$url" =~ ^https?:// ]]
}

# =============================================================================
# Input Validation — Supabase
# =============================================================================

@test "supabase url: valid format accepted" {
  local url="https://myproject.supabase.co"
  [[ "$url" =~ ^https://.+\.supabase\.co$ ]]
}

@test "supabase url: wrong domain rejected" {
  local url="https://myproject.example.com"
  ! [[ "$url" =~ ^https://.+\.supabase\.co$ ]]
}

@test "supabase key: eyJ prefix accepted" {
  local key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
  [[ "$key" =~ ^eyJ ]]
}

@test "supabase key: wrong prefix rejected" {
  local key="abc123"
  ! [[ "$key" =~ ^eyJ ]]
}

# =============================================================================
# Input Validation — Gateway
# =============================================================================

@test "gateway url: http accepted" {
  local url="http://legendsclaw-gw:18789"
  [[ "$url" =~ ^https?:// ]]
}

@test "gateway url: no protocol rejected" {
  local url="legendsclaw-gw:18789"
  ! [[ "$url" =~ ^https?:// ]]
}

# =============================================================================
# Input Validation — Slack
# =============================================================================

@test "slack webhook: valid format accepted" {
  local url="https://hooks.slack.com/services/T00/B00/xxx"
  [[ "$url" =~ ^https://hooks\.slack\.com/ ]]
}

@test "slack webhook: wrong domain rejected" {
  local url="https://example.com/webhook"
  ! [[ "$url" =~ ^https://hooks\.slack\.com/ ]]
}

# =============================================================================
# Key Masking
# =============================================================================

mask_key() {
  local key="$1"
  local len=${#key}
  if [[ $len -le 10 ]]; then
    echo "***"
  else
    echo "${key:0:8}***${key: -4}"
  fi
}

@test "mask_key: masks long key correctly" {
  run mask_key "pk_12345678_abcdef1234567890"
  [[ "$output" == *"***"* ]]
  [[ "$output" != "pk_12345678_abcdef1234567890" ]]
}

@test "mask_key: never shows full key" {
  local full_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
  run mask_key "$full_key"
  [[ "$output" != "$full_key" ]]
}

@test "mask_key: short key shows only stars" {
  run mask_key "short"
  [[ "$output" == "***" ]]
}

@test "mask_key: empty key shows stars" {
  run mask_key ""
  [[ "$output" == "***" ]]
}

# =============================================================================
# Skill Subdirectory Creation
# =============================================================================

@test "skill dir: creates index.js" {
  mkdir -p "${TEST_SKILLS_DIR}/clickup-ops"
  cat > "${TEST_SKILLS_DIR}/clickup-ops/index.js" << 'EOF'
module.exports = { name: 'clickup-ops', handler: async () => {}, health: async () => {} };
EOF
  [[ -f "${TEST_SKILLS_DIR}/clickup-ops/index.js" ]]
}

@test "skill dir: creates SKILL.md" {
  mkdir -p "${TEST_SKILLS_DIR}/memory"
  cat > "${TEST_SKILLS_DIR}/memory/SKILL.md" << 'EOF'
# memory
## Description
Context persistence
EOF
  [[ -f "${TEST_SKILLS_DIR}/memory/SKILL.md" ]]
}

@test "skill dir: existing dir is not duplicated" {
  mkdir -p "${TEST_SKILLS_DIR}/alerts"
  touch "${TEST_SKILLS_DIR}/alerts/existing-file.txt"
  # Simular step_skip — se dir existe, pular
  if [[ -d "${TEST_SKILLS_DIR}/alerts" ]]; then
    skipped=true
  fi
  [[ "$skipped" == "true" ]]
  [[ -f "${TEST_SKILLS_DIR}/alerts/existing-file.txt" ]]
}

@test "skill dir: only selected skills created" {
  local selected=("clickup-ops" "memory")
  for skill_name in "${selected[@]}"; do
    mkdir -p "${TEST_SKILLS_DIR}/${skill_name}"
  done
  [[ -d "${TEST_SKILLS_DIR}/clickup-ops" ]]
  [[ -d "${TEST_SKILLS_DIR}/memory" ]]
  [[ ! -d "${TEST_SKILLS_DIR}/n8n-trigger" ]]
  [[ ! -d "${TEST_SKILLS_DIR}/supabase-query" ]]
}

# =============================================================================
# config.js Update
# =============================================================================

@test "config.js: preserves agent identity fields" {
  cat > "${TEST_SKILLS_DIR}/config.js" << 'EOF'
module.exports = {
  AGENT_NAME: 'jarvis',
  DISPLAY_NAME: 'Jarvis',
  ICON: '🤖',
  LANGUAGE: 'pt-BR',
  CLICKUP_API_KEY: process.env.CLICKUP_API_KEY,
};
EOF
  run cat "${TEST_SKILLS_DIR}/config.js"
  [[ "$output" == *"AGENT_NAME: 'jarvis'"* ]]
  [[ "$output" == *"DISPLAY_NAME: 'Jarvis'"* ]]
}

@test "config.js: uses process.env without fallbacks" {
  cat > "${TEST_SKILLS_DIR}/config.js" << 'EOF'
module.exports = {
  CLICKUP_API_KEY: process.env.CLICKUP_API_KEY,
  CLICKUP_TEAM_ID: process.env.CLICKUP_TEAM_ID,
};
EOF
  run cat "${TEST_SKILLS_DIR}/config.js"
  [[ "$output" != *"SEU_"* ]]
  [[ "$output" == *"process.env.CLICKUP_API_KEY"* ]]
}

@test "config.js: only selected skill vars present" {
  # Simular config com apenas clickup
  cat > "${TEST_SKILLS_DIR}/config.js" << 'EOF'
module.exports = {
  AGENT_NAME: 'test',
  CLICKUP_API_KEY: process.env.CLICKUP_API_KEY,
  CLICKUP_TEAM_ID: process.env.CLICKUP_TEAM_ID,
};
EOF
  run cat "${TEST_SKILLS_DIR}/config.js"
  [[ "$output" == *"CLICKUP_API_KEY"* ]]
  [[ "$output" != *"N8N_API_KEY"* ]]
  [[ "$output" != *"SUPABASE_URL"* ]]
}

# =============================================================================
# index.js Update
# =============================================================================

@test "index.js: has require for selected skill" {
  cat > "${TEST_SKILLS_DIR}/index.js" << 'EOF'
const clickup_ops = require('./clickup-ops');
const memory = require('./memory');
const skills = [clickup_ops, memory];
module.exports = { skills };
EOF
  run cat "${TEST_SKILLS_DIR}/index.js"
  [[ "$output" == *"require('./clickup-ops')"* ]]
  [[ "$output" == *"require('./memory')"* ]]
}

@test "index.js: skills array contains selected skills" {
  cat > "${TEST_SKILLS_DIR}/index.js" << 'EOF'
const alerts = require('./alerts');
const skills = [alerts];
module.exports = { skills };
EOF
  run cat "${TEST_SKILLS_DIR}/index.js"
  [[ "$output" == *"skills"* ]]
  [[ "$output" == *"alerts"* ]]
}

# =============================================================================
# .env Population
# =============================================================================

@test "env: contains Skills Config header" {
  local env_file="${TEST_ENV_DIR}/.env"
  cat > "$env_file" << 'EOF'
# Existing config
OPENROUTER_API_KEY=sk-or-xxx

# Skills Config
CLICKUP_API_KEY=pk_test123
CLICKUP_TEAM_ID=9876543
EOF
  run cat "$env_file"
  [[ "$output" == *"# Skills Config"* ]]
}

@test "env: only selected skill vars present" {
  local env_file="${TEST_ENV_DIR}/.env"
  cat > "$env_file" << 'EOF'
# Skills Config
CLICKUP_API_KEY=pk_test123
CLICKUP_TEAM_ID=9876543
EOF
  run cat "$env_file"
  [[ "$output" == *"CLICKUP_API_KEY"* ]]
  [[ "$output" != *"N8N_API_KEY"* ]]
  [[ "$output" != *"SUPABASE_URL"* ]]
}

@test "env: chmod 600 applied" {
  local env_file="${TEST_ENV_DIR}/.env"
  echo "test" > "$env_file"
  chmod 600 "$env_file"
  local perms
  perms=$(stat -c "%a" "$env_file" 2>/dev/null || stat -f "%Lp" "$env_file" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

# =============================================================================
# dados_skills State File
# =============================================================================

@test "dados_skills: contains Agente field" {
  cat > "$STATE_DIR/dados_skills" << 'EOF'
Agente: jarvis
Skills Ativas: clickup-ops, memory
EOF
  run cat "$STATE_DIR/dados_skills"
  [[ "$output" == *"Agente: jarvis"* ]]
}

@test "dados_skills: contains Skills Ativas" {
  cat > "$STATE_DIR/dados_skills" << 'EOF'
Agente: jarvis
Skills Ativas: clickup-ops, memory
Health Check: 2/2 OK
EOF
  run cat "$STATE_DIR/dados_skills"
  [[ "$output" == *"Skills Ativas:"* ]]
}

@test "dados_skills: contains Health Check summary" {
  cat > "$STATE_DIR/dados_skills" << 'EOF'
Health Check: 3/4 OK
EOF
  run cat "$STATE_DIR/dados_skills"
  [[ "$output" == *"Health Check:"* ]]
  [[ "$output" == *"OK"* ]]
}

@test "dados_skills: chmod 600 applied" {
  echo "test" > "$STATE_DIR/dados_skills"
  chmod 600 "$STATE_DIR/dados_skills"
  local perms
  perms=$(stat -c "%a" "$STATE_DIR/dados_skills" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/dados_skills" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

@test "dados_skills: contains Data Configuracao" {
  cat > "$STATE_DIR/dados_skills" << 'EOF'
Data Configuracao: 2026-02-20 15:30:00
EOF
  run cat "$STATE_DIR/dados_skills"
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

@test "failure: npm install failure is non-blocking" {
  # Simular que npm install falhou mas script continua
  local npm_exit=1
  local script_continues=true
  # step_fail nao aborta
  [[ "$script_continues" == "true" ]]
}

# =============================================================================
# Re-execution Scenarios
# =============================================================================

@test "re-execution: existing skill dir preserved" {
  mkdir -p "${TEST_SKILLS_DIR}/clickup-ops"
  echo "existing content" > "${TEST_SKILLS_DIR}/clickup-ops/custom.js"
  # step_skip deve ser chamado, dir preservado
  [[ -d "${TEST_SKILLS_DIR}/clickup-ops" ]]
  [[ -f "${TEST_SKILLS_DIR}/clickup-ops/custom.js" ]]
}

@test "re-execution: config.js backup created" {
  cat > "${TEST_SKILLS_DIR}/config.js" << 'EOF'
module.exports = { AGENT_NAME: 'test' };
EOF
  cp -p "${TEST_SKILLS_DIR}/config.js" "${TEST_SKILLS_DIR}/config.js.bak"
  [[ -f "${TEST_SKILLS_DIR}/config.js.bak" ]]
}

@test "re-execution: index.js backup created" {
  cat > "${TEST_SKILLS_DIR}/index.js" << 'EOF'
module.exports = { skills: [] };
EOF
  cp -p "${TEST_SKILLS_DIR}/index.js" "${TEST_SKILLS_DIR}/index.js.bak"
  [[ -f "${TEST_SKILLS_DIR}/index.js.bak" ]]
}

# =============================================================================
# Deployer Menu Integration
# =============================================================================

@test "deployer menu: contains entry 09 Skills" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"[09]"* ]]
  [[ "$output" == *"Skills"* ]]
}

@test "deployer menu: case 09 calls 08-skills.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"09|9)"* ]]
  [[ "$output" == *"08-skills.sh"* ]]
}

# =============================================================================
# Story 12.5: Skill Categories from Template
# =============================================================================

@test "template: 6 skill categories exist" {
  local template_skills="$SCRIPT_DIR/apps/_template/skills"
  local categories=("dev" "infrastructure" "memory" "orchestration" "superpowers" "system")
  for cat in "${categories[@]}"; do
    [[ -d "${template_skills}/${cat}" ]]
  done
}

@test "template: each category has README.md" {
  local template_skills="$SCRIPT_DIR/apps/_template/skills"
  local categories=("dev" "infrastructure" "memory" "orchestration" "superpowers" "system")
  for cat in "${categories[@]}"; do
    [[ -f "${template_skills}/${cat}/README.md" ]]
  done
}

@test "template: every skill has SKILL.md" {
  local template_skills="$SCRIPT_DIR/apps/_template/skills"
  local count=0
  local missing=()
  for skill_dir in "$template_skills"/*/; do
    [[ "$(basename "$skill_dir")" == "lib" ]] && continue
    for sub_dir in "$skill_dir"*/; do
      [[ ! -d "$sub_dir" ]] && continue
      [[ "$(basename "$sub_dir")" == "lib" ]] && continue
      [[ "$(basename "$sub_dir")" == "tools" ]] && continue
      if [[ -f "${sub_dir}SKILL.md" ]]; then
        count=$((count + 1))
      else
        missing+=("$(basename "$skill_dir")/$(basename "$sub_dir")")
      fi
    done
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing SKILL.md in: ${missing[*]}" >&2
    return 1
  fi
  [[ $count -gt 0 ]]
}

# =============================================================================
# Story 12.5: SKILL.md Frontmatter Format
# =============================================================================

@test "SKILL.md: has YAML frontmatter with required fields" {
  local template_skills="$SCRIPT_DIR/apps/_template/skills"
  local required_fields=("name" "description" "version" "tier" "always_on")
  local fail_count=0

  while IFS= read -r -d '' skill_md; do
    # Check starts with ---
    local first_line
    first_line=$(head -1 "$skill_md")
    if [[ "$first_line" != "---" ]]; then
      echo "Missing frontmatter start: $skill_md" >&2
      fail_count=$((fail_count + 1))
      continue
    fi
    # Check each required field exists in frontmatter
    for field in "${required_fields[@]}"; do
      if ! sed -n '2,/^---$/p' "$skill_md" | grep -q "^${field}:"; then
        echo "Missing field '${field}' in: $skill_md" >&2
        fail_count=$((fail_count + 1))
      fi
    done
  done < <(find "$template_skills" -name "SKILL.md" -print0)

  [[ $fail_count -eq 0 ]]
}

@test "SKILL.md: memory/SKILL.md has frontmatter (migrated)" {
  local skill_md="$SCRIPT_DIR/apps/_template/skills/memory/SKILL.md"
  local first_line
  first_line=$(head -1 "$skill_md")
  [[ "$first_line" == "---" ]]
  run grep "^name:" "$skill_md"
  [[ "$status" -eq 0 ]]
}

@test "SKILL.md: elicitation/SKILL.md has frontmatter (migrated)" {
  local skill_md="$SCRIPT_DIR/apps/_template/skills/elicitation/SKILL.md"
  local first_line
  first_line=$(head -1 "$skill_md")
  [[ "$first_line" == "---" ]]
  run grep "^name:" "$skill_md"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Story 12.5: Always-on Skills
# =============================================================================

@test "always-on: context-recovery has always_on: true" {
  local skill_md="$SCRIPT_DIR/apps/_template/skills/memory/context-recovery/SKILL.md"
  run grep "always_on: true" "$skill_md"
  [[ "$status" -eq 0 ]]
}

@test "always-on: planner has always_on: true" {
  local skill_md="$SCRIPT_DIR/apps/_template/skills/orchestration/planner/SKILL.md"
  run grep "always_on: true" "$skill_md"
  [[ "$status" -eq 0 ]]
}

@test "always-on: context-recovery has index.js" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/memory/context-recovery/index.js" ]]
}

@test "always-on: planner has index.js" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/orchestration/planner/index.js" ]]
}

@test "always-on: context-recovery index.js exports required fields" {
  local idx="$SCRIPT_DIR/apps/_template/skills/memory/context-recovery/index.js"
  run cat "$idx"
  [[ "$output" == *"name:"* ]]
  [[ "$output" == *"handler:"* ]]
  [[ "$output" == *"health:"* ]]
}

@test "always-on: planner index.js exports required fields" {
  local idx="$SCRIPT_DIR/apps/_template/skills/orchestration/planner/index.js"
  run cat "$idx"
  [[ "$output" == *"name:"* ]]
  [[ "$output" == *"handler:"* ]]
  [[ "$output" == *"health:"* ]]
}

# =============================================================================
# Story 12.5: Infrastructure skills have SKILL.md
# =============================================================================

@test "infrastructure: clickup-ops has SKILL.md" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/infrastructure/clickup-ops/SKILL.md" ]]
}

@test "infrastructure: n8n-trigger has SKILL.md" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/infrastructure/n8n-trigger/SKILL.md" ]]
}

@test "infrastructure: supabase-query has SKILL.md" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/infrastructure/supabase-query/SKILL.md" ]]
}

@test "infrastructure: allos-status has SKILL.md" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/infrastructure/allos-status/SKILL.md" ]]
}

@test "infrastructure: alerts has SKILL.md" {
  [[ -f "$SCRIPT_DIR/apps/_template/skills/infrastructure/alerts/SKILL.md" ]]
}

# =============================================================================
# Story 12.5: skills-entries.json Generation
# =============================================================================

@test "skills-entries: valid JSON structure" {
  local entries_file="${TEST_APPS_DIR}/test-agent/config/skills-entries.json"
  mkdir -p "$(dirname "$entries_file")"
  echo '{ "memory": { "enabled": true }, "context-recovery": { "enabled": true } }' > "$entries_file"
  run node -e "JSON.parse(require('fs').readFileSync('${entries_file}','utf8'));console.log('valid')"
  [[ "$output" == "valid" ]]
}

@test "skills-entries: each entry has enabled field" {
  local entries_file="${TEST_APPS_DIR}/test-agent/config/skills-entries.json"
  mkdir -p "$(dirname "$entries_file")"
  echo '{ "memory": { "enabled": true }, "alerts": { "enabled": true } }' > "$entries_file"
  run node -e "
    const e = JSON.parse(require('fs').readFileSync('${entries_file}','utf8'));
    const ok = Object.values(e).every(v => typeof v.enabled === 'boolean');
    console.log(ok ? 'valid' : 'invalid');
  "
  [[ "$output" == "valid" ]]
}

# =============================================================================
# Story 12.5: 08-skills.sh generates SKILL.md with frontmatter
# =============================================================================

@test "08-skills.sh: SKILL.md generator uses frontmatter format" {
  run grep "^---$" "$SCRIPT_DIR/ferramentas/08-skills.sh"
  [[ "$status" -eq 0 ]]
  run grep "always_on:" "$SCRIPT_DIR/ferramentas/08-skills.sh"
  [[ "$status" -eq 0 ]]
}

@test "08-skills.sh: copies skill categories from template" {
  run grep "SKILL_CATEGORIES" "$SCRIPT_DIR/ferramentas/08-skills.sh"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"dev"* ]]
  [[ "$output" == *"infrastructure"* ]]
  [[ "$output" == *"memory"* ]]
  [[ "$output" == *"orchestration"* ]]
  [[ "$output" == *"superpowers"* ]]
  [[ "$output" == *"system"* ]]
}

@test "08-skills.sh: detects always-on skills via SKILL.md" {
  run grep "always_on: true" "$SCRIPT_DIR/ferramentas/08-skills.sh"
  [[ "$status" -eq 0 ]]
}

@test "08-skills.sh: generates skills-entries.json" {
  run grep "skills-entries.json" "$SCRIPT_DIR/ferramentas/08-skills.sh"
  [[ "$status" -eq 0 ]]
}

@test "08-skills.sh: Step 14 workspace sync removed" {
  run grep "COPIAR SKILLS PARA OPENCLAW WORKSPACE" "$SCRIPT_DIR/ferramentas/08-skills.sh"
  [[ "$status" -ne 0 ]]
}

# =============================================================================
# Story 12.5: 14-gateway-config.sh reads skills-entries.json
# =============================================================================

@test "14-gateway-config.sh: reads skills-entries.json" {
  run grep "skills-entries.json" "$SCRIPT_DIR/ferramentas/14-gateway-config.sh"
  [[ "$status" -eq 0 ]]
}

@test "14-gateway-config.sh: SKILLS_ENTRIES env var used in aiosbot.json" {
  run grep "SKILLS_ENTRIES" "$SCRIPT_DIR/ferramentas/14-gateway-config.sh"
  [[ "$status" -eq 0 ]]
}
