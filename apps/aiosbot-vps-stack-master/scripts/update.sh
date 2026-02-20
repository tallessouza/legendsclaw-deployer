#!/bin/bash
# ============================================
# Update AIOSBot - Keep configs
# ============================================
# Updates AIOSBot to the latest version while
# preserving your configuration files.
#
# Usage: ./scripts/update.sh

set -euo pipefail

AIOSBOT_DIR="${HOME}/.aiosbot"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[UPDATE]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

log "Backing up current configuration..."

BACKUP_DIR="$AIOSBOT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
for f in aiosbot.json node.json llm-router-config.yaml; do
  if [[ -f "$AIOSBOT_DIR/$f" ]]; then
    cp "$AIOSBOT_DIR/$f" "$BACKUP_DIR/$f"
    log "Backed up $f"
  fi
done

log "Updating aiosbot CLI..."
npm install -g @synkra/aiosbot@latest

log "Verifying update..."
aiosbot --version 2>/dev/null || warn "Could not verify version"

log "Configuration preserved in: $BACKUP_DIR"

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo "Run 'aiosbot doctor' to verify."
