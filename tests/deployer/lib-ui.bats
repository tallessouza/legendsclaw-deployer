#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/lib/ui.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/lib-ui.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || true)
}

# -----------------------------------------------------------------------------
# step_init
# -----------------------------------------------------------------------------
@test "step_init sets total and resets counters" {
  step_init 10
  [ "$STEP_TOTAL" -eq 10 ]
  [ "$STEP_CURRENT" -eq 0 ]
  [ "$STEP_OK" -eq 0 ]
  [ "$STEP_SKIP" -eq 0 ]
  [ "$STEP_FAIL" -eq 0 ]
}

# -----------------------------------------------------------------------------
# step_ok
# -----------------------------------------------------------------------------
@test "step_ok increments current and ok counters" {
  step_init 5
  step_ok "teste ok"
  [ "$STEP_CURRENT" -eq 1 ]
  [ "$STEP_OK" -eq 1 ]
}

@test "step_ok outputs N/TOTAL - [ OK ] format" {
  step_init 3
  run step_ok "Docker instalado"
  [[ "$output" == *"1/3"* ]]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"Docker instalado"* ]]
}

# -----------------------------------------------------------------------------
# step_fail
# -----------------------------------------------------------------------------
@test "step_fail increments current and fail counters" {
  step_init 5
  step_fail "teste fail"
  [ "$STEP_CURRENT" -eq 1 ]
  [ "$STEP_FAIL" -eq 1 ]
}

@test "step_fail outputs N/TOTAL - [ FAIL ] format" {
  step_init 3
  run step_fail "Falha na instalacao"
  [[ "$output" == *"1/3"* ]]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"Falha na instalacao"* ]]
}

# -----------------------------------------------------------------------------
# step_skip
# -----------------------------------------------------------------------------
@test "step_skip increments current and skip counters" {
  step_init 5
  step_skip "teste skip"
  [ "$STEP_CURRENT" -eq 1 ]
  [ "$STEP_SKIP" -eq 1 ]
}

@test "step_skip outputs N/TOTAL - [ SKIP ] format" {
  step_init 3
  run step_skip "Ja instalado"
  [[ "$output" == *"1/3"* ]]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"Ja instalado"* ]]
}

# -----------------------------------------------------------------------------
# Mixed steps sequence
# -----------------------------------------------------------------------------
@test "sequential steps increment counter correctly" {
  step_init 5
  step_ok "passo 1"
  step_skip "passo 2"
  step_fail "passo 3"
  [ "$STEP_CURRENT" -eq 3 ]
  [ "$STEP_OK" -eq 1 ]
  [ "$STEP_SKIP" -eq 1 ]
  [ "$STEP_FAIL" -eq 1 ]
}

# -----------------------------------------------------------------------------
# tabela
# -----------------------------------------------------------------------------
@test "tabela outputs formatted table" {
  run tabela "Portas" "80|TCP|HTTP" "443|TCP|HTTPS"
  [[ "$output" == *"Portas"* ]]
  [[ "$output" == *"80"* ]]
  [[ "$output" == *"443"* ]]
}

# -----------------------------------------------------------------------------
# resumo_final
# -----------------------------------------------------------------------------
@test "resumo_final shows summary" {
  step_init 3
  step_ok "ok"
  step_skip "skip"
  step_fail "fail"
  run resumo_final
  [[ "$output" == *"RESUMO"* ]]
  [[ "$output" == *"1"* ]]
}
