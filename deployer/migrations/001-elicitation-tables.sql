-- =============================================================================
-- Legendsclaw — Migration 001: Elicitation Tables
-- Story 4.3: Skill Elicitation — Templates e Schema Supabase
-- Transacional, Idempotente (CREATE TABLE IF NOT EXISTS)
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. TRIGGER FUNCTION (shared by all 3 tables)
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column() IS 'Auto-update updated_at on row modification';

-- =============================================================================
-- 2. TABLE: elicitation_templates
-- Stores interview templates with sections and questions (JSONB)
-- =============================================================================
CREATE TABLE IF NOT EXISTS elicitation_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  sections JSONB NOT NULL,  -- [{name, questions: [{text, type, required, hints}]}]
  version INTEGER NOT NULL DEFAULT 1,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE elicitation_templates IS 'Interview templates with structured sections and questions';
COMMENT ON COLUMN elicitation_templates.id IS 'UUID primary key';
COMMENT ON COLUMN elicitation_templates.name IS 'Unique template identifier (e.g. onboarding-founder)';
COMMENT ON COLUMN elicitation_templates.description IS 'Human-readable template description';
COMMENT ON COLUMN elicitation_templates.sections IS 'JSONB array: [{name, questions: [{text, type, required, hints}]}]';
COMMENT ON COLUMN elicitation_templates.version IS 'Template version number';
COMMENT ON COLUMN elicitation_templates.active IS 'Whether template is available for new sessions';
COMMENT ON COLUMN elicitation_templates.created_at IS 'Row creation timestamp';
COMMENT ON COLUMN elicitation_templates.updated_at IS 'Last modification timestamp (auto-updated via trigger)';

CREATE TRIGGER trg_elicitation_templates_updated_at
  BEFORE UPDATE ON elicitation_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 3. TABLE: elicitation_sessions
-- Tracks active interview sessions with progress state
-- =============================================================================
CREATE TABLE IF NOT EXISTS elicitation_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES elicitation_templates(id),
  status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'paused', 'completed')),
  current_section INTEGER NOT NULL DEFAULT 0,
  current_question INTEGER NOT NULL DEFAULT 0,
  responses JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE elicitation_sessions IS 'Active interview sessions tracking progress and responses';
COMMENT ON COLUMN elicitation_sessions.id IS 'UUID primary key';
COMMENT ON COLUMN elicitation_sessions.template_id IS 'FK to elicitation_templates';
COMMENT ON COLUMN elicitation_sessions.status IS 'Session state: in_progress, paused, completed';
COMMENT ON COLUMN elicitation_sessions.current_section IS '0-based index into template sections array';
COMMENT ON COLUMN elicitation_sessions.current_question IS '0-based index into current section questions array';
COMMENT ON COLUMN elicitation_sessions.responses IS 'JSONB map of section_idx -> question_idx -> {value, raw_message, extracted_at}';
COMMENT ON COLUMN elicitation_sessions.created_at IS 'Session start timestamp';
COMMENT ON COLUMN elicitation_sessions.updated_at IS 'Last activity timestamp (auto-updated via trigger)';

CREATE TRIGGER trg_elicitation_sessions_updated_at
  BEFORE UPDATE ON elicitation_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 4. TABLE: elicitation_results
-- Exported structured results from completed (or partial) sessions
-- =============================================================================
CREATE TABLE IF NOT EXISTS elicitation_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES elicitation_sessions(id),
  template_id UUID NOT NULL REFERENCES elicitation_templates(id),
  data JSONB NOT NULL,
  exported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE elicitation_results IS 'Exported structured interview results';
COMMENT ON COLUMN elicitation_results.id IS 'UUID primary key';
COMMENT ON COLUMN elicitation_results.session_id IS 'FK to elicitation_sessions';
COMMENT ON COLUMN elicitation_results.template_id IS 'FK to elicitation_templates';
COMMENT ON COLUMN elicitation_results.data IS 'JSONB structured export data';
COMMENT ON COLUMN elicitation_results.exported_at IS 'When results were exported';
COMMENT ON COLUMN elicitation_results.created_at IS 'Row creation timestamp';
COMMENT ON COLUMN elicitation_results.updated_at IS 'Last modification timestamp (auto-updated via trigger)';

CREATE TRIGGER trg_elicitation_results_updated_at
  BEFORE UPDATE ON elicitation_results
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 5. INDEXES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_sessions_template_id ON elicitation_sessions(template_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON elicitation_sessions(status);
CREATE INDEX IF NOT EXISTS idx_results_session_id ON elicitation_results(session_id);
CREATE INDEX IF NOT EXISTS idx_results_template_id ON elicitation_results(template_id);

-- =============================================================================
-- 6. ROW LEVEL SECURITY
-- NOTE: service_role bypasses RLS by default in Supabase.
-- RLS is enabled as defense-in-depth for future anon/authenticated access.
-- =============================================================================
ALTER TABLE elicitation_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE elicitation_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE elicitation_results ENABLE ROW LEVEL SECURITY;

-- Permissive policy for service_role (documentation — service_role already bypasses RLS)
-- These policies exist for when non-service-role access is added in the future.
CREATE POLICY IF NOT EXISTS "service_role_all_templates" ON elicitation_templates
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "service_role_all_sessions" ON elicitation_sessions
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "service_role_all_results" ON elicitation_results
  FOR ALL USING (true) WITH CHECK (true);

-- =============================================================================
-- 7. POST-MIGRATION VERIFICATION
-- =============================================================================
DO $$
BEGIN
  ASSERT (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('elicitation_templates', 'elicitation_sessions', 'elicitation_results')
  ) = 3, 'Migration verification failed: expected 3 elicitation tables';
END;
$$;

COMMIT;
