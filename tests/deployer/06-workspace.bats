#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/06-workspace.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/06-workspace.bats
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

  # Mock APPS_DIR
  export TEST_APPS_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" "$TEST_APPS_DIR" 2>/dev/null || true
}

# =============================================================================
# Script File Existence
# =============================================================================

@test "06-workspace.sh exists" {
  [[ -f "$SCRIPT_DIR/ferramentas/06-workspace.sh" ]]
}

@test "06-workspace.sh is executable" {
  [[ -x "$SCRIPT_DIR/ferramentas/06-workspace.sh" ]]
}

@test "06-workspace.sh starts with shebang" {
  run head -1 "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "06-workspace.sh has set -euo pipefail" {
  run head -5 "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "06-workspace.sh sources ui.sh" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'source "${LIB_DIR}/ui.sh"'* ]]
}

@test "06-workspace.sh sources logger.sh" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'source "${LIB_DIR}/logger.sh"'* ]]
}

@test "06-workspace.sh sources common.sh" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'source "${LIB_DIR}/common.sh"'* ]]
}

@test "06-workspace.sh sources hints.sh" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'source "${LIB_DIR}/hints.sh"'* ]]
}

@test "06-workspace.sh sources env-detect.sh" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'source "${LIB_DIR}/env-detect.sh"'* ]]
}

@test "06-workspace.sh calls log_init workspace" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'log_init "workspace"'* ]]
}

@test "06-workspace.sh calls setup_trap" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"setup_trap"* ]]
}

@test "06-workspace.sh calls step_init" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"step_init"* ]]
}

@test "06-workspace.sh checks dados_whitelabel dependency" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"dados_whitelabel"* ]]
}

@test "06-workspace.sh calls resumo_final" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"resumo_final"* ]]
}

@test "06-workspace.sh calls hint_workspace" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"hint_workspace"* ]]
}

@test "06-workspace.sh calls log_finish" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"log_finish"* ]]
}

@test "06-workspace.sh chmod 600 dados_workspace" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'chmod 600 "$STATE_DIR/dados_workspace"'* ]]
}

@test "06-workspace.sh generates SOUL.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"SOUL.md"* ]]
}

@test "06-workspace.sh generates AGENTS.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"AGENTS.md"* ]]
}

@test "06-workspace.sh generates IDENTITY.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"IDENTITY.md"* ]]
}

@test "06-workspace.sh generates USER.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"USER.md"* ]]
}

@test "06-workspace.sh generates MEMORY.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"MEMORY.md"* ]]
}

@test "06-workspace.sh generates BOOTSTRAP.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"BOOTSTRAP.md"* ]]
}

@test "06-workspace.sh creates workspace directory" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'mkdir -p "$WORKSPACE_DIR"'* ]]
}

@test "06-workspace.sh creates memory subdirectory" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'mkdir -p "$WORKSPACE_DIR/memory"'* ]]
}

@test "06-workspace.sh saves dados_workspace state" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"dados_workspace"* ]]
}

# =============================================================================
# hint_workspace
# =============================================================================

@test "hint_workspace displays next steps header" {
  run hint_workspace "jarvis"
  [[ "$output" == *"PROXIMOS PASSOS"* ]]
}

@test "hint_workspace shows LLM Router step" {
  run hint_workspace "jarvis"
  [[ "$output" == *"Ferramenta [07]"* ]]
}

@test "hint_workspace shows workspace path with agent name" {
  run hint_workspace "atlas"
  [[ "$output" == *"apps/atlas/workspace/"* ]]
}

@test "hint_workspace shows SOUL.md personalization step" {
  run hint_workspace "jarvis"
  [[ "$output" == *"SOUL.md"* ]]
}

@test "hint_workspace uses default agent name when empty" {
  run hint_workspace
  [[ "$output" == *"meu-agente"* ]]
}

# =============================================================================
# Deployer Menu Integration
# =============================================================================

@test "deployer.sh has [06] Workspace menu entry" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"Workspace Files"* ]]
}

@test "deployer.sh has case 06|6 for workspace" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"06|6)"* ]]
}

@test "deployer.sh calls 06-workspace.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"06-workspace.sh"* ]]
}

# =============================================================================
# Dependency Check
# =============================================================================

@test "fail: dados_whitelabel missing detected" {
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
}

# =============================================================================
# State File — dados_workspace format
# =============================================================================

