#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 06: Validacao Gateway + Tailscale
# Story 2.2: Validacao end-to-end do OpenClaw Gateway via Tailscale
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "validation-gw"
setup_trap

# Verificar bash >= 4.0 (necessario para associative arrays)
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "ERRO: bash >= 4.0 necessario (atual: ${BASH_VERSION})"
  log_finish
  exit 1
fi

step_init 10

# Rastreamento de resultados
declare -A RESULTS=()

# =============================================================================
# STEP 2: LOAD STATE — dados_openclaw + dados_tailscale
# =============================================================================
dados

if [[ ! -f "$STATE_DIR/dados_openclaw" ]]; then
  step_fail "dados_openclaw nao encontrado — OpenClaw nao instalado"
  echo "  Execute primeiro: Ferramenta [05] OpenClaw Gateway"
  log_finish
  exit 1
fi

if [[ ! -f "$STATE_DIR/dados_tailscale" ]]; then
  step_fail "dados_tailscale nao encontrado — Tailscale nao configurado"
  echo "  Execute primeiro: Ferramenta [04] Tailscale VPN"
  log_finish
  exit 1
fi

# Ler dados de estado
porta_openclaw=$(grep "Porta:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}')
porta_openclaw="${porta_openclaw:-18789}"
hostname_tailscale=$(grep "Hostname Tailscale:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}')
ip_tailscale=$(grep "IP Tailscale:" "$STATE_DIR/dados_tailscale" 2>/dev/null | awk -F': ' '{print $2}')

step_ok "Estado carregado — dados_openclaw e dados_tailscale encontrados"

# =============================================================================
# STEP 3: CHECK TAILSCALE
# =============================================================================
if tailscale status &>/dev/null; then
  step_ok "Tailscale ativo e conectado"
  RESULTS[tailscale]="PASS"
else
  step_fail "Tailscale nao esta ativo ou conectado"
  RESULTS[tailscale]="FAIL"
  # Continuar com checks locais (|| true implicito pelo tracking)
fi

# =============================================================================
# STEP 4: CHECK OPENCLAW SERVICE
# =============================================================================
if systemctl is-active openclaw &>/dev/null; then
  step_ok "Servico OpenClaw ativo"
  RESULTS[service]="PASS"
else
  step_fail "Servico OpenClaw nao esta ativo"
  RESULTS[service]="FAIL"
  # Continuar com checks restantes (mesmo pattern do Tailscale check)
fi

# =============================================================================
# STEP 5: DISPLAY TEST COMMANDS — comandos para desktop
# =============================================================================
echo ""
echo -e "${UI_BOLD}=============================================="
echo "  COMANDOS DE TESTE (executar do desktop)"
echo -e "==============================================${UI_NC}"
echo ""
echo "  Verificar conectividade Tailscale:"
echo "    tailscale ping ${hostname_tailscale:-SEU_HOSTNAME}"
echo ""
echo "  Health check via Tailscale:"
echo "    curl http://${ip_tailscale:-SEU_IP}:${porta_openclaw}/health"
echo ""
echo "  Teste de agente:"
echo "    openclaw agent --message \"Teste\" --thinking high"
echo ""
echo "=============================================="
echo ""

step_ok "Comandos de teste exibidos"

# =============================================================================
# STEP 6: RUN DOCTOR — openclaw doctor
# =============================================================================
if [[ -d "/opt/openclaw" ]]; then
  echo "  Executando openclaw doctor..."
  if (cd /opt/openclaw && pnpm openclaw doctor 2>&1); then
    step_ok "openclaw doctor PASS"
    RESULTS[doctor]="PASS"
  else
    step_fail "openclaw doctor FAIL"
    RESULTS[doctor]="FAIL"
  fi
else
  step_fail "Diretorio /opt/openclaw nao encontrado"
  RESULTS[doctor]="FAIL"
fi

# =============================================================================
# STEP 7: HEALTH CHECK LOCAL
# =============================================================================
if curl -sf "http://localhost:${porta_openclaw}/health" &>/dev/null; then
  step_ok "Health check local OK — porta ${porta_openclaw}"
  RESULTS[health]="PASS"
else
  step_fail "Health check local falhou — porta ${porta_openclaw}"
  RESULTS[health]="FAIL"
fi

# =============================================================================
# STEP 8: MENSAGEM LOCAL — openclaw agent --message "Teste"
# =============================================================================
if [[ -d "/opt/openclaw" ]]; then
  echo "  Executando teste de mensagem local (timeout 30s)..."
  if timeout 30 bash -c 'cd /opt/openclaw && pnpm openclaw agent --message "Teste" --thinking high' &>/dev/null; then
    step_ok "Teste de mensagem local PASS"
    RESULTS[mensagem]="PASS"
  else
    step_fail "Teste de mensagem local FAIL (timeout ou erro)"
    RESULTS[mensagem]="FAIL"
  fi
else
  step_fail "Diretorio /opt/openclaw nao encontrado — teste de mensagem impossivel"
  RESULTS[mensagem]="FAIL"
fi

# =============================================================================
# STEP 9: RECORD RESULTS — append em dados_openclaw
# =============================================================================
# Determinar resultado geral
resultado_geral="PASS"
for check in tailscale service doctor health mensagem; do
  if [[ "${RESULTS[$check]:-FAIL}" == "FAIL" ]]; then
    resultado_geral="FAIL"
    break
  fi
done

# Append resultado
{
  echo ""
  echo "--- Validacao End-to-End ---"
  echo "Validacao: ${resultado_geral}"
  echo "Data Validacao: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Tailscale: ${RESULTS[tailscale]:-FAIL}"
  echo "OpenClaw Service: ${RESULTS[service]:-FAIL}"
  echo "Doctor: ${RESULTS[doctor]:-FAIL}"
  echo "Health Check: ${RESULTS[health]:-FAIL}"
  echo "Mensagem Local: ${RESULTS[mensagem]:-FAIL}"
} >> "$STATE_DIR/dados_openclaw"

chmod 600 "$STATE_DIR/dados_openclaw"

step_ok "Resultados registrados em ~/dados_vps/dados_openclaw"

# =============================================================================
# STEP 10: HINTS + RESUMO
# =============================================================================

# Hints contextuais por falha
if [[ "${RESULTS[tailscale]:-FAIL}" == "FAIL" ]] || \
   [[ "${RESULTS[service]:-FAIL}" == "FAIL" ]] || \
   [[ "${RESULTS[doctor]:-FAIL}" == "FAIL" ]] || \
   [[ "${RESULTS[health]:-FAIL}" == "FAIL" ]] || \
   [[ "${RESULTS[mensagem]:-FAIL}" == "FAIL" ]]; then
  hint_validacao_gw \
    "${RESULTS[tailscale]:-FAIL}" \
    "${RESULTS[service]:-FAIL}" \
    "${RESULTS[doctor]:-FAIL}" \
    "${RESULTS[health]:-FAIL}" \
    "${RESULTS[mensagem]:-FAIL}" \
    "$porta_openclaw"
fi

# Resumo final
resumo_final

echo -e "${UI_BOLD}  Validacao Gateway + Tailscale End-to-End${UI_NC}"
echo ""
echo "  Resultado: ${resultado_geral}"
echo ""
echo "  Tailscale:       ${RESULTS[tailscale]:-FAIL}"
echo "  OpenClaw Service: ${RESULTS[service]:-FAIL}"
echo "  Doctor:          ${RESULTS[doctor]:-FAIL}"
echo "  Health Check:    ${RESULTS[health]:-FAIL}"
echo "  Mensagem Local:  ${RESULTS[mensagem]:-FAIL}"
echo ""
echo "  Dados: ~/dados_vps/dados_openclaw"
echo "  Log:   ${LOG_FILE}"
echo ""

if [[ "$resultado_geral" == "PASS" ]]; then
  echo -e "  ${UI_GREEN}Gateway validado com sucesso!${UI_NC}"
  echo "  Proximos passos: Configurar LLM providers (OpenRouter, Anthropic)"
else
  echo -e "  ${UI_RED}Validacao encontrou problemas — verifique os hints acima.${UI_NC}"
fi
echo ""

log_finish
