#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/lib/hints.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/lib-hints.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"

setup() {
  source <(sed 's/^readonly //g' "$SCRIPT_DIR/lib/hints.sh" 2>/dev/null || true)
}

# -----------------------------------------------------------------------------
# hint_firewall
# -----------------------------------------------------------------------------
@test "hint_firewall displays port table" {
  run hint_firewall
  [[ "$output" == *"FIREWALL"* ]]
  [[ "$output" == *"22"* ]]
  [[ "$output" == *"80"* ]]
  [[ "$output" == *"443"* ]]
  [[ "$output" == *"9443"* ]]
  [[ "$output" == *"2377"* ]]
  [[ "$output" == *"7946"* ]]
  [[ "$output" == *"4789"* ]]
  [[ "$output" == *"41641"* ]]
}

@test "hint_firewall mentions SSH" {
  run hint_firewall
  [[ "$output" == *"SSH"* ]]
}

@test "hint_firewall mentions Swarm" {
  run hint_firewall
  [[ "$output" == *"Swarm"* ]]
}

@test "hint_firewall mentions Tailscale" {
  run hint_firewall
  [[ "$output" == *"Tailscale"* ]]
}

# -----------------------------------------------------------------------------
# hint_dns
# -----------------------------------------------------------------------------
@test "hint_dns displays DNS table" {
  run hint_dns "painel.exemplo.com"
  [[ "$output" == *"DNS"* ]]
  [[ "$output" == *"painel.exemplo.com"* ]]
  [[ "$output" == *"A"* ]]
}

@test "hint_dns uses default domain when none provided" {
  run hint_dns
  [[ "$output" == *"portainer.exemplo.com"* ]]
}

# -----------------------------------------------------------------------------
# hint_provider
# -----------------------------------------------------------------------------
@test "hint_provider shows hetzner hints" {
  run hint_provider "hetzner"
  [[ "$output" == *"HETZNER"* ]]
  [[ "$output" == *"CX21"* ]]
}

@test "hint_provider shows aws hints" {
  run hint_provider "aws"
  [[ "$output" == *"AWS"* ]]
  [[ "$output" == *"Security Groups"* ]]
}

@test "hint_provider shows generic hints for unknown provider" {
  run hint_provider "digitalocean"
  [[ "$output" == *"firewall"* ]]
}
