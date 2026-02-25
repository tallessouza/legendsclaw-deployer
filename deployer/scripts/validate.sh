#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Validação Geral do Sistema
# Verifica: state files, configs, gateway, skills, workspace
# Uso: ./validate.sh [agente]
# Story: 12.8
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYER_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${DEPLOYER_DIR}/lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"

log_init "validate"
setup_trap

# --- Detectar agente ---
nome_agente="${1:-}"
if [[ -z "$nome_agente" && -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
fi

if [[ -z "$nome_agente" ]]; then
  echo "ERRO: Nome do agente nao informado e dados_whitelabel nao encontrado."
  echo "Uso: $0 [agente]"
  exit 1
fi

echo "Validando instalacao do agente: ${nome_agente}"
echo ""

# --- Derivar paths de dados_whitelabel ---
apps_path=$(grep "Apps Path:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
apps_path="${apps_path:-${DEPLOYER_DIR}/apps/${nome_agente}}"

config_dir="${apps_path}/config"
skills_dir="${apps_path}/skills"

# Workspace path: prefer dados_workspace, fallback to apps_path/workspace
workspace_path=$(grep "Workspace Path:" "$STATE_DIR/dados_workspace" 2>/dev/null | awk -F': ' '{print $2}' || true)
workspace_path="${workspace_path:-${apps_path}/workspace}"

# --- Validação ---
step_init 5

# CHECK 1: State files essenciais
missing_state_files=()
for sf in dados_whitelabel dados_openclaw dados_workspace; do
  if [[ ! -f "$STATE_DIR/$sf" ]]; then
    missing_state_files+=("$sf")
    log "FAIL: State file ausente: $sf"
  fi
done
if [[ ${#missing_state_files[@]} -eq 0 ]]; then
  step_ok "State files essenciais presentes (dados_whitelabel, dados_openclaw, dados_workspace)"
else
  step_fail "State files ausentes: ${missing_state_files[*]} — verifique ~/dados_vps/"
fi

# CHECK 2: Configs via validate-config.sh
validate_config_script="${SCRIPT_DIR}/validate-config.sh"
if [[ -x "$validate_config_script" ]]; then
  if LEGENDSCLAW_TEE_ACTIVE=1 "$validate_config_script" "$nome_agente" >/dev/null 2>&1; then
    step_ok "Configs validados via validate-config.sh"
  else
    step_fail "validate-config.sh reportou problemas — execute manualmente para detalhes"
  fi
else
  step_skip "validate-config.sh nao encontrado (Story 12.7)"
fi

# CHECK 3: Gateway acessível
gw_port=$(grep "Porta:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}' || echo "19888")
health_ok=false
for i in 1 2 3; do
  if curl -sf --max-time 5 "http://localhost:${gw_port}/health" >/dev/null 2>&1; then
    health_ok=true
    break
  fi
  sleep 2
done
if [[ "$health_ok" == "true" ]]; then
  step_ok "Gateway acessivel em localhost:${gw_port}/health"
else
  step_fail "Gateway inacessivel em localhost:${gw_port}/health (3 tentativas)"
fi

# CHECK 4: Skills instalados com SKILL.md
if [[ -d "$skills_dir" ]]; then
  skill_count=$(find "$skills_dir" -name "SKILL.md" -type f 2>/dev/null | wc -l)
  if [[ "$skill_count" -gt 0 ]]; then
    step_ok "Skills instalados: ${skill_count} skill(s) com SKILL.md em ${skills_dir}"
  else
    step_fail "Diretorio de skills existe mas nenhum SKILL.md encontrado em ${skills_dir}"
  fi
else
  step_fail "Diretorio de skills nao encontrado: ${skills_dir}"
fi

# CHECK 5: Workspace com 8 bootstrap files
BOOTSTRAP_FILES=(AGENTS.md SOUL.md IDENTITY.md USER.md BOOTSTRAP.md MEMORY.md TOOLS.md HEARTBEAT.md)
if [[ -d "$workspace_path" ]]; then
  missing_files=()
  for bf in "${BOOTSTRAP_FILES[@]}"; do
    if [[ ! -f "${workspace_path}/${bf}" ]]; then
      missing_files+=("$bf")
    fi
  done
  if [[ ${#missing_files[@]} -eq 0 ]]; then
    step_ok "Workspace completo: 8/8 bootstrap files em ${workspace_path}"
  else
    step_fail "Workspace incompleto: faltam ${#missing_files[@]} arquivo(s) — ${missing_files[*]}"
  fi
else
  step_fail "Workspace nao encontrado: ${workspace_path}"
fi

# --- Resumo ---
resumo_final
log_finish

if [[ "$STEP_FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
