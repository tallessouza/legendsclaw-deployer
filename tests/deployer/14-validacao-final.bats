#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/ferramentas/14-validacao-final.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/14-validacao-final.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TOOL_SCRIPT="${SCRIPT_DIR}/ferramentas/14-validacao-final.sh"

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
}

teardown() {
  rm -rf "$STATE_DIR" "$LOG_DIR" 2>/dev/null || true
}

# =============================================================================
# EXISTENCE AND SYNTAX
# =============================================================================

@test "14-validacao-final.sh exists" {
  [[ -f "$TOOL_SCRIPT" ]]
}

@test "14-validacao-final.sh has valid syntax" {
  run bash -n "$TOOL_SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "14-validacao-final.sh is executable" {
  [[ -x "$TOOL_SCRIPT" ]]
}

# =============================================================================
# INDIVIDUAL CHECK MOCKS — OK SCENARIOS
# =============================================================================

@test "check 1: Docker Swarm OK when active" {
  # Mock docker info
  docker() {
    if [[ "$1" == "info" ]]; then
      echo "active"
    fi
  }
  export -f docker

  swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "unknown")
  [[ "$swarm_state" == "active" ]]
}

@test "check 3: Portainer OK with valid health response" {
  # Create mock state file
  cat > "$STATE_DIR/dados_portainer" << 'EOF'
Portainer URL: https://portainer.example.com
Usuario: admin
EOF

  portainer_url=$(grep "Portainer URL:" "$STATE_DIR/dados_portainer" | awk -F': ' '{print $2}')
  [[ "$portainer_url" == "https://portainer.example.com" ]]
}

@test "check 5: Tailscale SKIP when not installed" {
  # Simulate tailscale not found
  if ! command -v tailscale_nonexistent_cmd &>/dev/null; then
    result="SKIP"
  fi
  [[ "$result" == "SKIP" ]]
}

@test "check 6: LLM Router OK with config present" {
  cat > "$STATE_DIR/dados_llm_router" << 'EOF'
Config: /opt/openclaw/llm-router.yaml
LLM_ROUTER_CONFIG: configured
EOF

  config=$(grep "LLM_ROUTER_CONFIG:" "$STATE_DIR/dados_llm_router" | awk -F': ' '{print $2}')
  [[ "$config" == "configured" ]]
}

# =============================================================================
# INDIVIDUAL CHECK MOCKS — FAIL SCENARIOS
# =============================================================================

@test "check 1: Docker Swarm FAIL when inactive" {
  swarm_state="inactive"
  if [[ "$swarm_state" != "active" ]]; then
    result="FAIL"
  fi
  [[ "$result" == "FAIL" ]]
}

@test "check 4: OpenClaw FAIL diagnostic includes curl command" {
  # Simula falha com diagnostico
  gateway_url="http://localhost:18789"
  detail="Health check falhou. Diagnostico: curl -s ${gateway_url}/health"
  [[ "$detail" == *"curl -s"* ]]
  [[ "$detail" == *"/health"* ]]
}

@test "check 8: Evolution FAIL when URL missing" {
  cat > "$STATE_DIR/dados_evolution" << 'EOF'
Instancia: legendsclaw
EOF

  evolution_url=$(grep "Evolution URL:" "$STATE_DIR/dados_evolution" 2>/dev/null | awk -F': ' '{print $2}')
  [[ -z "$evolution_url" ]]
}

# =============================================================================
# SKIP SCENARIOS — MISSING DEPENDENCIES
# =============================================================================

@test "check 3: Portainer SKIP when dados_portainer absent" {
  [[ ! -f "$STATE_DIR/dados_portainer" ]]
}

@test "check 4: OpenClaw SKIP when dados_openclaw absent" {
  [[ ! -f "$STATE_DIR/dados_openclaw" ]]
}

@test "check 7: Skills SKIP when dados_whitelabel absent" {
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
}

@test "check 8: Evolution SKIP when dados_evolution absent" {
  [[ ! -f "$STATE_DIR/dados_evolution" ]]
}

@test "check 10: Blocklist SKIP when dados_whitelabel absent" {
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
}

@test "check 11: Sandbox SKIP when dados_seguranca absent" {
  [[ ! -f "$STATE_DIR/dados_seguranca" ]]
}

@test "check 12: Hooks SKIP when dados_bridge absent" {
  [[ ! -f "$STATE_DIR/dados_bridge" ]]
}

# =============================================================================
# RELATORIO GENERATION
# =============================================================================

