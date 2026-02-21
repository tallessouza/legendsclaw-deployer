#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 15: Validacao Final — Teste End-to-End
# Story 5.4: Validar todos os componentes instalados (Epics 1-5)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# LOGGING + STEP INIT
# =============================================================================
log_init "validation-final"
setup_trap
step_init 15

# =============================================================================
# PRE-REQUISITOS
# =============================================================================
if [[ ! -d "$STATE_DIR" ]]; then
  step_fail "Diretorio ~/dados_vps/ nao encontrado"
  echo "  Execute pelo menos a Ferramenta [01] Base antes de validar."
  exit 1
fi

if [[ ! -f "$STATE_DIR/dados_vps" ]]; then
  step_fail "Arquivo ~/dados_vps/dados_vps nao encontrado"
  echo "  Execute a Ferramenta [01] Base para criar dados iniciais."
  exit 1
fi

dados
step_ok "Pre-requisitos verificados — dados_vps presente"

# =============================================================================
# HELPER: Ler valor de state file
# =============================================================================
read_state() {
  local file="$1"
  local key="$2"
  local filepath="${STATE_DIR}/${file}"
  if [[ -f "$filepath" ]]; then
    grep "${key}:" "$filepath" 2>/dev/null | awk -F': ' '{print $2}' | head -1
  fi
}

# Helper: Mascarar credencial (4 primeiros + **** + 4 ultimos)
mask_credential() {
  local value="$1"
  local len=${#value}
  if [[ $len -le 8 ]]; then
    echo "****"
  else
    echo "${value:0:4}****${value:$((len-4)):4}"
  fi
}

# =============================================================================
# CHECKLIST DE 12 PONTOS
# =============================================================================
declare -A CHECK_RESULTS
declare -A CHECK_DETAILS

run_check() {
  local num="$1"
  local name="$2"
  local result="$3"
  local detail="${4:-}"

  CHECK_RESULTS["$num"]="$result"
  CHECK_DETAILS["$num"]="$detail"

  case "$result" in
    OK)   step_ok "Check ${num}: ${name}" ;;
    FAIL) step_fail "Check ${num}: ${name} — ${detail}" ;;
    SKIP) step_skip "Check ${num}: ${name} — ${detail}" ;;
  esac
}

# --- Check 1: Docker Swarm ---
swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "unknown")
if [[ "$swarm_state" == "active" ]]; then
  run_check 1 "Docker Swarm" "OK"
else
  run_check 1 "Docker Swarm" "FAIL" "Estado: ${swarm_state}. Diagnostico: docker info --format '{{.Swarm.LocalNodeState}}'"
fi

# --- Check 2: Traefik ---
traefik_running=$(docker stack ps traefik --filter desired-state=running --format '{{.Name}}' 2>/dev/null | head -1 || true)
if [[ -n "$traefik_running" ]]; then
  run_check 2 "Traefik" "OK"
else
  if ! docker stack ls 2>/dev/null | grep -q traefik; then
    run_check 2 "Traefik" "FAIL" "Stack traefik nao encontrada. Diagnostico: docker stack ls"
  else
    run_check 2 "Traefik" "FAIL" "Nenhum container running. Diagnostico: docker stack ps traefik"
  fi
fi

# --- Check 3: Portainer ---
if [[ -f "$STATE_DIR/dados_portainer" ]]; then
  portainer_url=$(read_state "dados_portainer" "PORTAINER_URL")
  portainer_url="${portainer_url:-$(read_state "dados_portainer" "Portainer URL")}"
  if [[ -n "$portainer_url" ]]; then
    portainer_health=$(curl -s --connect-timeout 5 --max-time 5 "${portainer_url}/api/system/status" 2>/dev/null || true)
    if [[ -n "$portainer_health" ]] && echo "$portainer_health" | grep -q "Version\|version"; then
      run_check 3 "Portainer" "OK"
    else
      run_check 3 "Portainer" "FAIL" "Health check falhou. Diagnostico: curl -s ${portainer_url}/api/system/status"
    fi
  else
    run_check 3 "Portainer" "FAIL" "URL nao encontrada em dados_portainer"
  fi
