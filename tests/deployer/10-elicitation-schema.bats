#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/10-elicitation-schema.sh
# Story 4.3: Skill Elicitation — Templates e Schema Supabase
# Framework: bats-core
# Execucao: npx bats tests/deployer/10-elicitation-schema.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  # Source libs com readonly removido
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true)
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/hints.sh" 2>/dev/null || true)

  # Mock STATE_DIR
  export STATE_DIR="$(mktemp -d)"
  mkdir -p "$STATE_DIR"

  # Mock LOG_DIR
  export LOG_DIR="$(mktemp -d)"

  # Paths
  export MIGRATIONS_DIR="${SCRIPT_DIR}/migrations"
  export SEEDS_DIR="${SCRIPT_DIR}/seeds"
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" 2>/dev/null || true
}

# =============================================================================
# Migration SQL — 3 CREATE TABLE (Task 5.2)
# =============================================================================

@test "migration: contains CREATE TABLE elicitation_templates" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"CREATE TABLE IF NOT EXISTS elicitation_templates"* ]]
}

@test "migration: contains CREATE TABLE elicitation_sessions" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"CREATE TABLE IF NOT EXISTS elicitation_sessions"* ]]
}

@test "migration: contains CREATE TABLE elicitation_results" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"CREATE TABLE IF NOT EXISTS elicitation_results"* ]]
}

@test "migration: all 3 tables present" {
  local count
  count=$(grep -c "CREATE TABLE IF NOT EXISTS elicitation_" "$MIGRATIONS_DIR/001-elicitation-tables.sql")
  [[ "$count" -eq 3 ]]
}

# =============================================================================
# Migration SQL — Indexes (Task 5.3)
# =============================================================================

@test "migration: contains idx_sessions_template_id" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"idx_sessions_template_id"* ]]
}

@test "migration: contains idx_sessions_status" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"idx_sessions_status"* ]]
}

@test "migration: contains idx_results_session_id" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"idx_results_session_id"* ]]
}

@test "migration: contains idx_results_template_id" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"idx_results_template_id"* ]]
}

# =============================================================================
# Migration SQL — Triggers (Task 5.4)
# =============================================================================

@test "migration: contains update_updated_at_column trigger function" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"update_updated_at_column"* ]]
}

@test "migration: has trigger on elicitation_templates" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"trg_elicitation_templates_updated_at"* ]]
}

@test "migration: has trigger on elicitation_sessions" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"trg_elicitation_sessions_updated_at"* ]]
}

@test "migration: has trigger on elicitation_results" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"trg_elicitation_results_updated_at"* ]]
}

# =============================================================================
# Migration SQL — RLS (Task 5.5)
# =============================================================================

@test "migration: enables RLS on elicitation_templates" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"ALTER TABLE elicitation_templates ENABLE ROW LEVEL SECURITY"* ]]
}

@test "migration: enables RLS on elicitation_sessions" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"ALTER TABLE elicitation_sessions ENABLE ROW LEVEL SECURITY"* ]]
}

@test "migration: enables RLS on elicitation_results" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"ALTER TABLE elicitation_results ENABLE ROW LEVEL SECURITY"* ]]
}

@test "migration: contains RLS policies" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"CREATE POLICY"* ]]
}

# =============================================================================
# Migration SQL — Transactional and Idempotent
# =============================================================================

@test "migration: is transactional (BEGIN/COMMIT)" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"BEGIN;"* ]]
  [[ "$output" == *"COMMIT;"* ]]
}

@test "migration: contains post-migration verification (ASSERT)" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"ASSERT"* ]]
}

@test "migration: contains COMMENT ON TABLE" {
  local count
  count=$(grep -c "COMMENT ON TABLE" "$MIGRATIONS_DIR/001-elicitation-tables.sql")
  [[ "$count" -ge 3 ]]
}

@test "migration: contains COMMENT ON COLUMN" {
  local count
  count=$(grep -c "COMMENT ON COLUMN" "$MIGRATIONS_DIR/001-elicitation-tables.sql")
  [[ "$count" -ge 10 ]]
}

# =============================================================================
# Migration SQL — Column types
# =============================================================================

@test "migration: templates has UUID primary key" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"id UUID PRIMARY KEY DEFAULT gen_random_uuid()"* ]]
}

@test "migration: templates has sections JSONB" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"sections JSONB NOT NULL"* ]]
}

@test "migration: sessions has status CHECK constraint" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"CHECK (status IN ("* ]]
}

@test "migration: sessions references templates FK" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"REFERENCES elicitation_templates(id)"* ]]
}

@test "migration: results references sessions FK" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"REFERENCES elicitation_sessions(id)"* ]]
}

# =============================================================================
# Seed SQL — INSERT with ON CONFLICT (Task 5.6)
# =============================================================================

@test "seed: contains INSERT INTO elicitation_templates" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"INSERT INTO elicitation_templates"* ]]
}

@test "seed: uses ON CONFLICT for idempotency" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"ON CONFLICT"* ]]
  [[ "$output" == *"DO UPDATE SET"* ]]
}

@test "seed: uses fixed UUID" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"a1b2c3d4-e5f6-7890-abcd-ef1234567890"* ]]
}

