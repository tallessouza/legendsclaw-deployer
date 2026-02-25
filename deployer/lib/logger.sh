#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Logging Functions
# Pattern: {ferramenta}-{timestamp}.log em ~/legendsclaw-logs/
# =============================================================================

LOG_DIR="$HOME/legendsclaw-logs"
LOG_FILE=""

# Inicializa logging para uma ferramenta
# Uso: log_init "base"
log_init() {
  local ferramenta="${1:-deployer}"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="${LOG_DIR}/${ferramenta}-${timestamp}.log"

  mkdir -p "$LOG_DIR"

  # Redireciona stdout e stderr para tee (tela + arquivo)
  # Evita tee duplo quando rodando como subscript (install.sh → ferramenta.sh)
  if [[ -z "${LEGENDSCLAW_TEE_ACTIVE:-}" ]]; then
    export LEGENDSCLAW_TEE_ACTIVE=1
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  # Header do log
  echo "=============================================="
  echo "Legendsclaw Deployer — ${ferramenta}"
  echo "=============================================="
  echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Hostname: $(hostname)"
  echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Desconhecido')"
  echo "User: $(whoami)"
  echo "Log: ${LOG_FILE}"
  echo "=============================================="
  echo ""
}

# Log uma mensagem com timestamp
# Uso: log "Mensagem de log"
log() {
  local message="$1"
  echo "[$(date '+%H:%M:%S')] ${message}" >> "${LOG_FILE}" 2>/dev/null
}

# Finaliza logging
# Uso: log_finish
log_finish() {
  echo ""
  echo "=============================================="
  echo "Log finalizado: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Arquivo: ${LOG_FILE}"
  echo "=============================================="
}
