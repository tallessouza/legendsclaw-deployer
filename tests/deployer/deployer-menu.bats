#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/deployer.sh — Menu Seletor de Ambiente
# Story 11.1: Menu [1] Local / [2] VPS / [0] Sair
# =============================================================================

setup() {
  DEPLOYER="${BATS_TEST_DIRNAME}/../../deployer/deployer.sh"
}

# --- show_menu_ambiente exists ---

@test "deployer.sh: contains show_menu_ambiente function" {
  run grep -c "show_menu_ambiente" "$DEPLOYER"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]  # definition + call
}

# --- show_menu still exists ---

@test "deployer.sh: show_menu function still exists (VPS menu)" {
  run grep -c "show_menu()" "$DEPLOYER"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# --- menu_vps has all 16 ferramentas ---

@test "deployer.sh: menu_vps contains all 16 ferramentas" {
  for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16; do
    run grep "ferramentas/${i}-" "$DEPLOYER"
    [ "$status" -eq 0 ]
  done
}

# --- AUTO_MODE bypass ---

@test "deployer.sh: AUTO_MODE skips menu seletor" {
  run grep -A2 'AUTO_MODE.*true' "$DEPLOYER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"menu_vps"* ]]
}

# --- setup-local.sh reference ---

@test "deployer.sh: references ferramentas/setup-local.sh" {
  run grep "setup-local.sh" "$DEPLOYER"
  [ "$status" -eq 0 ]
}

# --- Option 0 exits ---

@test "deployer.sh: menu seletor has exit option" {
  run grep "Sair" "$DEPLOYER"
  [ "$status" -eq 0 ]
}

# --- Syntax check ---

@test "deployer.sh: passes bash syntax check" {
  run bash -n "$DEPLOYER"
  [ "$status" -eq 0 ]
}

# --- setup-local.sh syntax ---

@test "ferramentas/setup-local.sh: passes bash syntax check" {
  run bash -n "${BATS_TEST_DIRNAME}/../../deployer/ferramentas/setup-local.sh"
  [ "$status" -eq 0 ]
}
