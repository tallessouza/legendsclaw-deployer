#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/lib/deploy.sh
# Framework: bats-core — com mocks de docker e curl
# Execucao: npx bats tests/deployer/lib-deploy.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  mkdir -p "$TEST_DIR/dados_vps"

  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/deploy.sh" 2>/dev/null || true)
}

teardown() {
  rm -rf "$TEST_DIR"
  unset -f docker 2>/dev/null || true
  unset -f curl 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# wait_stack — mock docker
# -----------------------------------------------------------------------------
@test "wait_stack returns 0 when service is already 1/1" {
  # Mock docker service ls to return 1/1
  docker() {
    case "$1" in
      service)
        echo "1/1"
        ;;
    esac
  }
  export -f docker

  run wait_stack "traefik_traefik"
  [ "$status" -eq 0 ]
}

@test "wait_stack returns 1 on timeout when service never comes up" {
  # Mock docker service ls to return 0/1 (never ready)
  docker() {
    case "$1" in
      service)
        echo "0/1"
        ;;
    esac
  }
  export -f docker

  # Override sleep to speed up test
  sleep() { :; }
  export -f sleep

  # Override max_iter to 1 for fast test (sed hack in source won't work for local var)
  # We'll test the timeout message instead
  run timeout 5 bash -c '
    source <(sed "s/^readonly //g; s/local max_iter=10/local max_iter=1/" "'"$SCRIPT_DIR"'/lib/deploy.sh" 2>/dev/null || true)
    sleep() { :; }
    docker() { echo "0/1"; }
    export -f docker sleep
    wait_stack "fake_service"
  '
  [[ "$output" == *"TIMEOUT"* ]] || [[ "$status" -ne 0 ]]
}

# -----------------------------------------------------------------------------
# pull — mock docker
# -----------------------------------------------------------------------------
@test "pull returns 0 when docker pull succeeds" {
  docker() {
    case "$1" in
      pull) return 0 ;;
    esac
  }
  export -f docker

  run pull "traefik:v3.5.3"
  [ "$status" -eq 0 ]
}

@test "pull retries on failure" {
  local call_count=0
  docker() {
    case "$1" in
      pull)
        call_count=$((call_count + 1))
        if [[ "$call_count" -lt 2 ]]; then
          return 1
        fi
        return 0
        ;;
    esac
  }
  export -f docker
  sleep() { :; }
  export -f sleep

  run pull "traefik:v3.5.3"
  # May succeed on retry or show retry message
  [[ "$status" -eq 0 ]] || [[ "$output" == *"Retry"* ]]
}

# -----------------------------------------------------------------------------
# stack_editavel — mock curl and docker
# -----------------------------------------------------------------------------
@test "stack_editavel fails when credentials not found" {
  # Empty dados_portainer
  touch "$TEST_DIR/dados_vps/dados_portainer"

  run stack_editavel "test_stack" "/tmp/nonexistent.yaml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Credenciais"* ]] || [[ "$output" == *"ERRO"* ]]
}
