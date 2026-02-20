#!/bin/bash
# ============================================
# AIOSBot VPS Stack - VPS Installation
# ============================================
# Installs AIOSBot gateway, skills, MCPs, and
# Tailscale on a fresh VPS.
#
# Usage: ssh root@your-vps 'bash -s' < vps/install.sh
#   or:  ./vps/install.sh (when run on the VPS)

set -euo pipefail

INSTALL_DIR="/home/aiosbot"
AIOSBOT_DIR="$INSTALL_DIR/.aiosbot"
WORKSPACE_DIR="$INSTALL_DIR/aiosbot"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INSTALL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Check if running as root or aiosbot user
if [[ "$EUID" -ne 0 ]] && [[ "$(whoami)" != "aiosbot" ]]; then
  error "Run as root or aiosbot user"
fi

log "Starting AIOSBot VPS installation..."

# Step 1: System dependencies
log "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq curl git build-essential screen jq

# Step 2: Node.js (if not installed)
if ! command -v node &>/dev/null; then
  log "Installing Node.js 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
fi
log "Node.js $(node --version) installed"

# Step 3: Create aiosbot user (if not exists)
if ! id -u aiosbot &>/dev/null; then
  log "Creating aiosbot user..."
  useradd -m -s /bin/bash aiosbot
fi

# Step 4: Install AIOSBot (aiosbot)
log "Installing AIOSBot..."
if ! command -v aiosbot &>/dev/null; then
  npm install -g @synkra/aiosbot@latest
fi
log "AIOSBot $(aiosbot --version 2>/dev/null || echo 'installed') ready"

# Step 5: Create directory structure
log "Creating directory structure..."
mkdir -p "$AIOSBOT_DIR"/{skills,memory,credentials,logs,cron,devices}
mkdir -p "$WORKSPACE_DIR"/{memory,logs,life/areas/{people,companies,projects}}

# Step 6: Copy config files (if available in current directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/config/aiosbot.json" ]]; then
  log "Copying gateway config..."
  cp "$SCRIPT_DIR/config/aiosbot.json" "$AIOSBOT_DIR/aiosbot.json"
  chmod 600 "$AIOSBOT_DIR/aiosbot.json"
fi

if [[ -f "$SCRIPT_DIR/config/llm-router-config.yaml" ]]; then
  log "Copying LLM router config..."
  cp "$SCRIPT_DIR/config/llm-router-config.yaml" "$AIOSBOT_DIR/llm-router-config.yaml"
fi

if [[ -f "$SCRIPT_DIR/config/node.json" ]]; then
  log "Copying node config..."
  cp "$SCRIPT_DIR/config/node.json" "$AIOSBOT_DIR/node.json"
fi

# Step 7: Copy workspace files
if [[ -d "$SCRIPT_DIR/workspace" ]]; then
  log "Copying workspace files..."
  for f in "$SCRIPT_DIR/workspace/"*.md; do
    [[ -f "$f" ]] && cp "$f" "$WORKSPACE_DIR/$(basename "$f")"
  done
fi

# Step 8: Copy skills
if [[ -d "$SCRIPT_DIR/skills" ]]; then
  log "Copying skills..."
  cp -r "$SCRIPT_DIR/skills/"* "$AIOSBOT_DIR/skills/" 2>/dev/null || true

  # Install skill dependencies
  if [[ -f "$AIOSBOT_DIR/skills/package.json" ]]; then
    cd "$AIOSBOT_DIR/skills" && npm install --production
  fi
fi

# Step 9: Set permissions
log "Setting permissions..."
chown -R aiosbot:aiosbot "$INSTALL_DIR"
chmod 700 "$AIOSBOT_DIR"
chmod 600 "$AIOSBOT_DIR/aiosbot.json" 2>/dev/null || true

# Step 10: Tailscale (if not installed)
if ! command -v tailscale &>/dev/null; then
  log "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  warn "Run 'tailscale up' to authenticate with your tailnet"
else
  log "Tailscale already installed"
fi

# Step 11: Start gateway
log "Starting AIOSBot gateway..."
if command -v aiosbot &>/dev/null; then
  su - aiosbot -c "screen -dmS aiosbot aiosbot gateway start" 2>/dev/null || \
    warn "Could not start gateway in screen. Start manually: aiosbot gateway start"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  VPS Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Checklist:"
echo "  [ ] Run 'tailscale up' to connect to tailnet"
echo "  [ ] Verify gateway: curl http://localhost:18789/health"
echo "  [ ] Check skills: aiosbot skills list"
echo "  [ ] Test from local: ./tests/test-gateway.sh"
echo ""
echo "Gateway running in screen session 'aiosbot'"
echo "Attach: screen -r aiosbot"
