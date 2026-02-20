#!/bin/bash
# Test local-to-VPS connection
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0

echo "=== Local → VPS Connection Test ==="

# Test 1: Tailscale connectivity
echo -n "1. Tailscale status... "
if command -v tailscale &>/dev/null; then
  STATUS=$(tailscale status 2>/dev/null | head -1)
  echo -e "${GREEN}$STATUS${NC}"
else
  echo -e "${RED}Tailscale not installed${NC}"
  FAILURES=$((FAILURES + 1))
fi

# Test 2: Ping gateway
GATEWAY_HOST="${GATEWAY_HOSTNAME:-}"
TAILNET="${TAILNET_ID:-}"
if [[ -n "$GATEWAY_HOST" ]] && [[ -n "$TAILNET" ]]; then
  FULL_HOST="${GATEWAY_HOST}.${TAILNET}.ts.net"
  echo -n "2. Ping gateway ($FULL_HOST)... "
  if command -v tailscale &>/dev/null; then
    if tailscale ping --timeout=5s "$GATEWAY_HOST" > /dev/null 2>&1; then
      echo -e "${GREEN}OK${NC}"
    else
      echo -e "${RED}FAILED${NC}"
    fi
  else
    if ping -c 1 -W 5 "$FULL_HOST" > /dev/null 2>&1; then
      echo -e "${GREEN}OK${NC}"
    else
      echo -e "${RED}FAILED${NC}"
    fi
  fi
else
  echo -e "2. ${YELLOW}Gateway hostname not configured${NC}"
fi

# Test 3: Local config exists
echo -n "3. Local config... "
if [[ -f "${HOME}/.aiosbot/aiosbot.json" ]]; then
  MODE=$(cd "${HOME}/.aiosbot" && node -e "console.log(require('./aiosbot.json').gateway?.mode || 'unknown')" 2>/dev/null || echo "error")
  echo -e "${GREEN}Found (mode: $MODE)${NC}"
else
  echo -e "${RED}Not found${NC}"
  FAILURES=$((FAILURES + 1))
fi

# Test 4: Bridge
echo -n "4. Bridge.js... "
BRIDGE="${HOME}/.aiosbot/bridge/bridge.js"
if [[ -f "$BRIDGE" ]]; then
  BRIDGE_STATUS=$(node "$BRIDGE" status 2>/dev/null | jq -r '.total // "error"' 2>/dev/null || echo "error")
  echo -e "${GREEN}Found ($BRIDGE_STATUS services)${NC}"
else
  echo -e "${YELLOW}Not installed${NC}"
fi

# Test 5: aiosbot doctor
echo -n "5. aiosbot doctor... "
if command -v aiosbot &>/dev/null; then
  if aiosbot doctor > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${YELLOW}Issues found (run 'aiosbot doctor' for details)${NC}"
  fi
else
  echo -e "${RED}aiosbot not installed${NC}"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "=== Test Complete ($FAILURES failures) ==="
exit $FAILURES
