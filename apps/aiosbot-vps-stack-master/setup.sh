#!/bin/bash
# ============================================
# AIOSBot VPS Stack - Interactive Setup
# ============================================
# This script collects configuration values and
# substitutes them in all template files.
#
# Usage: ./setup.sh [--dry-run]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] No files will be modified."
fi

echo "============================================"
echo "  AIOSBot VPS Stack - Setup Wizard"
echo "============================================"
echo ""

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

prompt() {
  local var_name="$1"
  local prompt_text="$2"
  local default="${3:-}"

  if [[ -n "$default" ]]; then
    printf "${BLUE}%s${NC} [${YELLOW}%s${NC}]: " "$prompt_text" "$default"
  else
    printf "${BLUE}%s${NC}: " "$prompt_text"
  fi

  read -r value
  value="${value:-$default}"

  if [[ -z "$value" ]]; then
    echo -e "${RED}Error: $var_name is required.${NC}"
    exit 1
  fi

  printf -v "$var_name" '%s' "$value"
}

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"

  printf "${BLUE}%s${NC}: " "$prompt_text"
  read -rs value
  echo ""

  if [[ -z "$value" ]]; then
    echo -e "${YELLOW}Warning: $var_name left empty. Set it in .env later.${NC}"
    value=""
  fi

  printf -v "$var_name" '%s' "$value"
}

echo -e "${GREEN}=== Identity ===${NC}"
prompt ORG_NAME "Organization name" "MyOrg"
prompt USER_NAME "Your full name"
prompt USER_NICKNAME "What should the AI call you?"
prompt USER_PRONOUNS "Your pronouns" "he/him"
prompt AGENT_NAME "AI agent name" "Assistant"
prompt AGENT_EMOJI "Agent emoji" "🤖"
prompt PRIMARY_CHANNEL "Primary communication channel" "WhatsApp"

echo ""
echo -e "${GREEN}=== VPS Configuration ===${NC}"
prompt VPS_IP "VPS IP address"
prompt GATEWAY_HOSTNAME "Gateway hostname (Tailscale)" "my-gateway"
prompt TAILNET_ID "Tailscale tailnet ID"
prompt VPS_NODE_NAME "VPS node display name" "VPS-Server"
prompt LOCAL_NODE_NAME "Local node display name" "Local-Desktop"
prompt WORKSPACE_PATH "Workspace path on VPS" "/home/aiosbot/workspace"

echo ""
echo -e "${GREEN}=== Security ===${NC}"
prompt_secret GATEWAY_PASSWORD "Gateway password (min 12 chars)"
prompt_secret HOOKS_TOKEN "Hooks webhook token"

echo ""
echo -e "${GREEN}=== Locale ===${NC}"
prompt TIMEZONE "Timezone" "UTC"
prompt LOCALE "Language/locale" "en-US"
prompt TTS_VOICE "TTS voice" "en-US-GuyNeural"

echo ""
echo -e "${GREEN}=== Optional Integrations ===${NC}"
prompt_secret OPENROUTER_API_KEY "OpenRouter API Key (optional)"
prompt_secret ANTHROPIC_ADMIN_KEY "Anthropic Admin Key (optional)"
prompt_secret OPENAI_API_KEY "OpenAI API Key (optional)"
prompt_secret GEMINI_API_KEY "Gemini API Key (optional)"
prompt_secret BRAVE_API_KEY "Brave Search API Key (optional)"
prompt_secret SUPABASE_URL "Supabase URL (optional)"
prompt_secret SUPABASE_ANON_KEY "Supabase Anon Key (optional)"
prompt_secret SUPABASE_SERVICE_ROLE_KEY "Supabase Service Role Key (optional)"

echo ""
echo -e "${GREEN}=== Database (Optional) ===${NC}"
prompt_secret ASSEMBLYAI_API_KEY "AssemblyAI API Key (optional)"
prompt SUPABASE_PROJECT_REF "Supabase Project Ref (optional)" ""
prompt_secret SUPABASE_DB_PASSWORD "Supabase DB Password (optional)"
prompt DATABASE_URL "Database URL (optional)" ""
prompt POSTGRES_HOST "Postgres Host (optional)" ""
prompt POSTGRES_PORT "Postgres Port (optional)" "5432"
prompt POSTGRES_USER "Postgres User (optional)" "postgres"
prompt POSTGRES_DB "Postgres DB (optional)" "postgres"

