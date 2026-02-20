#!/bin/bash
# ============================================
# Sanitize Script - Remove hardcoded values
# ============================================
# Scans files and replaces known sensitive values
# with {{PLACEHOLDER}} syntax.
#
# Usage: ./scripts/sanitize.sh [directory]

set -euo pipefail

TARGET_DIR="${1:-.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[SANITIZE]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Define replacements: "pattern|placeholder"
REPLACEMENTS=(
  # Add your organization-specific values here
  # "YourOrgPassword|{{GATEWAY_PASSWORD}}"
  # "your-tailnet-id|{{TAILNET_ID}}"
  # "1.2.3.4|{{VPS_IP}}"
  # "your-gateway|{{GATEWAY_HOSTNAME}}"
)

log "Scanning $TARGET_DIR for sensitive values..."

TOTAL_REPLACEMENTS=0

for entry in "${REPLACEMENTS[@]}"; do
  IFS='|' read -r pattern placeholder <<< "$entry"

  # Count occurrences
  count=$(grep -rl "$pattern" "$TARGET_DIR" --include='*.json' --include='*.yaml' --include='*.yml' --include='*.md' --include='*.js' --include='*.sh' --include='*.template' 2>/dev/null | wc -l)

  if [[ "$count" -gt 0 ]]; then
    log "Replacing '$pattern' → '$placeholder' in $count files"
    grep -rl "$pattern" "$TARGET_DIR" --include='*.json' --include='*.yaml' --include='*.yml' --include='*.md' --include='*.js' --include='*.sh' --include='*.template' 2>/dev/null | while read -r file; do
      sed -i "s|$pattern|$placeholder|g" "$file"
    done
    TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + count))
  fi
done

log "Total files modified: $TOTAL_REPLACEMENTS"

# Verify: check for common patterns that shouldn't be in a whitelabel repo
log "Verifying sanitization..."
ISSUES=0

# Check for API key patterns
if grep -r "sk-or-v1-" "$TARGET_DIR" --include='*.json' --include='*.js' --include='*.yaml' 2>/dev/null | grep -v '.template'; then
  warn "Found OpenRouter API key pattern!"
  ISSUES=$((ISSUES + 1))
fi

if grep -r "sk-ant-" "$TARGET_DIR" --include='*.json' --include='*.js' --include='*.yaml' 2>/dev/null | grep -v '.template'; then
  warn "Found Anthropic API key pattern!"
  ISSUES=$((ISSUES + 1))
fi

if grep -r "sk-proj-" "$TARGET_DIR" --include='*.json' --include='*.js' --include='*.yaml' 2>/dev/null | grep -v '.template'; then
  warn "Found OpenAI API key pattern!"
  ISSUES=$((ISSUES + 1))
fi

if grep -r "eyJhbGci" "$TARGET_DIR" --include='*.json' --include='*.js' --include='*.yaml' 2>/dev/null | grep -v '.template'; then
  warn "Found JWT token pattern!"
  ISSUES=$((ISSUES + 1))
fi

if [[ "$ISSUES" -eq 0 ]]; then
  echo -e "${GREEN}✓ Sanitization verified — no known sensitive patterns found.${NC}"
else
  echo -e "${RED}✗ Found $ISSUES potential sensitive value(s). Review above warnings.${NC}"
  exit 1
fi
