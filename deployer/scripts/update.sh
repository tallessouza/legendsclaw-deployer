#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Update (Backup + Git Pull + Re-validação)
# Uso: ./update.sh [agente]
# Story: 12.8
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYER_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${DEPLOYER_DIR}/lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"

log_init "update"
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

echo "Atualizando deployer para agente: ${nome_agente}"
echo ""

# --- Derivar paths ---
apps_path=$(grep "Apps Path:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
apps_path="${apps_path:-${DEPLOYER_DIR}/apps/${nome_agente}}"
config_dir="${apps_path}/config"

# --- Update ---
step_init 4

# STEP 1: Backup configs
backup_dir="${REAL_HOME}/legendsclaw-backups/$(date +%Y-%m-%d-%H%M%S)"
backup_created=false
if [[ -d "$config_dir" ]]; then
  mkdir -p "$backup_dir"
  cp -r "$config_dir" "$backup_dir/"
  backup_created=true
  step_ok "Backup criado: ${backup_dir}"
  log "Backup: ${config_dir} -> ${backup_dir}"
else
  step_skip "Diretorio de configs nao encontrado: ${config_dir} — nada para backup"
fi

# STEP 2: Git pull (com confirmação)
deployer_repo_dir="$DEPLOYER_DIR"
# Encontrar raiz do repositório git
if git -C "$deployer_repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  deployer_repo_dir=$(git -C "$deployer_repo_dir" rev-parse --show-toplevel 2>/dev/null)
fi

echo ""
echo "Repositorio: ${deployer_repo_dir}"
echo -n "Executar git pull? (S/n): "
if [[ "${AUTO_MODE:-false}" == "true" ]]; then
  pull_choice="S"
  echo "S [auto]"
else
  read -r pull_choice </dev/tty || pull_choice="n"
fi

if [[ "$pull_choice" =~ ^[Nn]$ ]]; then
  step_skip "Git pull cancelado pelo usuario"
else
  if git -C "$deployer_repo_dir" pull 2>&1; then
    step_ok "Git pull executado com sucesso"
  else
    local backup_msg=""
    if [[ "$backup_created" == "true" ]]; then
      backup_msg=" Backup disponivel em: ${backup_dir}"
    fi
    step_fail "Git pull falhou — possivel conflito.${backup_msg}"
    resumo_final
    log_finish
    exit 1
  fi
fi

# STEP 3: Re-validar configs via validate-config.sh
validate_config_script="${SCRIPT_DIR}/validate-config.sh"
if [[ -x "$validate_config_script" ]]; then
  if LEGENDSCLAW_TEE_ACTIVE=1 "$validate_config_script" "$nome_agente" >/dev/null 2>&1; then
    step_ok "Configs re-validados via validate-config.sh"
  else
    step_fail "validate-config.sh reportou problemas apos update"
  fi
else
  step_skip "validate-config.sh nao encontrado (Story 12.7)"
fi

# STEP 4: Re-validar via validate.sh
validate_script="${SCRIPT_DIR}/validate.sh"
if [[ -x "$validate_script" ]]; then
  if LEGENDSCLAW_TEE_ACTIVE=1 "$validate_script" "$nome_agente" >/dev/null 2>&1; then
    step_ok "Validacao geral passou"
  else
    step_fail "Validacao geral reportou problemas — execute validate.sh para detalhes"
  fi
else
  step_fail "validate.sh nao encontrado em ${SCRIPT_DIR}"
fi

# --- Resumo ---
resumo_final
log_finish

if [[ "$STEP_FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
