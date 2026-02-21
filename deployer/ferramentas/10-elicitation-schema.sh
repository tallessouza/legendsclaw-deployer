#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 10: Elicitation Schema
# Story 4.3: Skill Elicitation — Templates e Schema Supabase
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
MIGRATIONS_DIR="${SCRIPT_DIR}/../migrations"
SEEDS_DIR="${SCRIPT_DIR}/../seeds"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# Mascarar key para exibicao segura
mask_key() {
  local key="$1"
  local len=${#key}
  if [[ $len -le 10 ]]; then
    echo "***"
  else
    echo "${key:0:8}***${key: -4}"
  fi
}

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "elicitation-schema"
setup_trap
step_init 10

# =============================================================================
# STEP 2: LOAD STATE + VERIFICAR DEPENDENCIAS
# =============================================================================
dados
if [[ ! -f "$STATE_DIR/dados_whitelabel" ]]; then
  step_fail "Whitelabel nao encontrado (~/dados_vps/dados_whitelabel ausente)"
  echo "  Execute primeiro: Ferramenta [07] Whitelabel — Identidade do Agente"
  exit 1
fi
nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
if [[ -z "$nome_agente" ]]; then
  step_fail "Nome do agente nao encontrado em dados_whitelabel"
  exit 1
fi

step_ok "Estado carregado — agente '${nome_agente}'"

# =============================================================================
# STEP 3: OBTER SUPABASE_URL E SUPABASE_SERVICE_ROLE_KEY
# =============================================================================
supabase_url=""
supabase_key=""

# Tentar ler de dados_skills primeiro
if [[ -f "$STATE_DIR/dados_skills" ]]; then
  supabase_url=$(grep "SUPABASE_URL:" "$STATE_DIR/dados_skills" 2>/dev/null | awk -F': ' '{print $2}' || true)
  supabase_key=$(grep "SUPABASE_SERVICE_ROLE_KEY:" "$STATE_DIR/dados_skills" 2>/dev/null | awk -F': ' '{print $2}' || true)
fi

# Fallback: ler do .env do OpenClaw
if [[ -z "$supabase_url" || -z "$supabase_key" ]]; then
  OPENCLAW_DIR=$(grep "Install Path:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}' || true)
  OPENCLAW_DIR="${OPENCLAW_DIR:-/opt/openclaw}"
  ENV_FILE="${OPENCLAW_DIR}/.env"
  if [[ -f "$ENV_FILE" ]]; then
    [[ -z "$supabase_url" ]] && supabase_url=$(grep "^SUPABASE_URL=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
    [[ -z "$supabase_key" ]] && supabase_key=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
  fi
fi

# Se ainda nao temos, coletar do operador
if [[ -z "$supabase_url" ]]; then
  echo ""
  echo -e "  ${UI_YELLOW}SUPABASE_URL nao encontrada automaticamente.${UI_NC}"
  echo "  Hint: Acesse https://supabase.com/dashboard → Settings → API → Project URL"
  echo ""
  read -rp "  SUPABASE_URL: " supabase_url
  if [[ -z "$supabase_url" ]]; then
    step_fail "SUPABASE_URL e obrigatoria"
    exit 1
  fi
fi

if [[ -z "$supabase_key" ]]; then
  echo ""
  echo -e "  ${UI_YELLOW}SUPABASE_SERVICE_ROLE_KEY nao encontrada automaticamente.${UI_NC}"
  echo "  Hint: Acesse https://supabase.com/dashboard → Settings → API → service_role (secret)"
  echo ""
  read -rp "  SUPABASE_SERVICE_ROLE_KEY: " supabase_key
  if [[ -z "$supabase_key" ]]; then
    step_fail "SUPABASE_SERVICE_ROLE_KEY e obrigatoria"
    exit 1
  fi
fi

step_ok "Credenciais Supabase obtidas (URL: ${supabase_url%%/rest*}...)"

# =============================================================================
# STEP 4: CONFERINDO AS INFORMACOES
# =============================================================================
conferindo_as_info \
  "Agente=${nome_agente}" \
  "Supabase URL=${supabase_url}" \
  "Supabase Key=$(mask_key "$supabase_key")" \
  "Tabelas=elicitation_templates, elicitation_sessions, elicitation_results" \
  "Seed=onboarding-founder (2 secoes, 10 perguntas)" \
  "Migration File=deployer/migrations/001-elicitation-tables.sql" \
  "Seed File=deployer/seeds/001-onboarding-founder.sql"

read -rp "Confirma? (s/n): " confirmacao
if [[ ! "$confirmacao" =~ ^[Ss]$ ]]; then
  echo "Cancelado pelo operador."
  exit 0
fi

step_ok "Informacoes confirmadas"

# =============================================================================
# STEP 5: GERAR MIGRATION SQL
# =============================================================================
mkdir -p "$MIGRATIONS_DIR"

if [[ -f "${MIGRATIONS_DIR}/001-elicitation-tables.sql" ]]; then
  step_skip "Migration ja existe — deployer/migrations/001-elicitation-tables.sql"
else
  # Migration is shipped with the deployer (created by Story 4.3)
  step_fail "Migration file nao encontrado: deployer/migrations/001-elicitation-tables.sql"
  echo "  O arquivo deveria existir no repositorio. Verifique a instalacao."
  exit 1
fi

# =============================================================================
# STEP 6: GERAR SEED SQL
# =============================================================================
mkdir -p "$SEEDS_DIR"

if [[ -f "${SEEDS_DIR}/001-onboarding-founder.sql" ]]; then
  step_skip "Seed ja existe — deployer/seeds/001-onboarding-founder.sql"
else
  step_fail "Seed file nao encontrado: deployer/seeds/001-onboarding-founder.sql"
  echo "  O arquivo deveria existir no repositorio. Verifique a instalacao."
  exit 1
fi

# =============================================================================
# STEP 7: HINTS — COMO APLICAR O SQL
# =============================================================================
echo ""
echo -e "${UI_BOLD}=============================================="
echo "  COMO APLICAR"
echo -e "==============================================${UI_NC}"
echo ""
echo "  1. Acesse o Supabase Dashboard → SQL Editor"
echo "  2. Cole o conteudo de deployer/migrations/001-elicitation-tables.sql"
echo "  3. Execute (Run)"
echo "  4. Cole o conteudo de deployer/seeds/001-onboarding-founder.sql"
echo "  5. Execute (Run)"
echo ""
echo "  VERIFICACAO:"
echo "  1. Acesse Table Editor"
echo "  2. Confirme 3 tabelas: elicitation_templates, elicitation_sessions, elicitation_results"
echo "  3. Confirme seed: elicitation_templates deve ter 1 registro \"onboarding-founder\""
echo ""
echo "=============================================="
echo ""

step_ok "Hints de aplicacao exibidos"

# =============================================================================
# STEP 8: VERIFICACAO AUTOMATICA VIA REST
# =============================================================================
echo "  Verificando tabelas via REST API..."

verificacao="PENDENTE"

tables_response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  -H "apikey: ${supabase_key}" \
  -H "Authorization: Bearer ${supabase_key}" \
  "${supabase_url}/rest/v1/elicitation_templates?select=count" 2>/dev/null) || tables_response="000"

if [[ "$tables_response" == "200" ]]; then
  verificacao="OK"
  echo -e "    ${UI_GREEN}OK${UI_NC} Tabelas elicitation encontradas (HTTP 200)"

  # Verificar seed
  seed_count=$(curl -s --max-time 10 \
    -H "apikey: ${supabase_key}" \
    -H "Authorization: Bearer ${supabase_key}" \
    -H "Content-Type: application/json" \
    "${supabase_url}/rest/v1/elicitation_templates?name=eq.onboarding-founder&select=id" 2>/dev/null) || seed_count="[]"

  if echo "$seed_count" | grep -q "onboarding-founder\|a1b2c3d4"; then
    echo -e "    ${UI_GREEN}OK${UI_NC} Seed onboarding-founder encontrado"
  else
    echo -e "    ${UI_YELLOW}WARNING${UI_NC} Seed onboarding-founder nao encontrado — aplique o seed SQL"
  fi
elif [[ "$tables_response" == "404" ]]; then
  echo -e "    ${UI_YELLOW}PENDENTE${UI_NC} Tabelas nao encontradas (HTTP 404) — aplique a migration SQL"
else
  echo -e "    ${UI_YELLOW}PENDENTE${UI_NC} Nao foi possivel verificar (HTTP ${tables_response})"
fi

step_ok "Verificacao automatica concluida (${verificacao})"

# =============================================================================
# STEP 9: SAVE STATE
# =============================================================================
mkdir -p "$STATE_DIR"

cat > "$STATE_DIR/dados_elicitation_schema" << EOF
Migration: 001-elicitation-tables.sql
Tables: elicitation_templates, elicitation_sessions, elicitation_results
Seed: onboarding-founder
Migration File: deployer/migrations/001-elicitation-tables.sql
Seed File: deployer/seeds/001-onboarding-founder.sql
Supabase URL: ${supabase_url}
Verificacao: ${verificacao}
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_elicitation_schema"

step_ok "Estado salvo em ~/dados_vps/dados_elicitation_schema"

# =============================================================================
# STEP 10: RESUMO FINAL + HINTS
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  Elicitation Schema — ${nome_agente}${UI_NC}"
echo ""
echo "  Tabelas:          elicitation_templates, elicitation_sessions, elicitation_results"
echo "  Seed:             onboarding-founder (2 secoes, 10 perguntas)"
echo "  Migration:        deployer/migrations/001-elicitation-tables.sql"
echo "  Seed File:        deployer/seeds/001-onboarding-founder.sql"
echo "  Verificacao:      ${verificacao}"
echo "  Supabase URL:     ${supabase_url}"
echo "  Estado:           ~/dados_vps/dados_elicitation_schema"
echo "  Log:              ${LOG_FILE}"
echo ""

hint_elicitation_schema

log_finish