# =============================================================================
# Seed SQL — 2 Sections (Task 5.7)
# =============================================================================

@test "seed: contains Founder & Story section" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"Founder & Story"* ]]
}

@test "seed: contains Empresa & Tecnico section" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"Empresa & Tecnico"* ]]
}

@test "seed: has exactly 2 sections" {
  local count
  count=$(grep -c '"name":' "$SEEDS_DIR/001-onboarding-founder.sql")
  [[ "$count" -eq 2 ]]
}

# =============================================================================
# Seed SQL — Question Fields (Task 5.8)
# =============================================================================

@test "seed: questions have text field" {
  local count
  count=$(grep -c '"text":' "$SEEDS_DIR/001-onboarding-founder.sql")
  [[ "$count" -ge 5 ]]
}

@test "seed: questions have type field" {
  local count
  count=$(grep -c '"type":' "$SEEDS_DIR/001-onboarding-founder.sql")
  [[ "$count" -ge 5 ]]
}

@test "seed: questions have required field" {
  local count
  count=$(grep -c '"required":' "$SEEDS_DIR/001-onboarding-founder.sql")
  [[ "$count" -ge 5 ]]
}

@test "seed: questions have hints field" {
  local count
  count=$(grep -c '"hints":' "$SEEDS_DIR/001-onboarding-founder.sql")
  [[ "$count" -ge 5 ]]
}

@test "seed: contains text type questions" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *'"type": "text"'* ]]
}

@test "seed: contains select type questions" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *'"type": "select"'* ]]
}

# =============================================================================
# Seed SQL — Transactional and Verification
# =============================================================================

@test "seed: is transactional (BEGIN/COMMIT)" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"BEGIN;"* ]]
  [[ "$output" == *"COMMIT;"* ]]
}

@test "seed: contains post-seed verification (ASSERT)" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"ASSERT"* ]]
}

@test "seed: template name is onboarding-founder" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"onboarding-founder"* ]]
}

@test "seed: uses JSONB cast" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"::JSONB"* ]]
}

# =============================================================================
# dados_elicitation_schema State File (Task 5.9)
# =============================================================================

@test "state: dados_elicitation_schema saved with Migration field" {
  cat > "$STATE_DIR/dados_elicitation_schema" << 'EOF'
Migration: 001-elicitation-tables.sql
Tables: elicitation_templates, elicitation_sessions, elicitation_results
Seed: onboarding-founder
Migration File: deployer/migrations/001-elicitation-tables.sql
Seed File: deployer/seeds/001-onboarding-founder.sql
Supabase URL: https://example.supabase.co
Verificacao: OK
Data Configuracao: 2026-02-20 15:30:00
EOF
  run cat "$STATE_DIR/dados_elicitation_schema"
  [[ "$output" == *"Migration: 001-elicitation-tables.sql"* ]]
}

@test "state: dados_elicitation_schema has Tables field" {
  cat > "$STATE_DIR/dados_elicitation_schema" << 'EOF'
Tables: elicitation_templates, elicitation_sessions, elicitation_results
EOF
  run cat "$STATE_DIR/dados_elicitation_schema"
  [[ "$output" == *"elicitation_templates"* ]]
  [[ "$output" == *"elicitation_sessions"* ]]
  [[ "$output" == *"elicitation_results"* ]]
}

@test "state: dados_elicitation_schema has Seed field" {
  cat > "$STATE_DIR/dados_elicitation_schema" << 'EOF'
Seed: onboarding-founder
EOF
  run cat "$STATE_DIR/dados_elicitation_schema"
  [[ "$output" == *"Seed: onboarding-founder"* ]]
}

@test "state: dados_elicitation_schema has Verificacao field" {
  cat > "$STATE_DIR/dados_elicitation_schema" << 'EOF'
Verificacao: OK
EOF
  run cat "$STATE_DIR/dados_elicitation_schema"
  [[ "$output" == *"Verificacao:"* ]]
}

