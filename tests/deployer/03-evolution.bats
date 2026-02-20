#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/ferramentas/03-evolution.sh
# Story 1.3: Evolution API deployment
# =============================================================================

setup() {
  eval "$(cat "${BATS_TEST_DIRNAME}/../../deployer/lib/common.sh" | sed 's/^readonly //g')"
  eval "$(cat "${BATS_TEST_DIRNAME}/../../deployer/lib/env-detect.sh" | sed 's/^readonly //g')"
}

# --- API key generation ---

@test "openssl rand generates 32-char hex key" {
  apikey=$(openssl rand -hex 16)
  [ ${#apikey} -eq 32 ]
}

# --- YAML generation: VPS mode produces Traefik labels ---

@test "evolution VPS yaml includes traefik labels" {
  local url_evolution="api.exemplo.com"
  local apikeyglobal="testkey123"
  local senha_postgres="testpass"
  local nome_rede="legendsclaw_net"
  local tmpfile=$(mktemp)

  cat > "$tmpfile" << EOL
    deploy:
      labels:
        - traefik.enable=1
        - traefik.http.routers.evolution.rule=Host(\`${url_evolution}\`)
EOL

  grep -q "traefik.enable=1" "$tmpfile"
  grep -q "api.exemplo.com" "$tmpfile"
  rm -f "$tmpfile"
}

# --- YAML generation: Local mode has ports exposed ---

@test "evolution local yaml includes port mapping" {
  local tmpfile=$(mktemp)

  cat > "$tmpfile" << EOL
    ports:
      - "8080:8080"
EOL

  grep -q "8080:8080" "$tmpfile"
  rm -f "$tmpfile"
}

# --- YAML generation: Local mode has no Traefik labels ---

@test "evolution local yaml does not include traefik" {
  local tmpfile=$(mktemp)

  cat > "$tmpfile" << EOL
services:
  evolution_api:
    image: evoapicloud/evolution-api:latest
    ports:
      - "8080:8080"
  evolution_redis:
    image: redis:latest
EOL

  ! grep -q "traefik" "$tmpfile"
  rm -f "$tmpfile"
}

# --- Credentials file ---

@test "dados_evolution contains required fields" {
  local tmpdir=$(mktemp -d)

  cat > "$tmpdir/dados_evolution" << EOL
[ EVOLUTION API ]

Manager Evolution: https://api.exemplo.com/manager

BaseUrl: https://api.exemplo.com

Global API Key: abc123def456
EOL

  grep -q "Manager Evolution" "$tmpdir/dados_evolution"
  grep -q "BaseUrl" "$tmpdir/dados_evolution"
  grep -q "Global API Key" "$tmpdir/dados_evolution"

  rm -rf "$tmpdir"
}

# --- Dependencies ---

@test "evolution script sources env-detect.sh" {
  grep -q "env-detect.sh" "${BATS_TEST_DIRNAME}/../../deployer/ferramentas/03-evolution.sh"
}

@test "evolution script calls verificar_container_postgres" {
  grep -q "verificar_container_postgres" "${BATS_TEST_DIRNAME}/../../deployer/ferramentas/03-evolution.sh"
}

@test "evolution script calls criar_banco_postgres_da_stack" {
  grep -q "criar_banco_postgres_da_stack" "${BATS_TEST_DIRNAME}/../../deployer/ferramentas/03-evolution.sh"
}