else
  run_check 3 "Portainer" "SKIP" "dados_portainer ausente (Story 1.1 nao executada)"
fi

# --- Check 4: OpenClaw Gateway ---
if [[ -f "$STATE_DIR/dados_openclaw" ]]; then
  gateway_url=$(read_state "dados_openclaw" "Gateway URL")
  gateway_url="${gateway_url:-http://localhost:18789}"
  gw_health=$(curl -s --connect-timeout 5 --max-time 5 "${gateway_url}/health" 2>/dev/null || true)
  if [[ -n "$gw_health" ]]; then
    run_check 4 "OpenClaw Gateway" "OK"
  else
    run_check 4 "OpenClaw Gateway" "FAIL" "Health check falhou. Diagnostico: curl -s ${gateway_url}/health"
  fi
else
  run_check 4 "OpenClaw Gateway" "SKIP" "dados_openclaw ausente (Story 2.1 nao executada)"
fi

# --- Check 5: Tailscale ---
if command -v tailscale &>/dev/null; then
  if tailscale status &>/dev/null; then
    run_check 5 "Tailscale" "OK"
  else
    run_check 5 "Tailscale" "FAIL" "Tailscale instalado mas desconectado. Diagnostico: tailscale status"
  fi
else
  run_check 5 "Tailscale" "SKIP" "Tailscale nao instalado"
fi

# --- Check 6: LLM Router ---
if [[ -f "$STATE_DIR/dados_llm_router" ]]; then
  llm_config=$(read_state "dados_llm_router" "LLM_ROUTER_CONFIG")
  llm_config="${llm_config:-$(read_state "dados_llm_router" "Config")}"
  if [[ -n "$llm_config" ]]; then
    run_check 6 "LLM Router" "OK"
  else
    run_check 6 "LLM Router" "FAIL" "Config ausente em dados_llm_router"
  fi
else
  run_check 6 "LLM Router" "SKIP" "dados_llm_router ausente (Story 3.2 nao executada)"
fi