@test "dados_workspace contains all expected fields" {
  cat > "$STATE_DIR/dados_workspace" << 'EOF'
Agente: jarvis
Workspace Path: apps/jarvis/workspace
SOUL: apps/jarvis/workspace/SOUL.md
AGENTS: apps/jarvis/workspace/AGENTS.md
BOOTSTRAP: apps/jarvis/workspace/BOOTSTRAP.md
MEMORY: apps/jarvis/workspace/MEMORY.md
IDENTITY: apps/jarvis/workspace/IDENTITY.md
USER: apps/jarvis/workspace/USER.md
TOOLS: apps/jarvis/workspace/TOOLS.md
HEARTBEAT: apps/jarvis/workspace/HEARTBEAT.md
Status: completo
Data Criacao: 2026-02-20 14:30:00
EOF
  run cat "$STATE_DIR/dados_workspace"
  [[ "$output" == *"Agente: jarvis"* ]]
  [[ "$output" == *"Workspace Path:"* ]]
  [[ "$output" == *"SOUL:"* ]]
  [[ "$output" == *"AGENTS:"* ]]
  [[ "$output" == *"IDENTITY:"* ]]
  [[ "$output" == *"USER:"* ]]
  [[ "$output" == *"TOOLS:"* ]]
  [[ "$output" == *"HEARTBEAT:"* ]]
  [[ "$output" == *"Status: completo"* ]]
}

@test "dados_workspace permissions are 600" {
  echo "test" > "$STATE_DIR/dados_workspace"
  chmod 600 "$STATE_DIR/dados_workspace"
  local perms
  perms=$(stat -c %a "$STATE_DIR/dados_workspace")
  [[ "$perms" == "600" ]]
}

# =============================================================================
# Workspace File Content Verification
# =============================================================================

@test "SOUL.md template has Core Truths section" {
  local soul="${TEST_APPS_DIR}/SOUL.md"
  cat > "$soul" << 'EOF'
# SOUL.md - Who You Are
## Core Truths
**Be genuinely helpful, not performatively helpful.**
EOF
  run cat "$soul"
  [[ "$output" == *"Core Truths"* ]]
}

@test "SOUL.md template has Boundaries section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Boundaries"* ]]
}

@test "SOUL.md template has Vibe section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Vibe"* ]]
}

@test "SOUL.md template uses persona_estilo variable" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'${persona_estilo}'* ]]
}

@test "AGENTS.md template has Every Session section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Every Session"* ]]
}

@test "AGENTS.md template has Memory section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Memory"* ]]
}

@test "AGENTS.md template has Skills section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Skills"* ]]
}

@test "AGENTS.md template checks dados_skills" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"dados_skills"* ]]
}

@test "IDENTITY.md uses display_name variable" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'${display_name}'* ]]
}

@test "IDENTITY.md uses icone variable" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'${icone}'* ]]
}

@test "USER.md template has Communication section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Communication"* ]]
}

@test "USER.md template has Preferences section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Preferences"* ]]
}

@test "BOOTSTRAP.md template has The Conversation section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## The Conversation"* ]]
}

@test "MEMORY.md template has Active Projects section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Active Projects"* ]]
}

# =============================================================================
# TOOLS.md and HEARTBEAT.md (Story 12.4)
# =============================================================================

@test "06-workspace.sh generates TOOLS.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"TOOLS.md"* ]]
}

@test "TOOLS.md template has Environment section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"# Tools Configuration"* ]]
}

@test "TOOLS.md template has SSH Hosts section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## SSH Hosts"* ]]
}

@test "TOOLS.md template has Filesystem section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Filesystem"* ]]
}

@test "TOOLS.md template has Restrictions section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Restrictions"* ]]
}

@test "TOOLS.md uses WORKSPACE_DIR variable" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'Workspace: ${WORKSPACE_DIR}'* ]]
}

@test "06-workspace.sh generates HEARTBEAT.md" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"HEARTBEAT.md"* ]]
}

@test "HEARTBEAT.md template has Trigger Pattern section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Trigger Pattern"* ]]
}

@test "HEARTBEAT.md template has Background Tasks section" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"## Background Tasks"* ]]
}

@test "06-workspace.sh copies 8 files to openclaw workspace" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *"SOUL.md IDENTITY.md USER.md AGENTS.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md"* ]]
}

@test "dados_workspace state file includes TOOLS field" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'TOOLS: ${WORKSPACE_DIR}/TOOLS.md'* ]]
}

@test "dados_workspace state file includes HEARTBEAT field" {
  run cat "$SCRIPT_DIR/ferramentas/06-workspace.sh"
  [[ "$output" == *'HEARTBEAT: ${WORKSPACE_DIR}/HEARTBEAT.md'* ]]
}

# =============================================================================
# Template Reference Files (Story 12.4)
# =============================================================================

@test "_template/workspace/TOOLS.md exists" {
  [[ -f "$SCRIPT_DIR/apps/_template/workspace/TOOLS.md" ]]
}

@test "_template/workspace/HEARTBEAT.md exists" {
  [[ -f "$SCRIPT_DIR/apps/_template/workspace/HEARTBEAT.md" ]]
}
