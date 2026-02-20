#!/bin/bash
# ============================================
# Validate Installation
# ============================================
# Checks that the AIOSBot stack is properly
# configured and all components are accessible.
#
# Usage: ./scripts/validate.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
  local name="$1"
  local result="$2"

  if [[ "$result" == "pass" ]]; then
    echo -e "  ${GREEN}✓${NC} $name"
    PASS=$((PASS + 1))
  elif [[ "$result" == "warn" ]]; then
    echo -e "  ${YELLOW}⚠${NC} $name"
    WARN=$((WARN + 1))
  else
    echo -e "  ${RED}✗${NC} $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "============================================"
echo "  AIOSBot Stack Validation"
echo "============================================"
echo ""

# 1. Check .env exists
echo "Environment:"
if [[ -f ".env" ]]; then
  check ".env file exists" "pass"
  source .env 2>/dev/null
else
  check ".env file exists" "fail"
fi

# 2. Check template files were processed
echo ""
echo "Templates:"
UNPROCESSED=$(find . -name "*.template" -exec grep -l '{{' {} \; 2>/dev/null | wc -l)
GENERATED=$(find . -name "*.template" | while read t; do
  out="${t%.template}"
  [[ -f "$out" ]] && echo "1"
done | wc -l)

if [[ "$GENERATED" -gt 0 ]]; then
  check "$GENERATED template(s) processed" "pass"
else
  check "No templates processed — run setup.sh first" "fail"
fi

# 3. Check for leftover placeholders in generated files
PLACEHOLDERS=$(grep -r '{{[A-Z_]*}}' . --include='*.json' --include='*.yaml' --include='*.js' --include='*.md' --exclude-dir='.git' --exclude='*.template' 2>/dev/null | grep -v 'node_modules' | wc -l)
if [[ "$PLACEHOLDERS" -eq 0 ]]; then
  check "No unresolved placeholders" "pass"
else
  check "$PLACEHOLDERS unresolved placeholder(s) found" "warn"
fi

# 4. Check for leaked secrets
echo ""
echo "Security:"
SECRETS=0
for pattern in "sk-or-v1-" "sk-ant-" "sk-proj-" "eyJhbGci" "AIzaSy"; do
  if grep -r "$pattern" . --include='*.json' --include='*.js' --include='*.yaml' --exclude-dir='.git' --exclude='*.template' --exclude='.env' 2>/dev/null | head -1 > /dev/null 2>&1; then
    SECRETS=$((SECRETS + 1))
  fi
done
if [[ "$SECRETS" -eq 0 ]]; then
  check "No leaked API keys" "pass"
else
  check "$SECRETS leaked secret pattern(s) detected!" "fail"
fi

# 5. Check aiosbot CLI
echo ""
echo "Tools:"
if command -v aiosbot &>/dev/null; then
  check "aiosbot CLI installed" "pass"
else
  check "aiosbot CLI not found" "warn"
fi

if command -v node &>/dev/null; then
  check "Node.js $(node --version)" "pass"
else
  check "Node.js not installed" "fail"
fi

if command -v tailscale &>/dev/null; then
  check "Tailscale installed" "pass"
else
  check "Tailscale not installed" "warn"
fi

# Summary
echo ""
echo "============================================"
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
echo "============================================"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
