#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 14: Gateway Config (Consolidacao)
# Story 7.4: Consolida dados de todas as ferramentas e gera artefatos finais
# Artefatos: aiosbot.json, node.json, .env, mcp-config.json
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/auto.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "gateway-config"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init 13

# =============================================================================
# STEP 2: CARREGAR DADOS OBRIGATORIOS
# =============================================================================
dados

# Dados obrigatorios — sem eles, nao ha como gerar configs
REQUIRED_FILES=("dados_openclaw" "dados_whitelabel" "dados_workspace" "dados_llm_router")
for req in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$STATE_DIR/$req" ]]; then
    step_fail "$req ausente em $STATE_DIR — execute a ferramenta correspondente primeiro"
    exit 1
  fi
done

# Extrair campos obrigatorios
nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}' || true)
display_name=$(grep "Display Name:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}' || true)
idioma=$(grep "Idioma:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}' || true)
apps_path=$(grep "Apps Path:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
apps_path="${apps_path:-apps/${nome_agente}}"

openclaw_porta=$(grep "Porta:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}' || true)
openclaw_porta="${openclaw_porta:-18789}"

workspace_path=$(grep "Workspace Path:" "$STATE_DIR/dados_workspace" 2>/dev/null | awk -F': ' '{print $2}' || true)
workspace_path="${workspace_path:-${apps_path}/workspace}"

if [[ -z "$nome_agente" ]]; then
  step_fail "Nome do agente nao encontrado em dados_whitelabel"
  exit 1
fi

step_ok "Dados obrigatorios carregados (${nome_agente})"

# =============================================================================
# STEP 3: CARREGAR DADOS OPCIONAIS (graceful skip)
# =============================================================================
OPTIONAL_FILES=("dados_vps" "dados_portainer" "dados_tailscale" "dados_skills" "dados_seguranca" "dados_evolution" "dados_bridge" "dados_elicitation" "dados_postgres")
loaded_optional=0
skipped_optional=0

# Tailscale
ts_hostname=""
ts_ip=""
ts_tailnet=""
if [[ -f "$STATE_DIR/dados_tailscale" ]]; then
  ts_hostname=$(grep "Hostname Tailscale:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ts_ip=$(grep "IP Tailscale:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ts_tailnet=$(grep "Tailnet:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# Evolution (WhatsApp)
evo_url=""
evo_api_key=""
evo_instance=""
whatsapp_admin_phone=""
has_evolution="false"
if [[ -f "$STATE_DIR/dados_evolution" ]]; then
  evo_url=$(grep "Evolution URL:" "$STATE_DIR/dados_evolution" 2>/dev/null | awk -F': ' '{print $2}' || true)
  evo_api_key=$(grep "API Key:" "$STATE_DIR/dados_evolution" 2>/dev/null | awk -F': ' '{print $2}' || true)
  evo_instance=$(grep "Instance:" "$STATE_DIR/dados_evolution" 2>/dev/null | awk -F': ' '{print $2}' || true)
  has_evolution="true"
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# Seguranca
blocklist_path=""
has_seguranca="false"
if [[ -f "$STATE_DIR/dados_seguranca" ]]; then
  blocklist_path=$(grep "Blocklist:" "$STATE_DIR/dados_seguranca" 2>/dev/null | awk -F': ' '{print $2}' || true)
  has_seguranca="true"
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# LLM Router — API keys
openrouter_key=$(grep "OPENROUTER_API_KEY:" "$STATE_DIR/dados_llm_router" 2>/dev/null | awk -F': ' '{print $2}' || true)
anthropic_key=$(grep "ANTHROPIC_ADMIN_KEY:" "$STATE_DIR/dados_llm_router" 2>/dev/null | awk -F': ' '{print $2}' || true)
openai_key=$(grep "OPENAI_API_KEY:" "$STATE_DIR/dados_llm_router" 2>/dev/null | awk -F': ' '{print $2}' || true)
gemini_key=$(grep "GEMINI_API_KEY:" "$STATE_DIR/dados_llm_router" 2>/dev/null | awk -F': ' '{print $2}' || true)
brave_key=$(grep "BRAVE_API_KEY:" "$STATE_DIR/dados_llm_router" 2>/dev/null | awk -F': ' '{print $2}' || true)
default_tier=$(grep "Default Tier:" "$STATE_DIR/dados_llm_router" 2>/dev/null | awk -F': ' '{print $2}' || true)
default_tier="${default_tier:-standard}"

# Elicitation
user_name=""
user_timezone=""
supabase_url=""
supabase_anon_key=""
supabase_service_key=""
supabase_project_ref=""
supabase_db_password=""
database_url=""
if [[ -f "$STATE_DIR/dados_elicitation" ]]; then
  user_name=$(grep "User Name:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  user_timezone=$(grep "Timezone:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  supabase_url=$(grep "SUPABASE_URL:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  supabase_anon_key=$(grep "SUPABASE_ANON_KEY:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  supabase_service_key=$(grep "SUPABASE_SERVICE_ROLE_KEY:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  supabase_project_ref=$(grep "SUPABASE_PROJECT_REF:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  supabase_db_password=$(grep "SUPABASE_DB_PASSWORD:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  database_url=$(grep "DATABASE_URL:" "$STATE_DIR/dados_elicitation" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# VPS (nome_servidor para node.json displayName — AC 8)
nome_servidor=""
if [[ -f "$STATE_DIR/dados_vps" ]]; then
  nome_servidor=$(grep "Nome do Servidor:" "$STATE_DIR/dados_vps" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# Portainer
portainer_url=""
if [[ -f "$STATE_DIR/dados_portainer" ]]; then
  portainer_url=$(grep "Portainer URL:" "$STATE_DIR/dados_portainer" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# Bridge
has_bridge="false"
if [[ -f "$STATE_DIR/dados_bridge" ]]; then
  has_bridge="true"
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# Skills
skills_ativas=""
if [[ -f "$STATE_DIR/dados_skills" ]]; then
  skills_ativas=$(grep "Skills Ativas:" "$STATE_DIR/dados_skills" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ((loaded_optional++)) || true || true
else
  ((skipped_optional++)) || true || true
fi

# Postgres
postgres_host=""
postgres_port=""
postgres_user=""
postgres_db=""
if [[ -f "$STATE_DIR/dados_postgres" ]]; then
  postgres_host=$(grep "Host:" "$STATE_DIR/dados_postgres" 2>/dev/null | awk -F': ' '{print $2}' || true)
  postgres_port=$(grep "Port:" "$STATE_DIR/dados_postgres" 2>/dev/null | awk -F': ' '{print $2}' || true)
  postgres_user=$(grep "User:" "$STATE_DIR/dados_postgres" 2>/dev/null | awk -F': ' '{print $2}' || true)
  postgres_db=$(grep "DB:" "$STATE_DIR/dados_postgres" 2>/dev/null | awk -F': ' '{print $2}' || true)
  ((loaded_optional++)) || true || true
fi

step_ok "Dados opcionais: ${loaded_optional} carregados, ${skipped_optional} skipped"

# =============================================================================
# STEP 4: COLETAR INPUTS FALTANTES
# =============================================================================

# ORG_NAME
org_name="$display_name"

# Gateway password — gerar automaticamente
gateway_password=$(openssl rand -base64 32 2>/dev/null || cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)

# Hooks token — gerar automaticamente
hooks_token=$(openssl rand -hex 24 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c 48)

# WhatsApp admin phone
if [[ "$has_evolution" == "true" && -z "$whatsapp_admin_phone" ]]; then
  echo ""
  input "gateway_config.whatsapp_admin_phone" "Numero WhatsApp admin (ex: 5511999999999): " whatsapp_admin_phone --required
fi

# Timezone fallback
user_timezone="${user_timezone:-America/Sao_Paulo}"

conferindo_as_info \
  "Agente=${nome_agente}" \
  "Org=${org_name}" \
  "Gateway Port=${openclaw_porta}" \
  "Gateway Password=[GERADO]" \
  "Hooks Token=[GERADO]" \
  "Tailscale=${ts_hostname:-N/A}" \
  "WhatsApp=${whatsapp_admin_phone:-N/A}" \
  "Evolution=${has_evolution}" \
  "Seguranca=${has_seguranca}"

auto_confirm "As informacoes estao corretas? (s/n): " confirma
if [[ ! "$confirma" =~ ^[Ss]$ ]]; then
  step_fail "Cancelado pelo usuario"
  exit 1
fi

step_ok "Inputs coletados e confirmados"

# =============================================================================
# STEP 5: PREPARAR DIRETORIOS
# =============================================================================
CONFIG_DIR="${apps_path}/config"
MCP_DIR="${apps_path}/mcps"
ENV_DIR="${apps_path}"

mkdir -p "$CONFIG_DIR"
mkdir -p "$MCP_DIR"

step_ok "Diretorios preparados: ${CONFIG_DIR}/, ${MCP_DIR}/"

# =============================================================================
# STEP 6: BACKUP DE CONFIGS ANTERIORES
# =============================================================================
backup_count=0
for cfg_file in "$CONFIG_DIR/aiosbot.json" "$CONFIG_DIR/node.json" "$ENV_DIR/.env" "$MCP_DIR/mcp-config.json"; do
  if [[ -f "$cfg_file" ]]; then
    cp "$cfg_file" "${cfg_file}.bak"
    ((backup_count++))
  fi
done

if [[ $backup_count -gt 0 ]]; then
  step_ok "Backup criado para ${backup_count} config(s) existente(s)"
else
  step_skip "Nenhum config anterior encontrado — primeiro deploy"
fi

# =============================================================================
# STEP 7: GERAR aiosbot.json VIA NODE
# =============================================================================

# Ler denyPatterns customizados ou usar defaults
DENY_PATTERNS_JSON='["rm -rf /","rm -rf /*","mkfs\\\\.","dd if=/dev",":\\\\(\\\\)\\\\{\\\\s*:\\\\|:\\\\&\\\\s*\\\\};:","shutdown","reboot","> /dev/sd","chmod -R 777 /","wget .* \\\\| sh","curl .* \\\\| sh","wget .* \\\\| bash","curl .* \\\\| bash","rm -rf ~","rm -rf \\\\$HOME"]'
if [[ "$has_seguranca" == "true" && -n "$blocklist_path" && -f "$blocklist_path" ]]; then
  # Ler blocklist customizada e converter para JSON array
  DENY_PATTERNS_JSON=$(while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    printf '%s\n' "$line"
  done < "$blocklist_path" | node -e "
    const lines = require('fs').readFileSync('/dev/stdin','utf8').trim().split('\n').filter(Boolean);
    console.log(JSON.stringify(lines));
  " 2>/dev/null || echo "$DENY_PATTERNS_JSON")
fi

# Determinar gateway host
if [[ -n "$ts_hostname" && -n "$ts_tailnet" ]]; then
  gateway_host="${ts_hostname}.${ts_tailnet}.ts.net"
  ts_mode="funnel"
else
  gateway_host="localhost"
  ts_mode="off"
fi

# Gerar aiosbot.json programaticamente via Node.js
OPENROUTER_KEY="$openrouter_key" \
ANTHROPIC_KEY="$anthropic_key" \
OPENAI_KEY="$openai_key" \
GEMINI_KEY="$gemini_key" \
BRAVE_KEY="$brave_key" \
SUPABASE_URL_VAL="$supabase_url" \
SUPABASE_SERVICE_KEY="$supabase_service_key" \
SUPABASE_PROJECT_REF_VAL="$supabase_project_ref" \
SUPABASE_DB_PASS="$supabase_db_password" \
SUPABASE_ANON="$supabase_anon_key" \
DATABASE_URL_VAL="$database_url" \
POSTGRES_HOST_VAL="$postgres_host" \
POSTGRES_PORT_VAL="$postgres_port" \
POSTGRES_USER_VAL="$postgres_user" \
POSTGRES_DB_VAL="$postgres_db" \
WORKSPACE_PATH="$workspace_path" \
GATEWAY_PORT="$openclaw_porta" \
GATEWAY_PASSWORD="$gateway_password" \
HOOKS_TOKEN="$hooks_token" \
ORG_NAME="$org_name" \
AGENT_NAME="$nome_agente" \
WHATSAPP_PHONE="$whatsapp_admin_phone" \
HAS_EVOLUTION="$has_evolution" \
TS_MODE="$ts_mode" \
LOCAL_NODE="$nome_agente" \
DENY_PATTERNS="$DENY_PATTERNS_JSON" \
OUTPUT_PATH="$CONFIG_DIR/aiosbot.json" \
node -e '
const fs = require("fs");
const e = process.env;

const config = {
  meta: {
    lastTouchedVersion: "2026.1.24-3",
    lastTouchedAt: new Date().toISOString()
  },
  env: { vars: {} },
  wizard: {
    lastRunAt: new Date().toISOString(),
    lastRunVersion: "2026.1.24-3",
    lastRunCommand: "deployer",
    lastRunMode: "vps"
  },
  browser: {
    enabled: true,
    headless: true,
    defaultProfile: "server",
    profiles: { server: { cdpUrl: "http://localhost:3000", color: "#00AA00" } }
  },
  models: {
    mode: "merge",
    providers: {
      "anthropic-router": {
        baseUrl: "http://localhost:55119/v1",
        apiKey: "dummy",
        api: "openai-completions",
        models: [{
          id: "router-auto",
          name: "Anthropic Smart Router (Auto)",
          reasoning: false,
          input: ["text"],
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          contextWindow: 200000,
          maxTokens: 8192
        }]
      }
    }
  },
  agents: {
    defaults: {
      model: {
        primary: "anthropic-router/router-auto",
        fallbacks: [
          "anthropic/claude-sonnet-4",
          "openrouter/anthropic/claude-3.5-haiku",
          "openrouter/google/gemini-3-flash-preview"
        ]
      },
      models: {
        "anthropic-router/router-auto": { alias: "smart" }
      },
      workspace: e.WORKSPACE_PATH,
      memorySearch: {
        enabled: true,
        sources: ["memory", "sessions"],
        experimental: { sessionMemory: true },
        provider: "gemini"
      },
      contextPruning: { mode: "cache-ttl", ttl: "1h" },
      compaction: {
        mode: "safeguard",
        memoryFlush: {
          enabled: true,
          softThresholdTokens: 4000,
          prompt: "Pre-compaction memory flush. Analyze this session and extract memory-worthy information.\n\n## Phase 1: Observation Masking (Mental Filter)\nBefore extracting, mentally filter out:\n- Routine tool calls (file reads, git status, simple confirmations)\n- Greetings and small talk\n- Repetitive information already extracted\n- Debug outputs and logs\n- Messages with low information density\n\nFocus ONLY on high-signal messages.\n\n## Phase 2: Extract by Priority\n\n### HIGH Priority - User Corrections & Rules\n- User corrections to AI behavior\n- Explicit rules (NUNCA, SEMPRE, CRITICAL)\n- Preferences stated\nFormat: \"RULE: [behavior]\" or \"PREF: [preference]\"\n\n### MEDIUM Priority - Decisions & Patterns\n- Architectural decisions with rationale\n- Reusable patterns\n- Project updates\nFormat: \"DECISION: [what] because [why]\" or \"PATTERN: [description]\"\n\n### LOW Priority - Learnings & Facts\n- Errors fixed and lessons\n- New information about entities\nFormat: \"LESSON: [learning]\" or \"FACT: [entity] - [fact]\"\n\n## Phase 3: Output\nWrite to memory/YYYY-MM-DD.md\n\n## Rules\n1. Observation Masking FIRST\n2. Be CONCISE - 1-2 lines per item max\n3. Check duplicates\n4. Entity linking",
          systemPrompt: "Pre-compaction memory flush V2 with Observation Masking.\nProcess: FILTER > SCORE > EXTRACT > PERSIST\nBe aggressive about filtering. Most sessions have 1-3 meaningful items max."
        }
      },
      heartbeat: { every: "30m", model: "google/gemini-3-flash-preview" },
      maxConcurrent: 4,
      maxIterations: 25,
      subagents: {
        maxConcurrent: 8,
        maxIterations: 15,
        archiveAfterMinutes: 30,
        model: "google/gemini-3-flash-preview"
      },
      sandbox: { mode: "off" }
    },
    list: []
  },
  tools: {
    shell: { denyPatterns: JSON.parse(e.DENY_PATTERNS) },
    filesystem: {
      restrictToWorkspace: true,
      allowedPaths: [
        e.WORKSPACE_PATH,
        "/home/aiosbot/.aiosbot/skills",
        "/home/aiosbot/.aiosbot/memory"
      ]
    },
    web: {
      search: { enabled: true, provider: "brave", maxResults: 5, cacheTtlMinutes: 15 },
      fetch: { enabled: true, maxChars: 50000 }
    },
    media: {
      audio: {
        enabled: true,
        models: [{ provider: "google", model: "gemini-2.5-flash", capabilities: ["audio"] }]
      },
      video: {
        enabled: true,
        maxChars: 500,
        models: [{ provider: "google", model: "gemini-2.5-flash", capabilities: ["video"] }]
      }
    }
  },
  bindings: [],
  messages: {
    ackReactionScope: "group-mentions",
    tts: {
      auto: "off",
      provider: "edge",
      edge: { enabled: true, voice: "pt-BR-AntonioNeural" }
    }
  },
  commands: { native: "auto", nativeSkills: "auto" },
  hooks: {
    enabled: true,
    path: "/hooks",
    token: e.HOOKS_TOKEN,
    internal: {
      enabled: true,
      entries: {
        "session-memory": { enabled: false },
        "session-digest": { enabled: false }
      }
    }
  },
  channels: {
    telegram: {
      dmPolicy: "allowlist",
      groupPolicy: "allowlist",
      streamMode: "partial",
      accounts: {}
    }
  },
  gateway: {
    port: parseInt(e.GATEWAY_PORT) || 18789,
    mode: "local",
    bind: "loopback",
    auth: { mode: "password", password: e.GATEWAY_PASSWORD },
    trustedProxies: ["127.0.0.1", "::1"],
    tailscale: { mode: e.TS_MODE, resetOnExit: false },
    nodes: { browser: { mode: "auto", node: e.LOCAL_NODE } }
  },
  skills: { install: { nodeManager: "npm" }, entries: {} },
  plugins: { entries: { telegram: { enabled: false } } }
};

// === Env vars condicionais ===
const envVars = config.env.vars;
if (e.GEMINI_KEY) envVars.GEMINI_API_KEY = e.GEMINI_KEY;
if (e.SUPABASE_URL_VAL) envVars.SUPABASE_URL = e.SUPABASE_URL_VAL;
if (e.SUPABASE_SERVICE_KEY) envVars.SUPABASE_SERVICE_ROLE_KEY = e.SUPABASE_SERVICE_KEY;
if (e.SUPABASE_PROJECT_REF_VAL) envVars.SUPABASE_PROJECT_REF = e.SUPABASE_PROJECT_REF_VAL;
if (e.SUPABASE_DB_PASS) envVars.SUPABASE_DB_PASSWORD = e.SUPABASE_DB_PASS;
if (e.DATABASE_URL_VAL) envVars.DATABASE_URL = e.DATABASE_URL_VAL;
if (e.POSTGRES_HOST_VAL) envVars.POSTGRES_HOST = e.POSTGRES_HOST_VAL;
if (e.POSTGRES_PORT_VAL) envVars.POSTGRES_PORT = e.POSTGRES_PORT_VAL;
if (e.POSTGRES_USER_VAL) envVars.POSTGRES_USER = e.POSTGRES_USER_VAL;
if (e.POSTGRES_DB_VAL) envVars.POSTGRES_DB = e.POSTGRES_DB_VAL;
if (e.OPENROUTER_KEY) envVars.OPENROUTER_API_KEY = e.OPENROUTER_KEY;
if (e.SUPABASE_ANON) envVars.SUPABASE_ANON_KEY = e.SUPABASE_ANON;
if (e.BRAVE_KEY) envVars.BRAVE_API_KEY = e.BRAVE_KEY;
if (e.ANTHROPIC_KEY) envVars.ANTHROPIC_ADMIN_KEY = e.ANTHROPIC_KEY;
if (e.OPENAI_KEY) envVars.OPENAI_API_KEY = e.OPENAI_KEY;

// === Model aliases condicionais ===
const models = config.agents.defaults.models;
if (e.ANTHROPIC_KEY) {
  models["anthropic/claude-opus-4-5"] = { alias: "reasoning" };
  models["anthropic/claude-3.5-haiku"] = { alias: "haiku" };
  models["anthropic/claude-sonnet-4.5"] = { alias: "sonnet" };
  models["anthropic/claude-opus-4.6"] = { alias: "opus" };
}
if (e.OPENROUTER_KEY) {
  models["openrouter/deepseek/deepseek-v3.2"] = { alias: "backup" };
  models["openrouter/mistralai/devstral-2512"] = { alias: "code" };
  models["openrouter/nvidia/nemotron-3-nano-30b-a3b:free"] = { alias: "free" };
  models["openrouter/google/gemini-2.5-flash"] = { alias: "media" };
  models["openrouter/google/gemini-2.0-flash-001"] = { alias: "fast" };
  models["openrouter/google/gemini-3-flash-preview"] = { alias: "gemini3" };
}

// === WhatsApp / Evolution ===
if (e.HAS_EVOLUTION === "true" && e.WHATSAPP_PHONE) {
  config.channels.whatsapp = {
    accounts: {
      default: {
        name: e.ORG_NAME,
        enabled: true,
        dmPolicy: "allowlist",
        allowFrom: [e.WHATSAPP_PHONE],
        groupPolicy: "allowlist",
        debounceMs: 0
      }
    },
    dmPolicy: "allowlist",
    allowFrom: [e.WHATSAPP_PHONE],
    groupPolicy: "allowlist",
    mediaMaxMb: 50,
    debounceMs: 0
  };
  config.plugins.entries.whatsapp = { enabled: true };
}

fs.writeFileSync(e.OUTPUT_PATH, JSON.stringify(config, null, 4) + "\n");
'

# Validar JSON gerado
if node -e "JSON.parse(require('fs').readFileSync('$CONFIG_DIR/aiosbot.json','utf8'))" 2>/dev/null; then
  chmod 600 "$CONFIG_DIR/aiosbot.json"
  # Contar aliases
  alias_count=$(node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_DIR/aiosbot.json','utf8'));console.log(Object.keys(c.agents.defaults.models).length)" 2>/dev/null || echo "?")
  step_ok "aiosbot.json gerado (${alias_count} model aliases)"
else
  step_fail "aiosbot.json gerado com JSON invalido!"
  exit 1
fi

# =============================================================================
# STEP 8: GERAR node.json
# =============================================================================
node_uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || node -e "const c=require('crypto');console.log([c.randomBytes(4),c.randomBytes(2),c.randomBytes(2),c.randomBytes(2),c.randomBytes(6)].map((b,i)=>b.toString('hex')).join('-'))")
node_display="${nome_servidor:-$nome_agente}"

cat > "$CONFIG_DIR/node.json" << EOF
{
  "version": 1,
  "nodeId": "${node_uuid}",
  "displayName": "${node_display}",
  "gateway": {
    "host": "${gateway_host}",
    "port": 443,
    "tls": true
  }
}
EOF

if node -e "JSON.parse(require('fs').readFileSync('$CONFIG_DIR/node.json','utf8'))" 2>/dev/null; then
  chmod 600 "$CONFIG_DIR/node.json"
  step_ok "node.json gerado (UUID: ${node_uuid:0:8}...)"
else
  step_fail "node.json gerado com JSON invalido!"
  exit 1
fi

# =============================================================================
# STEP 9: GERAR .env CONSOLIDADO
# =============================================================================
cat > "$ENV_DIR/.env" << EOF
# ============================================
# ${display_name} — Environment Variables
# Generated by Legendsclaw Deployer v${DEPLOYER_VERSION:-1.0.0}
# $(date -u +%Y-%m-%dT%H:%M:%SZ)
# ============================================
# NEVER commit this file to git!

# === Identity ===
ORG_NAME=${org_name}
USER_NAME=${user_name:-$org_name}
AGENT_NAME=${nome_agente}

# === VPS Configuration ===
VPS_IP=${ts_ip:-}
GATEWAY_HOSTNAME=${ts_hostname:-localhost}
TAILNET_ID=${ts_tailnet:-}
GATEWAY_PASSWORD=${gateway_password}
HOOKS_TOKEN=${hooks_token}

# === Locale ===
TIMEZONE=${user_timezone}
LOCALE=${idioma:-pt-BR}

# === LLM API Keys (at least one required) ===
OPENROUTER_API_KEY=${openrouter_key:-}
ANTHROPIC_ADMIN_KEY=${anthropic_key:-}
OPENAI_API_KEY=${openai_key:-}
GEMINI_API_KEY=${gemini_key:-}
BRAVE_API_KEY=${brave_key:-}

# === Supabase (optional — for memory/database) ===
SUPABASE_URL=${supabase_url:-}
SUPABASE_ANON_KEY=${supabase_anon_key:-}
SUPABASE_SERVICE_ROLE_KEY=${supabase_service_key:-}
SUPABASE_PROJECT_REF=${supabase_project_ref:-}
SUPABASE_DB_PASSWORD=${supabase_db_password:-}
DATABASE_URL=${database_url:-}

# === Services (optional) ===
WHATSAPP_ADMIN_PHONE=${whatsapp_admin_phone:-}
MEMORY_PATH=${workspace_path}/memory

# === Advanced ===
LOG_LEVEL=info
LLM_ROUTER_ENABLED=true
LLM_ROUTER_DEFAULT_TIER=${default_tier}
DAILY_BUDGET_USD=20
EOF

chmod 600 "$ENV_DIR/.env"
env_lines=$(wc -l < "$ENV_DIR/.env")
step_ok ".env consolidado gerado (${env_lines} linhas)"

# =============================================================================
# STEP 10: GERAR mcp-config.json
# =============================================================================

# Construir JSON condicionalmente via node
BRAVE_KEY_VAL="$brave_key" \
WORKSPACE_PATH_VAL="$workspace_path" \
SUPABASE_URL_VAL="$supabase_url" \
SUPABASE_SERVICE_KEY_VAL="$supabase_service_key" \
MCP_OUTPUT="$MCP_DIR/mcp-config.json" \
node -e '
const fs = require("fs");
const e = process.env;
const servers = {};

if (e.BRAVE_KEY_VAL) {
  servers["brave-search"] = {
    command: "npx",
    args: ["-y", "@anthropic/mcp-brave-search"],
    env: { BRAVE_API_KEY: e.BRAVE_KEY_VAL }
  };
}

servers.filesystem = {
  command: "npx",
  args: ["-y", "@anthropic/mcp-filesystem", e.WORKSPACE_PATH_VAL]
};

if (e.SUPABASE_URL_VAL && e.SUPABASE_SERVICE_KEY_VAL) {
  servers.memory = {
    command: "npx",
    args: ["-y", "@anthropic/mcp-memory"],
    env: {
      SUPABASE_URL: e.SUPABASE_URL_VAL,
      SUPABASE_KEY: e.SUPABASE_SERVICE_KEY_VAL
    }
  };
}

fs.writeFileSync(e.MCP_OUTPUT, JSON.stringify({ mcpServers: servers }, null, 2) + "\n");
'

if node -e "JSON.parse(require('fs').readFileSync('$MCP_DIR/mcp-config.json','utf8'))" 2>/dev/null; then
  chmod 600 "$MCP_DIR/mcp-config.json"
  mcp_count=$(node -e "const c=JSON.parse(require('fs').readFileSync('$MCP_DIR/mcp-config.json','utf8'));console.log(Object.keys(c.mcpServers).length)" 2>/dev/null || echo "?")
  step_ok "mcp-config.json gerado (${mcp_count} servidores MCP)"
else
  step_fail "mcp-config.json gerado com JSON invalido!"
  exit 1
fi

# =============================================================================
# STEP 11: SALVAR ESTADO
# =============================================================================
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/dados_gateway_config" << EOF
Agente: ${nome_agente}
Config Dir: ${CONFIG_DIR}
aiosbot.json: ${CONFIG_DIR}/aiosbot.json
node.json: ${CONFIG_DIR}/node.json
env: ${ENV_DIR}/.env
mcp-config.json: ${MCP_DIR}/mcp-config.json
Arquivos Gerados: 4
Status: completo
Data Criacao: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
chmod 600 "$STATE_DIR/dados_gateway_config"

step_ok "Estado salvo em dados_gateway_config"

# =============================================================================
# STEP 12: COPIAR CONFIGS PARA OPENCLAW WORKSPACE
# =============================================================================
OPENCLAW_WORKSPACE="$HOME/.openclaw/workspace"
if [[ -d "$OPENCLAW_WORKSPACE" ]]; then
  DEST_CONFIG_DIR="${OPENCLAW_WORKSPACE}/apps/${nome_agente}/config"
  DEST_MCP_DIR="${OPENCLAW_WORKSPACE}/apps/${nome_agente}/mcps"
  mkdir -p "$DEST_CONFIG_DIR"
  mkdir -p "$DEST_MCP_DIR"
  cp "$CONFIG_DIR/aiosbot.json" "$DEST_CONFIG_DIR/"
  cp "$CONFIG_DIR/node.json" "$DEST_CONFIG_DIR/"
  cp "$MCP_DIR/mcp-config.json" "$DEST_MCP_DIR/"
  # Copiar .env para o diretorio do agente no workspace
  cp "$ENV_DIR/.env" "${OPENCLAW_WORKSPACE}/apps/${nome_agente}/.env"
  chmod 600 "${OPENCLAW_WORKSPACE}/apps/${nome_agente}/.env"
  step_ok "Configs copiados para ~/.openclaw/workspace/apps/${nome_agente}/"

  # Reiniciar gateway para carregar novos configs
  if reload_gateway; then
    echo -e "  ${UI_GREEN:-}Gateway reiniciado — configs aplicados${UI_NC:-}"
  fi
else
  step_skip "OpenClaw workspace nao encontrado (~/.openclaw/workspace/) — copie manualmente depois"
fi

# =============================================================================
# STEP 13: RESUMO FINAL
# =============================================================================
resumo_final

echo ""
echo -e "${UI_BOLD:-\033[1m}  ARTEFATOS GERADOS:${UI_NC:-\033[0m}"
echo ""
printf "  %-20s %-45s %s\n" "Artefato" "Path" "Tamanho"
printf "  %-20s %-45s %s\n" "--------" "----" "-------"
printf "  %-20s %-45s %s\n" "aiosbot.json" "$CONFIG_DIR/aiosbot.json" "$(wc -c < "$CONFIG_DIR/aiosbot.json") bytes"
printf "  %-20s %-45s %s\n" "node.json" "$CONFIG_DIR/node.json" "$(wc -c < "$CONFIG_DIR/node.json") bytes"
printf "  %-20s %-45s %s\n" ".env" "$ENV_DIR/.env" "$(wc -c < "$ENV_DIR/.env") bytes"
printf "  %-20s %-45s %s\n" "mcp-config.json" "$MCP_DIR/mcp-config.json" "$(wc -c < "$MCP_DIR/mcp-config.json") bytes"
echo ""
echo "  Model aliases: ${alias_count}"
echo "  MCP servers: ${mcp_count}"
echo "  Dados carregados: $((4 + loaded_optional)) | Skipped: ${skipped_optional}"
echo "  Permissoes: chmod 600 em todos os artefatos"
echo ""

hint_gateway_config "$nome_agente"
log_finish