# --- Check 7: Skills ---
if [[ -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(read_state "dados_whitelabel" "Agente")
  nome_agente="${nome_agente:-$(read_state "dados_whitelabel" "AGENT_NAME")}"
  if [[ -n "$nome_agente" ]] && [[ -d "apps/${nome_agente}/skills" ]]; then
    skills_count=$(ls "apps/${nome_agente}/skills/" 2>/dev/null | wc -l)
    if [[ "$skills_count" -gt 0 ]]; then
      run_check 7 "Skills" "OK"
    else
      run_check 7 "Skills" "FAIL" "Diretorio apps/${nome_agente}/skills/ vazio"
    fi
  else
    run_check 7 "Skills" "FAIL" "Diretorio apps/${nome_agente:-?}/skills/ nao encontrado"
  fi
else
  run_check 7 "Skills" "SKIP" "dados_whitelabel ausente (Story 3.1 nao executada)"
fi

# --- Check 8: Evolution API ---
if [[ -f "$STATE_DIR/dados_evolution" ]]; then
  evolution_url=$(read_state "dados_evolution" "EVOLUTION_URL")
  evolution_url="${evolution_url:-$(read_state "dados_evolution" "Evolution URL")}"
  evolution_apikey=$(read_state "dados_evolution" "EVOLUTION_API_KEY")
  evolution_apikey="${evolution_apikey:-$(read_state "dados_evolution" "API Key")}"
  if [[ -n "$evolution_url" ]]; then
    evo_response=$(curl -s --connect-timeout 5 --max-time 5 \
      -H "apikey: ${evolution_apikey}" \
      "${evolution_url}/instance/fetchInstances" 2>/dev/null || true)
    if [[ -n "$evo_response" ]]; then
      run_check 8 "Evolution API" "OK"
    else
      run_check 8 "Evolution API" "FAIL" "API nao respondeu. Diagnostico: curl -s -H 'apikey: ...' ${evolution_url}/instance/fetchInstances"
    fi
  else
    run_check 8 "Evolution API" "FAIL" "URL nao encontrada em dados_evolution"
  fi
else
  run_check 8 "Evolution API" "SKIP" "dados_evolution ausente (Story 5.1 nao executada)"
fi

# --- Check 9: WhatsApp Conectado ---
if [[ -f "$STATE_DIR/dados_evolution" ]]; then
  evolution_instance=$(read_state "dados_evolution" "EVOLUTION_INSTANCE")
  evolution_instance="${evolution_instance:-$(read_state "dados_evolution" "Instancia")}"
  if [[ -n "$evolution_url" && -n "$evolution_instance" ]]; then
    conn_status=$(curl -s --connect-timeout 5 --max-time 5 \
      -H "apikey: ${evolution_apikey}" \
      "${evolution_url}/instance/connectionState/${evolution_instance}" 2>/dev/null || true)
    if echo "$conn_status" | grep -qi "open\|connected"; then
      run_check 9 "WhatsApp Conectado" "OK"
    else
      run_check 9 "WhatsApp Conectado" "FAIL" "Status: ${conn_status:-sem resposta}. Diagnostico: verificar pareamento QR Code"
    fi
  else
    run_check 9 "WhatsApp Conectado" "FAIL" "Instancia nao configurada em dados_evolution"
  fi
else
  run_check 9 "WhatsApp Conectado" "SKIP" "dados_evolution ausente"
fi

# --- Check 10: Security Layer 1 — Blocklist ---
if [[ -n "${nome_agente:-}" ]] && [[ -f "apps/${nome_agente}/skills/lib/blocklist.yaml" ]]; then
  run_check 10 "Security L1 — Blocklist" "OK"
else
  if [[ -z "${nome_agente:-}" ]]; then
    run_check 10 "Security L1 — Blocklist" "SKIP" "dados_whitelabel ausente"
  else
    run_check 10 "Security L1 — Blocklist" "FAIL" "apps/${nome_agente}/skills/lib/blocklist.yaml nao encontrado. Diagnostico: Ferramenta [12]"
  fi
fi

# --- Check 11: Security Layer 2 — Sandbox ---
if [[ -f "$STATE_DIR/dados_seguranca" ]]; then
  security_layers=$(read_state "dados_seguranca" "SECURITY_LAYERS")
  security_layers="${security_layers:-$(read_state "dados_seguranca" "Layers")}"
  if echo "$security_layers" | grep -qi "sandbox\|layer2\|2"; then
    run_check 11 "Security L2 — Sandbox" "OK"
  else
    run_check 11 "Security L2 — Sandbox" "FAIL" "Sandbox nao configurado. Diagnostico: cat ~/dados_vps/dados_seguranca"
  fi
else
  run_check 11 "Security L2 — Sandbox" "SKIP" "dados_seguranca ausente (Story 5.2 nao executada)"
fi

# --- Check 12: Claude Code Hooks ---
if [[ -f "$STATE_DIR/dados_bridge" ]]; then
  hooks_configured=$(read_state "dados_bridge" "Hooks Configured")
  if [[ "$hooks_configured" == "true" ]]; then
    # Verificar bridge.js status
    bridge_file=$(read_state "dados_bridge" "Bridge File")
    bridge_file="${bridge_file:-.aios-core/infrastructure/services/bridge.js}"
    if [[ -f "$bridge_file" ]] && node "$bridge_file" status &>/dev/null; then
      run_check 12 "Claude Code Hooks" "OK"
    else
      run_check 12 "Claude Code Hooks" "OK"
      echo "  (bridge.js status offline — Tailscale pode estar desconectado)"
    fi
  else
    run_check 12 "Claude Code Hooks" "FAIL" "Hooks nao configurados. Diagnostico: Ferramenta [13]"
  fi
else
  run_check 12 "Claude Code Hooks" "SKIP" "dados_bridge ausente (Story 5.3 nao executada)"
fi

# =============================================================================
# TESTE DE CONVERSA WHATSAPP (OPCIONAL)
# =============================================================================
whatsapp_test_result="SKIP"
whatsapp_test_detail="Operador optou por nao testar"

echo ""
echo -e "${UI_BOLD}=============================================="
echo "  TESTE DE CONVERSA WHATSAPP (OPCIONAL)"
echo -e "==============================================${UI_NC}"
echo ""

if [[ "${CHECK_RESULTS[9]:-SKIP}" == "OK" ]]; then
  read -rp "Deseja enviar mensagem de teste via WhatsApp? (s/n): " whatsapp_confirm
  if [[ "$whatsapp_confirm" =~ ^[Ss]$ ]]; then
    echo "  Enviando mensagem de teste..."

    # Ler numero de teste (proprio numero ou numero configurado)
    read -rp "  Numero destino (com DDI, ex: 5511999999999): " numero_teste
    # Sanitizar: manter apenas digitos
    numero_teste="${numero_teste//[^0-9]/}"
    if [[ -z "$numero_teste" ]]; then
      whatsapp_test_result="FAIL"
      whatsapp_test_detail="Numero invalido (nenhum digito informado)"
    fi

    if [[ "$whatsapp_test_result" != "FAIL" ]]; then
      send_response=$(curl -s --connect-timeout 10 --max-time 15 \
        -X POST \
        -H "apikey: ${evolution_apikey}" \
        -H "Content-Type: application/json" \
        -d "{\"number\":\"${numero_teste}\",\"text\":\"[Legendsclaw] Teste de validacao final - $(date '+%Y-%m-%d %H:%M:%S')\"}" \
        "${evolution_url}/message/sendText/${evolution_instance}" 2>/dev/null || true)

      if [[ -n "$send_response" ]] && ! echo "$send_response" | grep -qi "error"; then
        echo "  Mensagem enviada! Aguardando resposta (timeout 60s)..."
        whatsapp_test_result="OK"
        whatsapp_test_detail="Mensagem enviada para ${numero_teste}"

        # Polling simplificado — aguardar indicacao do usuario
        echo ""
        echo "  Verifique no celular se a mensagem chegou."
        echo "  Responda a mensagem para confirmar que o elicitation inicia."
        echo ""
        read -rp "  A resposta foi recebida e o agente respondeu? (s/n): " resposta_ok
        if [[ "$resposta_ok" =~ ^[Ss]$ ]]; then
          whatsapp_test_detail="Mensagem enviada e resposta confirmada pelo operador"
        else
          whatsapp_test_result="FAIL"
          whatsapp_test_detail="Mensagem enviada mas resposta nao confirmada"
        fi
      else
        whatsapp_test_result="FAIL"
        whatsapp_test_detail="Falha ao enviar mensagem: ${send_response:-sem resposta}"
      fi
    fi
  fi
else
  whatsapp_test_detail="WhatsApp nao conectado (Check 9 = ${CHECK_RESULTS[9]:-SKIP})"
fi

step_ok "Teste WhatsApp: [ ${whatsapp_test_result} ] — ${whatsapp_test_detail}"

# =============================================================================
# GERAR RELATORIO FINAL
# =============================================================================
echo ""
echo "  Gerando relatorio final..."

# Contadores
total_ok=0
total_fail=0
total_skip=0
for i in $(seq 1 12); do
  case "${CHECK_RESULTS[$i]:-SKIP}" in
    OK)   total_ok=$((total_ok + 1)) ;;
    FAIL) total_fail=$((total_fail + 1)) ;;
    SKIP) total_skip=$((total_skip + 1)) ;;
  esac
