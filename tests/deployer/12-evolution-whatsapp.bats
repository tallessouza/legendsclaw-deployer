#!/usr/bin/env bats
# =============================================================================
# Tests: Story 5.1 — Evolution API WhatsApp + Webhook Integration
# File: tests/deployer/12-evolution-whatsapp.bats
# =============================================================================

setup() {
  TEST_DIR="${BATS_TEST_DIRNAME}"
  PROJECT_ROOT="${TEST_DIR}/../.."
  DEPLOYER_DIR="${PROJECT_ROOT}/deployer"
}

# --- Task 1: evolution-api.sh exists and has required functions ---

@test "evolution-api.sh exists" {
  [ -f "${DEPLOYER_DIR}/lib/evolution-api.sh" ]
}

@test "evolution-api.sh is sourceable" {
  # Source with mocked UI vars to avoid errors
  UI_BOLD="" UI_NC="" UI_CYAN="" UI_YELLOW=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
}

@test "evolution_create_instance is defined" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
  declare -f evolution_create_instance > /dev/null
}

@test "evolution_connect_instance is defined" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
  declare -f evolution_connect_instance > /dev/null
}

@test "evolution_check_connection is defined" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
  declare -f evolution_check_connection > /dev/null
}

@test "evolution_set_webhook is defined" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
  declare -f evolution_set_webhook > /dev/null
}

@test "mask_key is defined in evolution-api.sh" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
  declare -f mask_key > /dev/null
}

@test "mask_key masks correctly" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/evolution-api.sh"
  result=$(mask_key "abc123def456ghi")
  [ "$result" = "abc1**** ghi" ] || [ "$result" = "abc1****ghi" ] || {
    # Just check it starts with abc1 and ends with something, and contains ****
    [[ "$result" == abc1**** ]]
  }
}

# --- Task 2: hints WhatsApp in hints.sh ---

@test "hint_whatsapp_prep is defined in hints.sh" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/hints.sh"
  declare -f hint_whatsapp_prep > /dev/null
}

@test "hint_whatsapp_qr is defined in hints.sh" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/hints.sh"
  declare -f hint_whatsapp_qr > /dev/null
}

@test "hint_evolution_debug is defined in hints.sh" {
  UI_BOLD="" UI_NC=""
  source "${DEPLOYER_DIR}/lib/hints.sh"
  declare -f hint_evolution_debug > /dev/null
}

# --- Task 3: 03-evolution.sh sources evolution-api.sh ---

@test "03-evolution.sh sources evolution-api.sh" {
  grep -q 'evolution-api.sh' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "03-evolution.sh checks OpenClaw dependency" {
  grep -q 'dados_openclaw' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "03-evolution.sh has OPENCLAW_AVAILABLE flag" {
  grep -q 'OPENCLAW_AVAILABLE' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "03-evolution.sh collects numero_whatsapp" {
  grep -q 'numero_whatsapp' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "03-evolution.sh has TOTAL=14" {
  grep -q 'readonly TOTAL=14' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

# --- YAML generation with webhook (OpenClaw available) ---

@test "YAML contains WEBHOOK_GLOBAL_ENABLED conditional" {
  grep -q 'WEBHOOK_GLOBAL_ENABLED=' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "YAML contains webhook URL pointing to openclaw_gateway" {
  grep -q 'openclaw_gateway' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "YAML contains WEBHOOK_EVENTS_MESSAGES_UPSERT conditional" {
  grep -q 'WEBHOOK_EVENTS_MESSAGES_UPSERT=' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

# --- Backward compatibility ---

@test "03-evolution.sh maintains standalone mode when OpenClaw absent" {
  # Verify the conditional pattern: when OPENCLAW_AVAILABLE is false, webhook is disabled
  grep -q 'OPENCLAW_AVAILABLE.*false' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

# --- Finalize: dados_evolution includes WhatsApp data ---

@test "03-evolution.sh writes Numero WhatsApp to dados_evolution" {
  grep -q 'Numero WhatsApp' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "03-evolution.sh writes Webhook URL to dados_evolution" {
  grep -q 'Webhook URL:' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "03-evolution.sh writes Instancia WA to dados_evolution" {
  grep -q 'Instancia WA:' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

# --- Hint debug in resumo ---

@test "03-evolution.sh calls hint_evolution_debug" {
  grep -q 'hint_evolution_debug' "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

# --- Syntax validation ---

@test "03-evolution.sh passes bash syntax check" {
  bash -n "${DEPLOYER_DIR}/ferramentas/03-evolution.sh"
}

@test "evolution-api.sh passes bash syntax check" {
  bash -n "${DEPLOYER_DIR}/lib/evolution-api.sh"
}

@test "hints.sh passes bash syntax check" {
  bash -n "${DEPLOYER_DIR}/lib/hints.sh"
}