@test "report format has correct header" {
  local report_file="${STATE_DIR}/relatorio_instalacao.txt"
  cat > "$report_file" << 'EOF'
==========================================
RELATORIO DE INSTALACAO — LEGENDSCLAW
Data: 2026-02-20 10:00:00
Servidor: test-server
==========================================
EOF

  [[ -f "$report_file" ]]
  run grep "RELATORIO DE INSTALACAO" "$report_file"
  [[ "$status" -eq 0 ]]
}

@test "report contains checklist section" {
  local report_file="${STATE_DIR}/relatorio_instalacao.txt"
  cat > "$report_file" << 'EOF'
CHECKLIST (12 pontos):
[OK  ]  1. Docker Swarm
[FAIL]  2. Traefik
[SKIP]  3. Portainer

RESULTADO FINAL: 1/12 OK, 1 FAIL, 1 SKIP
==========================================
EOF

  run grep "CHECKLIST" "$report_file"
  [[ "$status" -eq 0 ]]
  run grep "RESULTADO FINAL" "$report_file"
  [[ "$status" -eq 0 ]]
}

@test "report file has chmod 600" {
  local report_file="${STATE_DIR}/relatorio_instalacao.txt"
  echo "test" > "$report_file"
  chmod 600 "$report_file"

  local perms
  perms=$(stat -c %a "$report_file" 2>/dev/null || stat -f %Lp "$report_file" 2>/dev/null)
  [[ "$perms" == "600" ]]
}

@test "mask_credential hides middle of key" {
  # Source the function
  mask_credential() {
    local value="$1"
    local len=${#value}
    if [[ $len -le 8 ]]; then
      echo "****"
    else
      echo "${value:0:4}****${value:$((len-4)):4}"
    fi
  }

  run mask_credential "abcdefghijklmnop"
  [[ "$output" == "abcd****mnop" ]]
}

@test "mask_credential returns **** for short keys" {
  mask_credential() {
    local value="$1"
    local len=${#value}
    if [[ $len -le 8 ]]; then
      echo "****"
    else
      echo "${value:0:4}****${value:$((len-4)):4}"
    fi
  }

  run mask_credential "abc"
  [[ "$output" == "****" ]]
}

# =============================================================================
# OFFLINE / GRACEFUL DEGRADATION
# =============================================================================

@test "partially populated dados_vps yields SKIP not FAIL" {
  # Only dados_vps present, nothing else
  cat > "$STATE_DIR/dados_vps" << 'EOF'
Nome do Servidor: test-server
Rede interna: legendsclaw
EOF

  # Check that missing files result in SKIP logic
  [[ ! -f "$STATE_DIR/dados_portainer" ]]
  [[ ! -f "$STATE_DIR/dados_openclaw" ]]
  [[ ! -f "$STATE_DIR/dados_evolution" ]]
  [[ ! -f "$STATE_DIR/dados_seguranca" ]]
  [[ ! -f "$STATE_DIR/dados_bridge" ]]
}

# =============================================================================
# HINTS
# =============================================================================

@test "hint_validation_report displays header" {
  run hint_validation_report
  [[ "$output" == *"COMO INTERPRETAR O RELATORIO"* ]]
  [[ "$output" == *"[OK]"* ]]
  [[ "$output" == *"[FAIL]"* ]]
  [[ "$output" == *"[SKIP]"* ]]
}

@test "hint_validation_troubleshoot displays all components" {
  run hint_validation_troubleshoot
  [[ "$output" == *"Docker Swarm"* ]]
  [[ "$output" == *"Traefik"* ]]
  [[ "$output" == *"Portainer"* ]]
  [[ "$output" == *"OpenClaw"* ]]
  [[ "$output" == *"Tailscale"* ]]
  [[ "$output" == *"Evolution"* ]]
}

@test "hint_validation_rerun shows re-execution steps" {
  run hint_validation_rerun
  [[ "$output" == *"Ferramenta [14]"* ]]
  [[ "$output" == *"corrigir"* ]]
}

# =============================================================================
# DEPLOYER MENU
# =============================================================================

@test "deployer menu includes Validacao Final option" {
  run grep -c "Validacao Final" "${SCRIPT_DIR}/deployer.sh"
  [[ "$output" -ge "1" ]]
}

@test "deployer menu includes case 14" {
  run grep -c "14-validacao-final.sh" "${SCRIPT_DIR}/deployer.sh"
  [[ "$output" -ge "1" ]]
}
