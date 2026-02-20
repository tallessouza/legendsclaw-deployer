#!/bin/bash
# Test skills loading
set -euo pipefail

SKILLS_DIR="${HOME}/.aiosbot/skills"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Skills Loading Test ==="

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo -e "${RED}Skills directory not found: $SKILLS_DIR${NC}"
  exit 1
fi

TOTAL=0
VALID=0
MISSING_SKILL_MD=0
MISSING_INDEX=0

for dir in "$SKILLS_DIR"/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")

  # Skip non-skill directories
  [[ "$name" == "node_modules" ]] && continue
  [[ "$name" == "lib" ]] && continue
  [[ "$name" == "tests" ]] && continue

  TOTAL=$((TOTAL + 1))

  has_skill_md=false
  has_index=false

  [[ -f "$dir/SKILL.md" ]] && has_skill_md=true
  [[ -f "$dir/index.js" ]] && has_index=true

  if $has_skill_md && $has_index; then
    echo -e "  ${GREEN}✓${NC} $name"
    VALID=$((VALID + 1))
  elif $has_index; then
    echo -e "  ${YELLOW}⚠${NC} $name (missing SKILL.md)"
    MISSING_SKILL_MD=$((MISSING_SKILL_MD + 1))
  elif $has_skill_md; then
    echo -e "  ${YELLOW}⚠${NC} $name (missing index.js)"
    MISSING_INDEX=$((MISSING_INDEX + 1))
  else
    echo -e "  ${RED}✗${NC} $name (missing both)"
  fi
done

echo ""
echo "Results: $VALID valid / $TOTAL total"
[[ "$MISSING_SKILL_MD" -gt 0 ]] && echo "  $MISSING_SKILL_MD missing SKILL.md"
[[ "$MISSING_INDEX" -gt 0 ]] && echo "  $MISSING_INDEX missing index.js"
echo ""

# Test aiosbot skills list
if command -v aiosbot &>/dev/null; then
  echo "aiosbot skills list:"
  aiosbot skills list 2>/dev/null || echo "  (aiosbot not running)"
fi

FAILURES=$((TOTAL - VALID))
echo "=== Test Complete ($FAILURES issues) ==="
exit $FAILURES