echo ""
echo -e "${GREEN}=== Optional Services ===${NC}"
prompt CLICKUP_TEAM_ID "ClickUp Team ID (optional)" ""
prompt N8N_WEBHOOK_URL "N8N Webhook URL (optional)" ""
prompt WHATSAPP_ADMIN_PHONE "WhatsApp admin phone (optional)" ""
prompt MEMORY_PATH "Memory base path" "$WORKSPACE_PATH/memory"

echo ""
echo -e "${GREEN}=== Generating configuration files ===${NC}"

# Function to substitute placeholders in a file
substitute_file() {
  local template="$1"
  local output="${template%.template}"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would process: $template → $output"
    return
  fi

  cp "$template" "$output"

  # Replace all placeholders
  sed -i "s|{{ORG_NAME}}|${ORG_NAME}|g" "$output"
  sed -i "s|{{USER_NAME}}|${USER_NAME}|g" "$output"
  sed -i "s|{{USER_NICKNAME}}|${USER_NICKNAME}|g" "$output"
  sed -i "s|{{USER_PRONOUNS}}|${USER_PRONOUNS}|g" "$output"
  sed -i "s|{{AGENT_NAME}}|${AGENT_NAME}|g" "$output"
  sed -i "s|{{AGENT_EMOJI}}|${AGENT_EMOJI}|g" "$output"
  sed -i "s|{{PRIMARY_CHANNEL}}|${PRIMARY_CHANNEL}|g" "$output"
  sed -i "s|{{VPS_IP}}|${VPS_IP}|g" "$output"
  sed -i "s|{{GATEWAY_HOSTNAME}}|${GATEWAY_HOSTNAME}|g" "$output"
  sed -i "s|{{TAILNET_ID}}|${TAILNET_ID}|g" "$output"
  sed -i "s|{{VPS_NODE_NAME}}|${VPS_NODE_NAME}|g" "$output"
  sed -i "s|{{LOCAL_NODE_NAME}}|${LOCAL_NODE_NAME}|g" "$output"
  sed -i "s|{{WORKSPACE_PATH}}|${WORKSPACE_PATH}|g" "$output"
  sed -i "s|{{GATEWAY_PASSWORD}}|${GATEWAY_PASSWORD}|g" "$output"
  sed -i "s|{{HOOKS_TOKEN}}|${HOOKS_TOKEN}|g" "$output"
  sed -i "s|{{TIMEZONE}}|${TIMEZONE}|g" "$output"
  sed -i "s|{{LOCALE}}|${LOCALE}|g" "$output"
  sed -i "s|{{TTS_VOICE}}|${TTS_VOICE}|g" "$output"
  sed -i "s|{{OPENROUTER_API_KEY}}|${OPENROUTER_API_KEY}|g" "$output"
  sed -i "s|{{ANTHROPIC_ADMIN_KEY}}|${ANTHROPIC_ADMIN_KEY}|g" "$output"
  sed -i "s|{{OPENAI_API_KEY}}|${OPENAI_API_KEY}|g" "$output"
  sed -i "s|{{GEMINI_API_KEY}}|${GEMINI_API_KEY}|g" "$output"
  sed -i "s|{{BRAVE_API_KEY}}|${BRAVE_API_KEY}|g" "$output"
  sed -i "s|{{SUPABASE_URL}}|${SUPABASE_URL}|g" "$output"
  sed -i "s|{{SUPABASE_ANON_KEY}}|${SUPABASE_ANON_KEY}|g" "$output"
  sed -i "s|{{SUPABASE_SERVICE_ROLE_KEY}}|${SUPABASE_SERVICE_ROLE_KEY}|g" "$output"
  sed -i "s|{{ASSEMBLYAI_API_KEY}}|${ASSEMBLYAI_API_KEY}|g" "$output"
  sed -i "s|{{SUPABASE_PROJECT_REF}}|${SUPABASE_PROJECT_REF}|g" "$output"
  sed -i "s|{{SUPABASE_DB_PASSWORD}}|${SUPABASE_DB_PASSWORD}|g" "$output"
  sed -i "s|{{DATABASE_URL}}|${DATABASE_URL}|g" "$output"
  sed -i "s|{{POSTGRES_HOST}}|${POSTGRES_HOST}|g" "$output"
  sed -i "s|{{POSTGRES_PORT}}|${POSTGRES_PORT}|g" "$output"
  sed -i "s|{{POSTGRES_USER}}|${POSTGRES_USER}|g" "$output"
  sed -i "s|{{POSTGRES_DB}}|${POSTGRES_DB}|g" "$output"
  sed -i "s|{{CLICKUP_TEAM_ID}}|${CLICKUP_TEAM_ID}|g" "$output"
  sed -i "s|{{N8N_WEBHOOK_URL}}|${N8N_WEBHOOK_URL}|g" "$output"
  sed -i "s|{{WHATSAPP_ADMIN_PHONE}}|${WHATSAPP_ADMIN_PHONE}|g" "$output"
  sed -i "s|{{MEMORY_PATH}}|${MEMORY_PATH}|g" "$output"
  sed -i "s|{{AUTO_GENERATED}}|$(date -u +%Y-%m-%dT%H:%M:%S.000Z)|g" "$output"
  sed -i "s|{{AUTO_GENERATED_UUID}}|$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$(shuf -i 1000-9999 -n 1)")|g" "$output"

  echo -e "  ${GREEN}✓${NC} $output"
}

