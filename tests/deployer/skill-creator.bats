#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/apps/_template/skills/system/skill-creator
# Framework: bats-core
# Execucao: npx bats tests/deployer/skill-creator.bats
# Nota: Testa o modulo Node.js create-skill.js via node -e
# =============================================================================

SKILL_CREATOR_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer/apps/_template/skills/system/skill-creator" && pwd)"

setup() {
  export TEST_DIR=$(mktemp -d)
  # Create fake skills root mimicking real structure
  export FAKE_SKILLS_ROOT="$TEST_DIR/skills"
  mkdir -p "$FAKE_SKILLS_ROOT/system/skill-creator/tools"
  cp "$SKILL_CREATOR_DIR/tools/create-skill.js" "$FAKE_SKILLS_ROOT/system/skill-creator/tools/"
  # Pre-create category dirs
  mkdir -p "$FAKE_SKILLS_ROOT/dev"
  mkdir -p "$FAKE_SKILLS_ROOT/infrastructure"
  mkdir -p "$FAKE_SKILLS_ROOT/memory"
  mkdir -p "$FAKE_SKILLS_ROOT/orchestration"
  mkdir -p "$FAKE_SKILLS_ROOT/superpowers"
  mkdir -p "$FAKE_SKILLS_ROOT/system"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# AC1: Skill scaffolda nova skill com SKILL.md + index.js + tools/
# -----------------------------------------------------------------------------
@test "create_skill generates SKILL.md + index.js + tools/.gitkeep" {
  run node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'hello-world', category: 'dev', description: 'A test skill' })
      .then(r => {
        console.log(JSON.stringify(r));
        process.exit(r.success ? 0 : 1);
      })
      .catch(e => { console.error(e.message); process.exit(1); });
  "
  [ "$status" -eq 0 ]

  # Verify files exist
  [ -f "$FAKE_SKILLS_ROOT/dev/hello-world/SKILL.md" ]
  [ -f "$FAKE_SKILLS_ROOT/dev/hello-world/index.js" ]
  [ -f "$FAKE_SKILLS_ROOT/dev/hello-world/tools/.gitkeep" ]
}

# -----------------------------------------------------------------------------
# AC4: SKILL.md has correct YAML frontmatter
# -----------------------------------------------------------------------------
@test "generated SKILL.md has YAML frontmatter with name, description, version, tier, always_on" {
  node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'fmt-test', category: 'memory', description: 'Format test', tier: 'budget', always_on: true })
      .then(() => process.exit(0))
      .catch(e => { console.error(e.message); process.exit(1); });
  "

  local skillmd="$FAKE_SKILLS_ROOT/memory/fmt-test/SKILL.md"
  [ -f "$skillmd" ]

  # Check frontmatter fields
  run head -8 "$skillmd"
  [[ "$output" == *"---"* ]]
  [[ "$output" == *"name: fmt-test"* ]]
  [[ "$output" == *"description: Format test"* ]]
  [[ "$output" == *"version: 1.0.0"* ]]
  [[ "$output" == *"tier: budget"* ]]
  [[ "$output" == *"always_on: true"* ]]
}

# -----------------------------------------------------------------------------
# AC5: Generated index.js exports handler + health
# -----------------------------------------------------------------------------
@test "generated index.js exports handler and health functions" {
  node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'exp-test', category: 'dev', description: 'Export test' })
      .then(() => process.exit(0))
      .catch(e => { console.error(e.message); process.exit(1); });
  "

  run node -e "
    const m = require('$FAKE_SKILLS_ROOT/dev/exp-test');
    const ok = typeof m.handler === 'function' && typeof m.health === 'function' && m.name === 'exp-test';
    console.log(ok ? 'PASS' : 'FAIL');
    process.exit(ok ? 0 : 1);
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

# -----------------------------------------------------------------------------
# Validation: reject invalid skill names
# -----------------------------------------------------------------------------
@test "rejects invalid skill names (uppercase, spaces, path traversal)" {
  local bad_names=("Test-Bad" "hello world" "../escape" "/absolute" "123start" "with spaces")

  for name in "${bad_names[@]}"; do
    run node -e "
      const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
      cs({ skill_name: '$name', category: 'dev', description: 'bad' })
        .then(() => process.exit(1))
        .catch(() => process.exit(0));
    "
    [ "$status" -eq 0 ]
  done
}

# -----------------------------------------------------------------------------
# Validation: reject duplicate skill (directory already exists)
# -----------------------------------------------------------------------------
@test "rejects duplicate skill creation" {
  # Create first
  node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'dup-test', category: 'dev', description: 'first' })
      .then(() => process.exit(0))
      .catch(e => { console.error(e.message); process.exit(1); });
  "

  # Attempt duplicate
  run node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'dup-test', category: 'dev', description: 'second' })
      .then(() => { console.log('SHOULD_HAVE_FAILED'); process.exit(1); })
      .catch(e => { console.log(e.message); process.exit(0); });
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
}

# -----------------------------------------------------------------------------
# Validation: reject invalid category
# -----------------------------------------------------------------------------
@test "rejects invalid category" {
  run node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'cat-test', category: 'invalid-cat', description: 'bad category' })
      .then(() => { console.log('SHOULD_HAVE_FAILED'); process.exit(1); })
      .catch(e => { console.log(e.message); process.exit(0); });
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid category"* ]]
}

# -----------------------------------------------------------------------------
# Validation: reject invalid tier
# -----------------------------------------------------------------------------
@test "rejects invalid tier" {
  run node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'tier-test', category: 'dev', description: 'tier test', tier: 'ultra' })
      .then(() => { console.log('SHOULD_HAVE_FAILED'); process.exit(1); })
      .catch(e => { console.log(e.message); process.exit(0); });
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid tier"* ]]
}

# -----------------------------------------------------------------------------
# Validation: reject unsafe description (template injection prevention)
# -----------------------------------------------------------------------------
@test "rejects description with unsafe characters" {
  run node -e "
    const cs = require('$FAKE_SKILLS_ROOT/system/skill-creator/tools/create-skill');
    cs({ skill_name: 'unsafe-test', category: 'dev', description: 'bad \`injection\`' })
      .then(() => { console.log('SHOULD_HAVE_FAILED'); process.exit(1); })
      .catch(e => { console.log(e.message); process.exit(0); });
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid description"* ]]
}
