#!/bin/bash
# ============================================
# AIOSBot VPS Stack - Local Installation
# ============================================
# Sets up the local desktop to connect to the
# remote VPS gateway.
#
# Usage: ./local/install.sh

set -euo pipefail

AIOSBOT_DIR="${HOME}/.aiosbot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INSTALL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

log "Starting local installation..."

# Step 1: Install aiosbot CLI
if ! command -v aiosbot &>/dev/null; then
  log "Installing aiosbot CLI..."
  npm install -g @synkra/aiosbot@latest
fi
log "AIOSBot CLI ready"

# Step 2: Create local directories
log "Creating local directories..."
mkdir -p "$AIOSBOT_DIR"/{agents,credentials,identity,memory}

# Step 3: Copy local config
if [[ -f "$SCRIPT_DIR/config/aiosbot.json" ]]; then
  log "Copying local gateway config..."
  cp "$SCRIPT_DIR/config/aiosbot.json" "$AIOSBOT_DIR/aiosbot.json"
  chmod 600 "$AIOSBOT_DIR/aiosbot.json"
else
  warn "No aiosbot.json found. Run setup.sh first."
fi

if [[ -f "$SCRIPT_DIR/config/node.json" ]]; then
  log "Copying node config..."
  cp "$SCRIPT_DIR/config/node.json" "$AIOSBOT_DIR/node.json"
fi

# Step 4: Copy bridge
if [[ -f "$SCRIPT_DIR/bridge/bridge.js" ]]; then
  log "Installing bridge..."
  mkdir -p "$AIOSBOT_DIR/bridge"
  cp "$SCRIPT_DIR/bridge/bridge.js" "$AIOSBOT_DIR/bridge/bridge.js"
fi

# Step 5: Copy skills config
if [[ -d "$SCRIPT_DIR/skills" ]]; then
  log "Copying skills config..."
  mkdir -p "$AIOSBOT_DIR/skills"
  cp "$SCRIPT_DIR/skills/"* "$AIOSBOT_DIR/skills/" 2>/dev/null || true
fi

# Step 6: Install hooks (optional)
if [[ -f "$SCRIPT_DIR/hooks/session-start.sh" ]]; then
  log "Installing session hook..."
  mkdir -p "${HOME}/.claude/hooks"
  cp "$SCRIPT_DIR/hooks/session-start.sh" "${HOME}/.claude/hooks/session-start.sh"
  chmod +x "${HOME}/.claude/hooks/session-start.sh"
fi

# Step 7: Tailscale check
if command -v tailscale &>/dev/null; then
  log "Tailscale detected"
  TAILSCALE_STATUS=$(tailscale status 2>/dev/null | head -1 || echo "unknown")
  log "Status: $TAILSCALE_STATUS"
else
  warn "Tailscale not installed. Install from https://tailscale.com/download"
fi

# Step 8: Test connection
log "Testing VPS connection..."
if [[ -f "$AIOSBOT_DIR/aiosbot.json" ]]; then
  GATEWAY_URL=$(cd "$AIOSBOT_DIR" && node -e "const c=require('./aiosbot.json'); console.log(c.gateway?.remote?.url || 'not-configured')" 2>/dev/null || echo "error")
  if [[ "$GATEWAY_URL" != "not-configured" ]] && [[ "$GATEWAY_URL" != "error" ]]; then
    log "Gateway URL: $GATEWAY_URL"
  else
    warn "Gateway URL not configured in aiosbot.json"
  fi
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Local Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Test your connection:"
echo "  aiosbot doctor"
echo "  aiosbot status"
echo ""
echo "If using Tailscale, ensure you're connected:"
echo "  tailscale status"
