#!/bin/bash
# ============================================
# AIOSBot VPS Stack - Config Validation
# ============================================
# Validates generated configuration files after
# setup.sh has processed all templates.
#
# Usage: ./scripts/validate-config.sh
# Called automatically by setup.sh after template processing.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0
WARNINGS=0

pass() { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $*"; FAILURES=$((FAILURES + 1)); }

echo "============================================"
echo "  Config Validation"
echo "============================================"
echo ""

# ── 1. Check .env exists ──────────────────────
echo "1. Environment file..."
if [[ -f "$REPO_DIR/.env" ]]; then
  pass ".env exists"

  # Check file permissions (should be 600)
  if [[ "$(stat -c %a "$REPO_DIR/.env" 2>/dev/null || stat -f %Lp "$REPO_DIR/.env" 2>/dev/null)" == "600" ]]; then
    pass ".env permissions are 600"
  else
    warn ".env permissions should be 600 (run: chmod 600 .env)"
  fi
else
  fail ".env not found — run setup.sh first"
fi

# ── 2. Check for unresolved placeholders ──────
echo ""
echo "2. Unresolved placeholders..."
PLACEHOLDER_FILES=(
  "vps/config/aiosbot.json"
  "vps/config/node.json"
  "local/config/aiosbot.json"
  "local/config/node.json"
  "vps/mcps/mcp-config.json"
)

UNRESOLVED=0
for f in "${PLACEHOLDER_FILES[@]}"; do
  FULL_PATH="$REPO_DIR/$f"
  if [[ -f "$FULL_PATH" ]]; then
    FOUND=$(grep -c '{{[A-Z_]*}}' "$FULL_PATH" 2>/dev/null || true)
    if [[ "$FOUND" -gt 0 ]]; then
      fail "$f has $FOUND unresolved placeholder(s)"
      grep -n '{{[A-Z_]*}}' "$FULL_PATH" 2>/dev/null | head -5 | while read -r line; do
        echo "        $line"
      done
      UNRESOLVED=$((UNRESOLVED + FOUND))
    else
      pass "$f — all placeholders resolved"
    fi
  fi
done

if [[ "$UNRESOLVED" -eq 0 ]]; then
  pass "Zero unresolved placeholders across all configs"
fi

# ── 3. Validate JSON syntax ───────────────────
echo ""
echo "3. JSON syntax..."
JSON_FILES=(
  "vps/config/aiosbot.json"
  "vps/config/node.json"
  "local/config/aiosbot.json"
  "local/config/node.json"
  "vps/mcps/mcp-config.json"
)

for f in "${JSON_FILES[@]}"; do
  FULL_PATH="$REPO_DIR/$f"
  if [[ -f "$FULL_PATH" ]]; then
    if node -e "JSON.parse(require('fs').readFileSync('$FULL_PATH','utf8'))" 2>/dev/null; then
      pass "$f — valid JSON"
    else
      fail "$f — invalid JSON syntax"
    fi
  fi
done

# ── 4. Required .env variables ────────────────
echo ""
echo "4. Required variables..."
REQUIRED_VARS=(
  "GATEWAY_PASSWORD:Gateway password"
  "TAILNET_ID:Tailscale tailnet ID"
  "GATEWAY_HOSTNAME:Gateway hostname"
  "VPS_IP:VPS IP address"
)

OPTIONAL_BUT_RECOMMENDED=(
  "OPENROUTER_API_KEY:OpenRouter API key (at least one LLM key needed)"
)

if [[ -f "$REPO_DIR/.env" ]]; then
  for entry in "${REQUIRED_VARS[@]}"; do
    var_name="${entry%%:*}"
    var_desc="${entry#*:}"
    VAL=$(grep "^${var_name}=" "$REPO_DIR/.env" 2>/dev/null | cut -d= -f2- || true)
    if [[ -z "$VAL" ]] || [[ "$VAL" == *"your-"* ]] || [[ "$VAL" == *"placeholder"* ]]; then
      fail "$var_desc ($var_name) not configured"
    else
      pass "$var_desc — set"
    fi
  done

  for entry in "${OPTIONAL_BUT_RECOMMENDED[@]}"; do
    var_name="${entry%%:*}"
    var_desc="${entry#*:}"
    VAL=$(grep "^${var_name}=" "$REPO_DIR/.env" 2>/dev/null | cut -d= -f2- || true)
    if [[ -z "$VAL" ]]; then
      warn "$var_desc — not set"
    else
      pass "$var_desc — set"
    fi
  done
fi

# ── 5. Security: no leaked secrets in templates ──
echo ""
echo "5. Secret leak check..."
SECRET_PATTERNS=(
  "sk-or-v1-:OpenRouter key"
  "sk-ant-:Anthropic key"
  "sk-proj-:OpenAI key"
  "eyJhbGci:JWT token"
  "AIzaSy:Google API key"
)

LEAKED=0
for entry in "${SECRET_PATTERNS[@]}"; do
  pattern="${entry%%:*}"
  desc="${entry#*:}"
  # Check generated configs (not .template files, not .env, not detection scripts)
  FOUND=$(grep -rl "$pattern" "$REPO_DIR/vps/config/"*.json "$REPO_DIR/local/config/"*.json 2>/dev/null | grep -v '.template' || true)
  if [[ -n "$FOUND" ]]; then
    warn "$desc pattern found in: $FOUND (expected in generated configs)"
  fi
done

if [[ "$LEAKED" -eq 0 ]]; then
  pass "No secret patterns leaked into config files"
fi

# ── 6. Port availability check ────────────────
echo ""
echo "6. Port check..."
if command -v ss &>/dev/null; then
  if ss -tlnp 2>/dev/null | grep -q ":18789 "; then
    warn "Port 18789 already in use (gateway port)"
  else
    pass "Port 18789 available"
  fi
  if ss -tlnp 2>/dev/null | grep -q ":55119 "; then
    warn "Port 55119 already in use (LLM router port)"
  else
    pass "Port 55119 available"
  fi
elif command -v netstat &>/dev/null; then
  if netstat -tlnp 2>/dev/null | grep -q ":18789 "; then
    warn "Port 18789 already in use"
  else
    pass "Port 18789 available"
  fi
else
  warn "Cannot check ports (ss/netstat not available)"
fi

# ── Summary ───────────────────────────────────
echo ""
echo "============================================"
if [[ "$FAILURES" -eq 0 ]]; then
  echo -e "  ${GREEN}Config validation PASSED${NC} ($WARNINGS warnings)"
else
  echo -e "  ${RED}Config validation FAILED${NC} ($FAILURES failures, $WARNINGS warnings)"
  echo ""
  echo "  Fix the issues above and re-run setup.sh"
fi
echo "============================================"
exit $FAILURES
