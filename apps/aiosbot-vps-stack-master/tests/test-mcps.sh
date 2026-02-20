#!/bin/bash
# Test MCP servers
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0

echo "=== MCP Server Test ==="

# Check mcporter
if command -v aiosbot &>/dev/null; then
  echo "MCP servers via aiosbot:"
  aiosbot mcp list 2>/dev/null || echo -e "  ${YELLOW}aiosbot mcp not available${NC}"
else
  echo -e "${YELLOW}aiosbot not installed — skipping MCP test${NC}"
fi

# Check MCP config directory
MCP_CONFIG_DIR="${HOME}/.aiosbot/skills/mcp-config"
if [[ -d "$MCP_CONFIG_DIR" ]]; then
  echo ""
  echo "MCP config directory: $MCP_CONFIG_DIR"
  ls -la "$MCP_CONFIG_DIR/" 2>/dev/null
else
  echo -e "${YELLOW}MCP config directory not found${NC}"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "=== Test Complete ($FAILURES failures) ==="
exit $FAILURES
