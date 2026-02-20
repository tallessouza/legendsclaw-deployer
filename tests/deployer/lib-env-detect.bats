#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/lib/env-detect.sh
# Story 1.3: Environment detection (local vs VPS)
# =============================================================================

setup() {
  # Source functions removing readonly to avoid conflicts
  eval "$(cat "${BATS_TEST_DIRNAME}/../../deployer/lib/env-detect.sh" | sed 's/^readonly //g')"
}

# --- detectar_ambiente ---

@test "detectar_ambiente: returns 'vps' when swarm is active" {
  # Mock docker info to return active
  docker() {
    if [[ "$1" == "info" ]]; then
      echo "active"
    fi
  }
  export -f docker

  run detectar_ambiente
  [ "$status" -eq 0 ]
  [ "$output" = "vps" ]
}

@test "detectar_ambiente: returns 'local' when swarm is inactive" {
  docker() {
    if [[ "$1" == "info" ]]; then
      echo "inactive"
    fi
  }
  export -f docker

  run detectar_ambiente
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "detectar_ambiente: returns 'local' when docker is not available" {
  docker() {
    return 1
  }
  export -f docker

  run detectar_ambiente
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

# --- deploy_stack ---

@test "deploy_stack: calls docker compose in local mode" {
  detectar_ambiente() { echo "local"; }
  export -f detectar_ambiente

  local compose_called=false
  docker() {
    if [[ "$1" == "compose" ]]; then
      compose_called=true
      return 0
    fi
  }
  export -f docker

  run deploy_stack "test_stack" "/tmp/test.yaml"
  [ "$status" -eq 0 ]
}

@test "deploy_stack: calls stack_editavel in vps mode" {
  detectar_ambiente() { echo "vps"; }
  export -f detectar_ambiente

  stack_editavel() {
    echo "stack_editavel called with $1 $2"
    return 0
  }
  export -f stack_editavel

  run deploy_stack "test_stack" "/tmp/test.yaml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stack_editavel called"* ]]
}
