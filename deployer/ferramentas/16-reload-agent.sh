#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 16: Reload Agent
# Reinicia o OpenClaw Gateway para aplicar mudancas de persona, skills, config
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"

log_init "reload-agent"
setup_trap
step_init 4

# =============================================================================
# STEP 1: DETECTAR SERVICO
# =============================================================================
service_type="none"

if systemctl is-active openclaw &>/dev/null 2>&1; then
  service_type="system"
  step_ok "OpenClaw detectado como system service"
elif systemctl --user is-active openclaw &>/dev/null 2>&1; then
  service_type="user"
  step_ok "OpenClaw detectado como user service"
elif systemctl --user is-active openclaw-gateway &>/dev/null 2>&1; then
  service_type="user-gateway"
  step_ok "OpenClaw detectado como user service (openclaw-gateway)"
else
  # Tentar detectar por processo
  gw_pid=$(pgrep -f "openclaw.*gateway\|openclaw.*serve\|dist/cli.js serve" 2>/dev/null | head -1 || true)
  if [[ -n "$gw_pid" ]]; then
    service_type="process"
    step_ok "OpenClaw detectado como processo (PID ${gw_pid})"
  else
    step_fail "OpenClaw nao encontrado (nenhum servico ou processo ativo)"
    echo "  Execute primeiro: Ferramenta [03] OpenClaw Gateway"
    exit 1
  fi
fi

# =============================================================================
# STEP 2: MOSTRAR O QUE SERA RECARREGADO
# =============================================================================
echo ""
echo -e "${UI_BOLD}Arquivos que serao recarregados apos restart:${UI_NC}"

STATE_DIR="${HOME}/dados_vps"
if [[ -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(grep "^Nome=" "$STATE_DIR/dados_whitelabel" 2>/dev/null | cut -d'=' -f2 || echo "desconhecido")
  echo "  Agente: ${nome_agente}"
fi

# Listar arquivos de persona/config
workspace_dir="${HOME}/.openclaw/workspace"
if [[ -d "$workspace_dir" ]]; then
  for f in SOUL.md IDENTITY.md USER.md AGENTS.md MEMORY.md; do
    if [[ -f "$workspace_dir/$f" ]]; then
      mod_time=$(stat -c '%y' "$workspace_dir/$f" 2>/dev/null | cut -d'.' -f1 || echo "?")
      echo "  ✓ ${f} (modificado: ${mod_time})"
    fi
  done
fi

# LLM Router config
DEPLOYER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -n "${nome_agente:-}" ]] && [[ -f "${DEPLOYER_ROOT}/apps/${nome_agente}/config/llm-router-config.yaml" ]]; then
  echo "  ✓ llm-router-config.yaml"
fi
if [[ -n "${nome_agente:-}" ]] && [[ -f "${DEPLOYER_ROOT}/apps/${nome_agente}/skills/config.js" ]]; then
  echo "  ✓ skills/config.js"
fi

step_ok "Arquivos de configuracao listados"

# =============================================================================
# STEP 3: REINICIAR SERVICO
# =============================================================================
echo ""
echo "  Reiniciando OpenClaw Gateway..."

case "$service_type" in
  system)
    sudo systemctl restart openclaw
    sleep 3
    if systemctl is-active openclaw &>/dev/null; then
      step_ok "OpenClaw system service reiniciado"
    else
      step_fail "Falha ao reiniciar OpenClaw system service"
      echo "  Verifique com: sudo journalctl -u openclaw -n 20"
      exit 1
    fi
    ;;
  user)
    systemctl --user restart openclaw
    sleep 3
    if systemctl --user is-active openclaw &>/dev/null; then
      step_ok "OpenClaw user service reiniciado"
    else
      step_fail "Falha ao reiniciar OpenClaw user service"
      echo "  Verifique com: journalctl --user -u openclaw -n 20"
      exit 1
    fi
    ;;
  user-gateway)
    systemctl --user restart openclaw-gateway
    sleep 3
    if systemctl --user is-active openclaw-gateway &>/dev/null; then
      step_ok "OpenClaw user service reiniciado"
    else
      step_fail "Falha ao reiniciar openclaw-gateway user service"
      exit 1
    fi
    ;;
  process)
    gw_pid=$(pgrep -f "openclaw.*gateway\|openclaw.*serve\|dist/cli.js serve" 2>/dev/null | head -1 || true)
    if [[ -n "$gw_pid" ]]; then
      kill "$gw_pid" 2>/dev/null || true
      sleep 2
    fi
    # Re-iniciar
    pushd /opt/openclaw > /dev/null
    nohup node dist/cli.js serve > /dev/null 2>&1 &
    popd > /dev/null
    sleep 3
    new_pid=$(pgrep -f "openclaw.*gateway\|openclaw.*serve\|dist/cli.js serve" 2>/dev/null | head -1 || true)
    if [[ -n "$new_pid" ]]; then
      step_ok "OpenClaw reiniciado (PID ${new_pid})"
    else
      step_fail "Falha ao reiniciar OpenClaw"
      exit 1
    fi
    ;;
esac

# =============================================================================
# STEP 4: HEALTH CHECK
# =============================================================================
porta_openclaw="18789"
if [[ -f "$STATE_DIR/dados_openclaw" ]]; then
  porta_openclaw=$(grep "^Porta:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}' || echo "18789")
  [[ -z "$porta_openclaw" ]] && porta_openclaw="18789"
fi

health_ok=false
for tentativa in 1 2 3 4 5; do
  echo "  Health check ${tentativa}/5..."
  if curl -sf "http://localhost:${porta_openclaw}/health" &>/dev/null; then
    health_ok=true
    break
  fi
  sleep 3
done

if $health_ok; then
  step_ok "Gateway respondendo na porta ${porta_openclaw} — reload completo"
else
  step_fail "Health check falhou — gateway pode estar iniciando ainda"
  echo "  Verifique manualmente: curl http://localhost:${porta_openclaw}/health"
fi

resumo_final
log_finish