@test "state: dados_elicitation_schema chmod 600" {
  echo "test" > "$STATE_DIR/dados_elicitation_schema"
  chmod 600 "$STATE_DIR/dados_elicitation_schema"
  local perms
  perms=$(stat -c "%a" "$STATE_DIR/dados_elicitation_schema" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/dados_elicitation_schema" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

@test "state: dados_elicitation_schema has Data Configuracao" {
  cat > "$STATE_DIR/dados_elicitation_schema" << 'EOF'
Data Configuracao: 2026-02-20 15:30:00
EOF
  run cat "$STATE_DIR/dados_elicitation_schema"
  [[ "$output" == *"Data Configuracao:"* ]]
}

@test "state: dados_elicitation_schema has Supabase URL" {
  cat > "$STATE_DIR/dados_elicitation_schema" << 'EOF'
Supabase URL: https://example.supabase.co
EOF
  run cat "$STATE_DIR/dados_elicitation_schema"
  [[ "$output" == *"Supabase URL:"* ]]
}

# =============================================================================
# hint_elicitation_schema (Task 5.10)
# =============================================================================

@test "hint: hint_elicitation_schema displays header" {
  run hint_elicitation_schema
  [[ "$output" == *"ELICITATION SCHEMA"* ]]
}

@test "hint: hint_elicitation_schema mentions SQL Editor" {
  run hint_elicitation_schema
  [[ "$output" == *"SQL Editor"* ]]
}

@test "hint: hint_elicitation_schema mentions Table Editor" {
  run hint_elicitation_schema
  [[ "$output" == *"Table Editor"* ]]
}

@test "hint: hint_elicitation_schema mentions migration file" {
  run hint_elicitation_schema
  [[ "$output" == *"001-elicitation-tables.sql"* ]]
}

@test "hint: hint_elicitation_schema mentions seed file" {
  run hint_elicitation_schema
  [[ "$output" == *"001-onboarding-founder.sql"* ]]
}

@test "hint: hint_elicitation_schema mentions RLS" {
  run hint_elicitation_schema
  [[ "$output" == *"RLS"* ]]
}

@test "hint: hint_elicitation_schema shows REST verification" {
  run hint_elicitation_schema
  [[ "$output" == *"curl"* ]]
}

# =============================================================================
# Failure Scenarios (Task 5.11)
# =============================================================================

@test "failure: dados_whitelabel ausente detected" {
  rm -f "$STATE_DIR/dados_whitelabel" 2>/dev/null || true
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
}

@test "failure: empty SUPABASE_URL detected" {
  local url=""
  [[ -z "$url" ]]
}

@test "failure: script has set -euo pipefail" {
  run head -3 "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"set -euo pipefail"* ]]
}

# =============================================================================
# Re-execution / Idempotency (Task 5.12)
# =============================================================================

@test "idempotent: migration uses IF NOT EXISTS" {
  local count
  count=$(grep -c "IF NOT EXISTS" "$MIGRATIONS_DIR/001-elicitation-tables.sql")
  [[ "$count" -ge 3 ]]
}

@test "idempotent: migration uses CREATE OR REPLACE for trigger function" {
  run cat "$MIGRATIONS_DIR/001-elicitation-tables.sql"
  [[ "$output" == *"CREATE OR REPLACE FUNCTION"* ]]
}

@test "idempotent: seed uses ON CONFLICT" {
  run cat "$SEEDS_DIR/001-onboarding-founder.sql"
  [[ "$output" == *"ON CONFLICT"* ]]
}

@test "idempotent: indexes use IF NOT EXISTS" {
  local count
  count=$(grep -c "CREATE INDEX IF NOT EXISTS" "$MIGRATIONS_DIR/001-elicitation-tables.sql")
  [[ "$count" -ge 4 ]]
}

@test "idempotent: policies use IF NOT EXISTS" {
  local count
  count=$(grep -c "CREATE POLICY IF NOT EXISTS" "$MIGRATIONS_DIR/001-elicitation-tables.sql")
  [[ "$count" -ge 3 ]]
}

# =============================================================================
# Deployer Menu Integration (Task 4.13)
# =============================================================================

@test "deployer menu: contains entry [11] Elicitation Schema" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"[11]"* ]]
  [[ "$output" == *"Elicitation Schema"* ]]
}

@test "deployer menu: case 11 calls 10-elicitation-schema.sh" {
  run cat "$SCRIPT_DIR/deployer.sh"
  [[ "$output" == *"11)"* ]]
  [[ "$output" == *"10-elicitation-schema.sh"* ]]
}

# =============================================================================
# Ferramenta Script Structure
# =============================================================================

@test "script: 10-elicitation-schema.sh exists and is executable" {
  [[ -f "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh" ]]
  [[ -x "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh" ]]
}

@test "script: sources all required libs" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"ui.sh"* ]]
  [[ "$output" == *"logger.sh"* ]]
  [[ "$output" == *"common.sh"* ]]
  [[ "$output" == *"hints.sh"* ]]
}

@test "script: calls log_init with correct name" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *'log_init "elicitation-schema"'* ]]
}

@test "script: calls step_init" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"step_init"* ]]
}

@test "script: calls log_finish" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"log_finish"* ]]
}

@test "script: calls resumo_final" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"resumo_final"* ]]
}

@test "script: calls conferindo_as_info" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"conferindo_as_info"* ]]
}

@test "script: calls hint_elicitation_schema" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"hint_elicitation_schema"* ]]
}

@test "script: has mask_key function" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"mask_key()"* ]]
}

@test "script: saves state with chmod 600" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"chmod 600"* ]]
  [[ "$output" == *"dados_elicitation_schema"* ]]
}

@test "script: checks for dados_whitelabel dependency" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"dados_whitelabel"* ]]
}

@test "script: provides SUPABASE_URL hint" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"supabase.com/dashboard"* ]]
  [[ "$output" == *"Project URL"* ]]
}

@test "script: provides SUPABASE_SERVICE_ROLE_KEY hint" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"service_role"* ]]
}

@test "script: verifies via REST API (curl)" {
  run cat "$SCRIPT_DIR/ferramentas/10-elicitation-schema.sh"
  [[ "$output" == *"curl"* ]]
  [[ "$output" == *"elicitation_templates"* ]]
}
