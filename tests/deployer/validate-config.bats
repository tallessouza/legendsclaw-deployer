#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/scripts/validate-config.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/validate-config.bats
# =============================================================================

REAL_DEPLOYER_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"

  # Criar estrutura fake do deployer em $TEST_DIR
  # Symlink libs reais, fixtures isoladas em $TEST_DIR
  DEPLOYER_DIR="${TEST_DIR}/deployer"
  mkdir -p "$DEPLOYER_DIR/scripts"
  ln -s "$REAL_DEPLOYER_DIR/lib" "$DEPLOYER_DIR/lib"
  cp "$REAL_DEPLOYER_DIR/scripts/validate-config.sh" "$DEPLOYER_DIR/scripts/"

  SCRIPT="${DEPLOYER_DIR}/scripts/validate-config.sh"

  # Estado fake
  export STATE_DIR="${TEST_DIR}/dados_vps"
  mkdir -p "$STATE_DIR"
  echo "agent_name: testagent" > "$STATE_DIR/dados_whitelabel"

  # Estrutura de apps (dentro de $TEST_DIR, nao no repo real)
  CONFIG_DIR="${DEPLOYER_DIR}/apps/testagent/config"
  mkdir -p "$CONFIG_DIR"

  # .env valido com permissoes 600
  cat > "$CONFIG_DIR/.env" <<'ENVEOF'
AGENT_NAME=testagent
VPS_IP=10.0.0.1
GATEWAY_HOSTNAME=localhost
TAILNET_ID=mytailnet
GATEWAY_PASSWORD=abc123def456ghi789jkl012mno345pq
HOOKS_TOKEN=aabbccddeeff00112233445566
OPENROUTER_API_KEY=sk-or-v1-testkey123
ENVEOF
  chmod 600 "$CONFIG_DIR/.env"

  # JSONs validos
  echo '{"name":"testagent"}' > "$CONFIG_DIR/aiosbot.json"
  echo '{"node":true}' > "$CONFIG_DIR/node.json"
  echo '{"mcp":[]}' > "$CONFIG_DIR/mcp-config.json"

  # Log dir
  mkdir -p "$TEST_DIR/legendsclaw-logs"

  # Mock ss para evitar interferência de portas reais
  MOCK_BIN="${TEST_DIR}/mock-bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/ss" <<'SSEOF'
#!/usr/bin/env bash
# Mock ss: retorna header sem resultados (portas livres)
echo "State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process"
SSEOF
  chmod +x "$MOCK_BIN/ss"
  export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# 2.2 Test: config valido completo → todos step_ok
# -----------------------------------------------------------------------------
@test "config valido completo: todos checks passam" {
  run bash "$SCRIPT" testagent
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"RESUMO"* ]]
  # Nenhum step_fail real (formato "[ FAIL ]" entre colchetes)
  local fail_steps
  fail_steps=$(echo "$output" | grep -c '\[ .*FAIL.* \]' || true)
  [ "$fail_steps" -eq 0 ]
}

# -----------------------------------------------------------------------------
# 2.3 Test: JSON invalido → step_fail
# -----------------------------------------------------------------------------
@test "JSON invalido: detecta syntax error" {
  echo '{invalid json' > "$CONFIG_DIR/aiosbot.json"
  run bash "$SCRIPT" testagent
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"JSON"* ]]
}

# -----------------------------------------------------------------------------
# 2.4 Test: placeholder nao resolvido → step_fail
# -----------------------------------------------------------------------------
@test "placeholder nao resolvido: detecta {{PLACEHOLDER}}" {
  echo '{"key":"{{PLACEHOLDER}}"}' > "$CONFIG_DIR/aiosbot.json"
  run bash "$SCRIPT" testagent
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"Placeholder"* ]] || [[ "$output" == *"placeholder"* ]]
}

# -----------------------------------------------------------------------------
# 2.5 Test: .env com permissao errada → step_fail
# -----------------------------------------------------------------------------
@test ".env permissao errada (644): detecta problema" {
  chmod 644 "$CONFIG_DIR/.env"
  run bash "$SCRIPT" testagent
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"644"* ]]
}

# -----------------------------------------------------------------------------
# 2.6 Test: variavel obrigatoria ausente → step_fail
# -----------------------------------------------------------------------------
@test "variavel obrigatoria ausente: detecta TAILNET_ID faltando" {
  grep -v "^TAILNET_ID=" "$CONFIG_DIR/.env" > "$CONFIG_DIR/.env.tmp"
  mv "$CONFIG_DIR/.env.tmp" "$CONFIG_DIR/.env"
  chmod 600 "$CONFIG_DIR/.env"
  run bash "$SCRIPT" testagent
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"TAILNET_ID"* ]]
}

# -----------------------------------------------------------------------------
# 2.7 Test: secret vazado em JSON config → step_fail
# -----------------------------------------------------------------------------
@test "secret vazado em JSON: detecta API key fora do .env" {
  echo '{"key":"sk-ant-abc123secret"}' > "$CONFIG_DIR/aiosbot.json"
  run bash "$SCRIPT" testagent
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"secret"* ]] || [[ "$output" == *"Secret"* ]]
}

# -----------------------------------------------------------------------------
# 2.8 Test: nenhuma API key → step_fail
# -----------------------------------------------------------------------------
@test "nenhuma API key: detecta ausencia de todas API keys" {
  grep -v "API_KEY" "$CONFIG_DIR/.env" > "$CONFIG_DIR/.env.tmp"
  mv "$CONFIG_DIR/.env.tmp" "$CONFIG_DIR/.env"
  chmod 600 "$CONFIG_DIR/.env"
  run bash "$SCRIPT" testagent
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"API key"* ]] || [[ "$output" == *"api key"* ]] || [[ "$output" == *"API_KEY"* ]]
}

# -----------------------------------------------------------------------------
# Teste adicional: agent name nao fornecido e sem fallback
# -----------------------------------------------------------------------------
@test "sem agent name: exibe erro e sai" {
  rm -f "$STATE_DIR/dados_whitelabel"
  run bash -c "echo '' | bash '$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERRO"* ]] || [[ "$output" == *"erro"* ]] || [[ "$output" == *"Uso:"* ]]
}
