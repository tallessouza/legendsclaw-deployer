#!/bin/bash
# AIOSBot Session Start Hook
# Connects local Claude Code to the VPS gateway on session start.
#
# Install: Add to your Claude Code hooks configuration
# Path: ~/.claude/hooks/session-start.sh

set -euo pipefail

BRIDGE_PATH="${AIOSBOT_BRIDGE_PATH:-$HOME/.aiosbot/bridge/bridge.js}"
LOG_DIR="${AIOSBOT_LOG_DIR:-$HOME/.aiosbot/logs}"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_DIR/session-hook.log"
}

log "Session started"

# Verify bridge is accessible
if [ -f "$BRIDGE_PATH" ]; then
  log "Bridge found at $BRIDGE_PATH"

  # Run status check
  STATUS=$(node "$BRIDGE_PATH" status 2>/dev/null || echo '{"error": "bridge unreachable"}')
  log "Bridge status: $STATUS"
else
  log "WARNING: Bridge not found at $BRIDGE_PATH"
fi

# Verify gateway connectivity
GATEWAY_HOST="${AIOSBOT_GATEWAY_HOST:-}"
if [ -n "$GATEWAY_HOST" ]; then
  if curl -s --connect-timeout 5 "https://$GATEWAY_HOST/health" > /dev/null 2>&1; then
    log "Gateway reachable at $GATEWAY_HOST"
  else
    log "WARNING: Gateway unreachable at $GATEWAY_HOST"
  fi
fi

echo "AIOSBot session initialized"
