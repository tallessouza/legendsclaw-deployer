#!/bin/bash
# Test gateway connectivity
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

GATEWAY_HOST="${GATEWAY_HOSTNAME:-localhost}"
TAILNET="${TAILNET_ID:-}"
PORT="${GATEWAY_PORT:-18789}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILURES=0

echo "=== Gateway Connectivity Test ==="

# Test 1: Local gateway (if running on VPS)
echo -n "Local gateway (localhost:$PORT)... "
if curl -sf --connect-timeout 5 "http://localhost:$PORT/health" > /dev/null 2>&1; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}UNREACHABLE${NC} (expected if testing remotely)"
fi

# Test 2: Tailscale gateway
if [[ -n "$TAILNET" ]]; then
  FULL_HOST="${GATEWAY_HOST}.${TAILNET}.ts.net"
  echo -n "Tailscale gateway ($FULL_HOST)... "
  if curl -sf --connect-timeout 10 "https://$FULL_HOST/health" > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
  else
    echo -e "${RED}UNREACHABLE${NC}"
    echo "  Check: tailscale status"
    FAILURES=$((FAILURES + 1))
  fi
fi

# Test 3: WebSocket endpoint (requires Tailscale)
if [[ -n "$TAILNET" ]]; then
  if command -v wscat &>/dev/null; then
    echo -n "WebSocket endpoint... "
    if timeout 5 wscat -c "wss://$FULL_HOST" --no-check 2>/dev/null; then
      echo -e "${GREEN}OK${NC}"
    else
      echo -e "${RED}FAILED${NC}"
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo "WebSocket test skipped (install wscat: npm i -g wscat)"
  fi
fi

echo ""
echo "=== Test Complete ($FAILURES failures) ==="
exit $FAILURES