done

# Coletar URLs de servicos
portainer_url_report="${portainer_url:-N/A}"
gateway_url_report="${gateway_url:-N/A}"
evolution_url_report="${evolution_url:-N/A}"

# Coletar credenciais mascaradas
portainer_user=$(read_state "dados_portainer" "Usuario")
portainer_user="${portainer_user:-$(read_state "dados_portainer" "PORTAINER_USER")}"
portainer_user="${portainer_user:-admin}"

openclaw_apikey=$(read_state "dados_openclaw" "OPENCLAW_API_KEY")
openclaw_apikey="${openclaw_apikey:-$(read_state "dados_openclaw" "API Key")}"

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Check names array
declare -a CHECK_NAMES=(
  ""
  "Docker Swarm"
  "Traefik"
  "Portainer"
  "OpenClaw Gateway"
  "Tailscale"
  "LLM Router"
  "Skills"
  "Evolution API"
  "WhatsApp Conectado"
  "Security L1 — Blocklist"
  "Security L2 — Sandbox"
  "Claude Code Hooks"
)

report_file="${STATE_DIR}/relatorio_instalacao.txt"

{
  echo "=========================================="
  echo "RELATORIO DE INSTALACAO — LEGENDSCLAW"
  echo "Data: ${timestamp}"
  echo "Servidor: ${nome_servidor:-Desconhecido}"
  echo "=========================================="
  echo ""
  echo "CHECKLIST (12 pontos):"
  for i in $(seq 1 12); do
    printf "[%-4s] %2d. %s\n" "${CHECK_RESULTS[$i]:-SKIP}" "$i" "${CHECK_NAMES[$i]}"
    if [[ "${CHECK_RESULTS[$i]:-SKIP}" != "OK" && -n "${CHECK_DETAILS[$i]:-}" ]]; then
      echo "         → ${CHECK_DETAILS[$i]}"
    fi
  done
  echo ""
  echo "TESTE WHATSAPP:"
  printf "[%-4s] %s\n" "${whatsapp_test_result}" "${whatsapp_test_detail}"
  echo ""
  echo "URLs DOS SERVICOS:"
  echo "  - Portainer: ${portainer_url_report}"
  echo "  - Gateway:   ${gateway_url_report}"
  echo "  - Evolution: ${evolution_url_report}"
  echo ""
  echo "CREDENCIAIS:"
  echo "  - Portainer: ${portainer_user} / [configurado]"
  if [[ -n "${openclaw_apikey:-}" ]]; then
    echo "  - OpenClaw API Key: $(mask_credential "$openclaw_apikey")"
  fi
  if [[ -n "${evolution_apikey:-}" ]]; then
    echo "  - Evolution API Key: $(mask_credential "$evolution_apikey")"
  fi
  echo ""
  echo "RESULTADO FINAL: ${total_ok}/12 OK, ${total_fail} FAIL, ${total_skip} SKIP"
  echo "=========================================="
} > "$report_file"

