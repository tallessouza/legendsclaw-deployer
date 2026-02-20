#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — UI Functions
# Feedback visual pattern SetupOrion (N/M - [OK]/[FAIL]/[SKIP])
# =============================================================================

# Cores ANSI
readonly UI_RED='\033[0;31m'
readonly UI_GREEN='\033[0;32m'
readonly UI_YELLOW='\033[1;33m'
readonly UI_BLUE='\033[0;34m'
readonly UI_CYAN='\033[0;36m'
readonly UI_NC='\033[0m'
readonly UI_BOLD='\033[1m'

# Contadores globais
STEP_CURRENT=0
STEP_TOTAL=0
STEP_OK=0
STEP_SKIP=0
STEP_FAIL=0

# Inicializa contadores para uma ferramenta
# Uso: step_init 13
step_init() {
  STEP_TOTAL="${1:-0}"
  STEP_CURRENT=0
  STEP_OK=0
  STEP_SKIP=0
  STEP_FAIL=0
}

# Feedback OK
# Uso: step_ok "Descricao do passo"
step_ok() {
  local message="$1"
  STEP_CURRENT=$((STEP_CURRENT + 1))
  STEP_OK=$((STEP_OK + 1))
  echo -e "${STEP_CURRENT}/${STEP_TOTAL} - [ ${UI_GREEN}OK${UI_NC} ] - ${message}"
}

# Feedback FAIL
# Uso: step_fail "Descricao do passo"
step_fail() {
  local message="$1"
  STEP_CURRENT=$((STEP_CURRENT + 1))
  STEP_FAIL=$((STEP_FAIL + 1))
  echo -e "${STEP_CURRENT}/${STEP_TOTAL} - [ ${UI_RED}FAIL${UI_NC} ] - ${message}"
}

# Feedback SKIP
# Uso: step_skip "Descricao do passo"
step_skip() {
  local message="$1"
  STEP_CURRENT=$((STEP_CURRENT + 1))
  STEP_SKIP=$((STEP_SKIP + 1))
  echo -e "${STEP_CURRENT}/${STEP_TOTAL} - [ ${UI_YELLOW}SKIP${UI_NC} ] - ${message}"
}

# Exibe tabela formatada
# Uso: tabela "Header" "col1|col2|col3" "val1|val2|val3" ...
tabela() {
  local title="$1"
  shift
  echo ""
  echo -e "${UI_BOLD}${title}${UI_NC}"
  echo "----------------------------------------------"
  for row in "$@"; do
    echo -e "  $(echo "$row" | sed 's/|/\t/g')"
  done
  echo "----------------------------------------------"
  echo ""
}

# Exibe resumo final de uma ferramenta
resumo_final() {
  echo ""
  echo -e "${UI_BOLD}=============================================="
  echo "  RESUMO"
  echo -e "==============================================${UI_NC}"
  echo ""
  echo -e "  ${UI_GREEN}OK${UI_NC}:   ${STEP_OK}"
  echo -e "  ${UI_YELLOW}SKIP${UI_NC}: ${STEP_SKIP}"
  echo -e "  ${UI_RED}FAIL${UI_NC}: ${STEP_FAIL}"
  echo ""
}