# Generate .env from collected values
generate_env() {
  local env_file="$REPO_DIR/.env"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would generate: $env_file"
    return
  fi

  cat > "$env_file" << EOF
# AIOSBot VPS Stack - Environment Configuration
# Generated by setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Identity
ORG_NAME=${ORG_NAME}
USER_NAME=${USER_NAME}
AGENT_NAME=${AGENT_NAME}

# VPS
VPS_IP=${VPS_IP}
GATEWAY_HOSTNAME=${GATEWAY_HOSTNAME}
TAILNET_ID=${TAILNET_ID}
GATEWAY_PASSWORD=${GATEWAY_PASSWORD}
HOOKS_TOKEN=${HOOKS_TOKEN}

# Locale
TIMEZONE=${TIMEZONE}
LOCALE=${LOCALE}

# API Keys
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
ANTHROPIC_ADMIN_KEY=${ANTHROPIC_ADMIN_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}
BRAVE_API_KEY=${BRAVE_API_KEY}

# Supabase
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
SUPABASE_PROJECT_REF=${SUPABASE_PROJECT_REF}
SUPABASE_DB_PASSWORD=${SUPABASE_DB_PASSWORD}

# Database
DATABASE_URL=${DATABASE_URL}
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_PORT=${POSTGRES_PORT}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_DB=${POSTGRES_DB}

# Additional API Keys
ASSEMBLYAI_API_KEY=${ASSEMBLYAI_API_KEY}

# Services
CLICKUP_TEAM_ID=${CLICKUP_TEAM_ID}
N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}
WHATSAPP_ADMIN_PHONE=${WHATSAPP_ADMIN_PHONE}
MEMORY_PATH=${MEMORY_PATH}
EOF

  chmod 600 "$env_file"
  echo -e "  ${GREEN}✓${NC} .env generated (permissions: 600)"
}

# Process all template files
echo "Processing templates..."
find "$REPO_DIR" -name "*.template" | while read -r template; do
  substitute_file "$template"
done

echo ""
echo "Generating .env file..."
generate_env

echo ""
echo "Validating configuration..."
if [[ "$DRY_RUN" == false ]]; then
  if bash "$REPO_DIR/scripts/validate-config.sh"; then
    echo ""
  else
    echo ""
    echo -e "${RED}Configuration validation failed. Please fix the issues above.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Review generated files in vps/ and local/"
echo "  2. Run: ./vps/install.sh    (on your VPS)"
echo "  3. Run: ./local/install.sh  (on your desktop)"
echo "  4. Run: ./scripts/validate.sh (verify everything)"
echo ""
echo -e "${YELLOW}Important: .env contains secrets — never commit it!${NC}"