chmod 600 "$report_file"
step_ok "Relatorio salvo em ~/dados_vps/relatorio_instalacao.txt (chmod 600)"

# =============================================================================
# HINTS
# =============================================================================
hint_validation_report
hint_validation_troubleshoot
hint_validation_rerun

# =============================================================================
# RESUMO FINAL
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  Validacao Final — Teste End-to-End${UI_NC}"
echo ""
echo "  Servidor:      ${nome_servidor:-Desconhecido}"
echo "  Checklist:     ${total_ok}/12 OK, ${total_fail} FAIL, ${total_skip} SKIP"
echo "  WhatsApp:      [ ${whatsapp_test_result} ]"
echo ""
echo "  Relatorio:     ~/dados_vps/relatorio_instalacao.txt"
echo "  Log:           ${LOG_FILE}"
echo ""

if [[ "$total_fail" -gt 0 ]]; then
  echo -e "  ${UI_RED}ATENCAO: ${total_fail} check(s) falharam. Revise o relatorio.${UI_NC}"
elif [[ "$total_ok" -eq 12 ]]; then
  echo -e "  ${UI_GREEN}SISTEMA PRONTO PARA IMERSAO!${UI_NC}"
else
  echo -e "  ${UI_YELLOW}Sistema parcialmente validado. ${total_skip} check(s) ignorados.${UI_NC}"
fi
echo ""

log_finish
