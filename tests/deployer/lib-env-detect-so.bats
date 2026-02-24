#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/lib/env-detect.sh — detectar_so()
# Story 11.1: OS detection (Linux/macOS/WSL/Windows-no-WSL)
# =============================================================================

setup() {
  eval "$(cat "${BATS_TEST_DIRNAME}/../../deployer/lib/env-detect.sh" | sed 's/^readonly //g')"
}

# --- detectar_so ---

@test "detectar_so: returns 'linux' on native Linux" {
  uname() { echo "Linux"; }
  export -f uname
  # Ensure WSL env var is not set
  unset WSL_DISTRO_NAME 2>/dev/null || true

  # Mock grep to NOT find microsoft in /proc/version
  grep() { return 1; }
  export -f grep

  run detectar_so
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
}

@test "detectar_so: returns 'wsl' when WSL_DISTRO_NAME is set" {
  uname() { echo "Linux"; }
  export -f uname
  export WSL_DISTRO_NAME="Ubuntu"

  run detectar_so
  [ "$status" -eq 0 ]
  [ "$output" = "wsl" ]

  unset WSL_DISTRO_NAME
}

@test "detectar_so: returns 'macos' on Darwin" {
  uname() { echo "Darwin"; }
  export -f uname

  run detectar_so
  [ "$status" -eq 0 ]
  [ "$output" = "macos" ]
}

@test "detectar_so: returns 'windows-no-wsl' for unknown kernel" {
  uname() { echo "MINGW64_NT"; }
  export -f uname

  run detectar_so
  [ "$status" -eq 0 ]
  [ "$output" = "windows-no-wsl" ]
}

@test "detectar_so: returns something when uname fails" {
  uname() { return 1; }
  export -f uname

  run detectar_so
  [ "$status" -eq 0 ]
  [ "$output" = "windows-no-wsl" ]
}

# --- detectar_ambiente still works ---

@test "detectar_ambiente: still exists and returns local or vps" {
  docker() { echo "inactive"; }
  export -f docker

  run detectar_ambiente
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}
