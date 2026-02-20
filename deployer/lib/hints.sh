#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Contextual Hints
# hint_firewall(), hint_dns(), hint_provider()
# =============================================================================

# Hint de firewall — tabela de portas necessarias
# Uso: hint_firewall
hint_firewall() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: CONFIGURACAO DE FIREWALL"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Antes de prosseguir, certifique-se de que as"
  echo "  seguintes portas estao abertas no firewall da VPS:"
  echo ""
  echo "  Porta       Protocolo   Servico"
  echo "  -----       ---------   -------"
  echo "  22          TCP         SSH"
  echo "  80          TCP         HTTP (Traefik)"
  echo "  443         TCP         HTTPS (Traefik)"
  echo "  9443        TCP         Portainer"
  echo "  2377        TCP         Docker Swarm manager"
  echo "  7946        TCP+UDP     Swarm node communication"
  echo "  4789        UDP         Overlay network"
  echo "  41641       UDP         Tailscale"
  echo ""
  echo "  No painel Hetzner: Networking > Firewalls"
  echo "  No painel AWS: Security Groups > Inbound Rules"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de DNS — registros A necessarios
# Uso: hint_dns "$dominio_portainer"
hint_dns() {
  local dominio="${1:-portainer.exemplo.com}"
  local ip_vps
  ip_vps=$(curl -s https://ifconfig.me 2>/dev/null || echo "SEU_IP_VPS")

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: CONFIGURACAO DE DNS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Configure os seguintes registros DNS tipo A:"
  echo ""
  echo "  Tipo   Nome                        Valor"
  echo "  ----   ----                        -----"
  echo "  A      ${dominio}    ${ip_vps}"
  echo ""
  echo "  Propagacao DNS pode levar 5-30 minutos."
  echo "  Verifique com: dig ${dominio} +short"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de provider — dicas especificas por cloud provider
# Uso: hint_provider "hetzner"
hint_provider() {
  local provider="${1:-hetzner}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: DICAS ${provider^^}"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  case "$provider" in
    hetzner)
      echo "  - Firewall: Cloud Console > Networking > Firewalls"
      echo "  - DNS: Pode usar Cloudflare ou Hetzner DNS"
      echo "  - Servidor recomendado: CX21+ (2 vCPU, 4GB RAM)"
      echo "  - Datacenter: Helsinki (hel1) ou Falkenstein (fsn1)"
      ;;
    aws)
      echo "  - Firewall: EC2 > Security Groups"
      echo "  - DNS: Route 53 ou externo"
      echo "  - Instancia recomendada: t3.medium+"
      ;;
    *)
      echo "  - Configure firewall conforme tabela de portas acima"
      echo "  - Configure DNS A records para seus dominios"
      ;;
  esac

  echo ""
  echo "=============================================="
  echo ""
}

# Hint de setup Tailscale no desktop
# Uso: hint_tailscale_desktop "$hostname" "$ip" "$ambiente"
hint_tailscale_desktop() {
  local hostname="${1:-meu-gateway}"
  local ip="${2:-TAILSCALE_IP}"
  local ambiente="${3:-vps}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: INSTALAR TAILSCALE NO DESKTOP"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  echo "  Windows:"
  echo "    Baixe: https://tailscale.com/download/windows"
  echo "    Ou via winget: winget install Tailscale.Tailscale"
  echo ""
  echo "  Mac:"
  echo "    brew install --cask tailscale"
  echo "    Ou App Store: pesquise 'Tailscale'"
  echo ""
  echo "  WSL2 (Linux):"
  echo "    curl -fsSL https://tailscale.com/install.sh | sh"
  echo "    sudo tailscale up"
  echo ""

  if [[ "$ambiente" == "vps" ]]; then
    echo "  Apos instalar no desktop, autentique com a"
    echo "  mesma conta Tailscale usada na VPS."
  else
    echo "  Apos instalar no desktop, autentique com a"
    echo "  mesma conta Tailscale usada nesta maquina."
  fi
  echo ""
  echo "  Verifique conectividade com:"
  echo "    tailscale ping ${hostname}"
  echo ""
  echo "  IP Tailscale desta maquina: ${ip}"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de DNS para OpenClaw Gateway
# Uso: hint_dns_openclaw "$dominio"
hint_dns_openclaw() {
  local dominio="${1:-gw.exemplo.com}"
  local ip_vps
  ip_vps=$(curl -s https://ifconfig.me 2>/dev/null || echo "SEU_IP_VPS")

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: DNS PARA OPENCLAW GATEWAY"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Configure o registro DNS tipo A:"
  echo ""
  echo "  Tipo   Nome                        Valor"
  echo "  ----   ----                        -----"
  echo "  A      ${dominio}    ${ip_vps}"
  echo ""
  echo "  Propagacao DNS pode levar 5-30 minutos."
  echo "  Verifique com: dig ${dominio} +short"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de troubleshooting para OpenClaw Gateway
# Uso: hint_troubleshoot_openclaw "$porta" "$dominio"
hint_troubleshoot_openclaw() {
  local porta="${1:-18789}"
  local dominio="${2:-}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: TROUBLESHOOTING OPENCLAW"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Verificar status do servico:"
  echo "    systemctl status openclaw"
  echo ""
  echo "  Ver logs em tempo real:"
  echo "    journalctl -u openclaw -f"
  echo ""
  echo "  Verificar porta:"
  echo "    ss -tlnp | grep ${porta}"
  echo ""
  echo "  Health check manual:"
  echo "    curl http://localhost:${porta}/health"
  echo ""
  echo "  Verificar conectividade Tailscale:"
  echo "    tailscale status"
  if [[ -n "$dominio" ]]; then
    echo "    curl https://${dominio}/health"
  fi
  echo ""
  echo "  Reiniciar servico:"
  echo "    systemctl restart openclaw"
  echo ""
  echo "  Verificar diagnostico:"
  echo "    cd /opt/openclaw && pnpm openclaw doctor"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de validacao gateway — hints contextuais por tipo de erro
# Uso: hint_validacao_gw "$tailscale_result" "$service_result" "$doctor_result" "$health_result" "$mensagem_result" "$porta"
hint_validacao_gw() {
  local tailscale_result="${1:-PASS}"
  local service_result="${2:-PASS}"
  local doctor_result="${3:-PASS}"
  local health_result="${4:-PASS}"
  local mensagem_result="${5:-PASS}"
  local porta="${6:-18789}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: RESOLUCAO DE PROBLEMAS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  if [[ "$tailscale_result" == "FAIL" ]]; then
    echo "  TAILSCALE DESCONECTADO:"
    echo "    tailscale up"
    echo "    tailscale status"
    echo "    # Se auth expirada:"
    echo "    tailscale up --reset"
    echo ""
  fi

  if [[ "$service_result" == "FAIL" ]]; then
    echo "  OPENCLAW SERVICE PARADO:"
    echo "    systemctl start openclaw"
    echo "    systemctl status openclaw"
    echo "    journalctl -u openclaw --no-pager -n 50"
    echo ""
  fi

  if [[ "$doctor_result" == "FAIL" ]]; then
    echo "  OPENCLAW DOCTOR FALHOU:"
    echo "    cd /opt/openclaw && pnpm openclaw doctor --verbose"
    echo "    # Verificar dependencias:"
    echo "    node --version  # deve ser >= 22"
    echo "    pnpm --version"
    echo ""
  fi

  if [[ "$health_result" == "FAIL" ]]; then
    echo "  HEALTH CHECK FALHOU:"
    echo "    # Verificar se porta esta escutando:"
    echo "    ss -tlnp | grep ${porta}"
    echo "    # Verificar logs:"
    echo "    journalctl -u openclaw -f"
    echo "    # Restart:"
    echo "    systemctl restart openclaw"
    echo ""
  fi

  if [[ "$mensagem_result" == "FAIL" ]]; then
    echo "  TESTE DE MENSAGEM FALHOU:"
    echo "    cd /opt/openclaw"
    echo "    pnpm openclaw agent --message \"Teste\" --thinking high --verbose"
    echo "    # Verificar configuracao de LLM providers"
    echo "    # Verificar logs: journalctl -u openclaw -f"
    echo ""
  fi

  echo "=============================================="
  echo ""
}

# Hint de proximos passos para whitelabel
# Uso: hint_whitelabel "$nome_agente"
hint_whitelabel() {
  local nome_agente="${1:-meu-agente}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Configurar LLM Router:"
  echo "     deployer.sh → Ferramenta [08]"
  echo ""
  echo "  2. Editar credenciais no config.js:"
  echo "     apps/${nome_agente}/skills/config.js"
  echo ""
  echo "  3. Criar definicao AIOS do agente no desktop:"
  echo "     No Claude Code: @aios-master *create agent"
  echo "     Ou manualmente: .aios-core/development/agents/${nome_agente}.md"
  echo "     (requer AIOS Core instalado no projeto)"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de debug e proximos passos para LLM Router
# Uso: hint_llm_router "$nome_agente"
hint_skills() {
  local nome_agente="${1:-meu-agente}"
  shift || true
  local skills=("$@")

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: SKILLS — DEBUG E PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  local has_skill=false
  for s in "${skills[@]}"; do
    case "$s" in
      clickup-ops)
        has_skill=true
        echo "  ClickUp:"
        echo "    curl -s -H 'Authorization: \$CLICKUP_API_KEY' \\"
        echo "      https://api.clickup.com/api/v2/team"
        echo ""
        ;;
      n8n-trigger)
        has_skill=true
        echo "  N8N:"
        echo "    curl -s -H 'X-N8N-API-KEY: \$N8N_API_KEY' \\"
        echo "      \$N8N_WEBHOOK_URL/healthz"
        echo ""
        ;;
      supabase-query)
        has_skill=true
        echo "  Supabase:"
        echo "    curl -s -H 'apikey: \$SUPABASE_ANON_KEY' \\"
        echo "      \$SUPABASE_URL/rest/v1/"
        echo ""
        ;;
      allos-status)
        has_skill=true
        echo "  Gateway:"
        echo "    curl -s \$AGENT_GATEWAY_URL/health"
        echo ""
        ;;
      alerts)
        has_skill=true
        echo "  Slack:"
        echo "    curl -X POST \$SLACK_ALERTS_WEBHOOK_URL \\"
        echo "      -d '{\"text\":\"test\"}'"
        echo ""
        ;;
      memory)
        has_skill=true
        echo "  Memory:"
        echo "    ls ~/.clawd/memory/"
        echo ""
        ;;
    esac
  done

  echo "  Config: apps/${nome_agente}/skills/config.js"
  echo "  Index:  apps/${nome_agente}/skills/index.js"
  echo ""
  echo "  Proximo: configurar Elicitation skill (Story 4.2)"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de debug e proximos passos para Elicitation skill
# Uso: hint_elicitation "$nome_agente" "$tables_status" "$llm_enabled"
hint_elicitation() {
  local nome_agente="${1:-meu-agente}"
  local tables_status="${2:-UNKNOWN}"
  local llm_enabled="${3:-false}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: ELICITATION — DEBUG E PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Verificar skill registrada:"
  echo "     node -e \"const s = require('./apps/${nome_agente}/skills/elicitation'); console.log(s.name, Object.keys(s.tools))\""
  echo ""
  echo "  2. Health check manual:"
  echo "     node -e \"require('./apps/${nome_agente}/skills/elicitation').health().then(console.log)\""
  echo ""
  echo "  3. Supabase conectividade:"
  echo "     curl -s -H 'apikey: \$SUPABASE_SERVICE_ROLE_KEY' \\"
  echo "       \$SUPABASE_URL/rest/v1/"
  echo ""

  if [[ "$tables_status" != "OK" ]]; then
    echo "  4. Criar tabelas (Story 4.3):"
    echo "     Aplique a migration SQL no Supabase SQL Editor"
    echo "     ou execute: deployer.sh → Ferramenta [11] (quando disponivel)"
    echo ""
  fi

  if [[ "$llm_enabled" == "true" ]]; then
    echo "  LLM Extraction (habilitado):"
    echo "     Tier standard: anthropic/claude-3.5-haiku via OpenRouter"
    echo "     Tier budget: deepseek/deepseek-chat (follow-ups)"
    echo "     Testar: curl -H 'Authorization: Bearer \$OPENROUTER_API_KEY' \\"
    echo "       https://openrouter.ai/api/v1/models"
    echo ""
  else
    echo "  LLM Extraction (desabilitado):"
    echo "     Usando extracao basica (regex). Para habilitar:"
    echo "     Execute Ferramenta [08] LLM Router (Story 3.2)"
    echo ""
  fi

  echo "  Memory Manager:"
  echo "     Arquivos exportados para: ~/.clawd/memory/elicitation/"
  echo "     Verificar: ls -la ~/.clawd/memory/elicitation/"
  echo ""

  echo "  Config: apps/${nome_agente}/skills/config.js"
  echo "  Skill:  apps/${nome_agente}/skills/elicitation/"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de debug e proximos passos para Elicitation Schema
# Uso: hint_elicitation_schema
hint_elicitation_schema() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: ELICITATION SCHEMA — DEBUG E PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Aplicar migration no Supabase:"
  echo "     Dashboard → SQL Editor → colar deployer/migrations/001-elicitation-tables.sql → Run"
  echo ""
  echo "  2. Aplicar seed:"
  echo "     Dashboard → SQL Editor → colar deployer/seeds/001-onboarding-founder.sql → Run"
  echo ""
  echo "  3. Verificar no Table Editor:"
  echo "     Confirme 3 tabelas: elicitation_templates, elicitation_sessions, elicitation_results"
  echo "     Confirme 1 registro em elicitation_templates: onboarding-founder"
  echo ""
  echo "  4. Verificar RLS habilitado:"
  echo "     Table Editor → cada tabela → RLS deve estar 'Enabled'"
  echo ""
  echo "  5. Testar via REST:"
  echo "     curl -s -H 'apikey: \$SUPABASE_SERVICE_ROLE_KEY' \\"
  echo "       -H 'Authorization: Bearer \$SUPABASE_SERVICE_ROLE_KEY' \\"
  echo "       \$SUPABASE_URL/rest/v1/elicitation_templates"
  echo ""
  echo "  Proximo: integrar LLM Router e Memory (Story 4.4)"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de preparacao WhatsApp pre-pareamento
# Uso: hint_whatsapp_prep
hint_whatsapp_prep() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: PREPARACAO WHATSAPP"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Antes do pareamento, certifique-se:"
  echo ""
  echo "  1. Chip eSIM ativo e com creditos"
  echo "  2. WhatsApp instalado no telefone"
  echo "  3. Desabilitar verificacao em 2 etapas (temporariamente)"
  echo "  4. NAO estar logado em WhatsApp Web em outro lugar"
  echo "  5. Manter recargas periodicas para manter numero ativo"
  echo ""
  echo "  O numero sera pareado via QR Code apos o deploy."
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de pareamento WhatsApp via QR Code
# Uso: hint_whatsapp_qr "$manager_url" "$instance_name"
hint_whatsapp_qr() {
  local manager_url="${1:-https://api.exemplo.com}"
  local instance_name="${2:-legendsclaw}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: PAREAMENTO WHATSAPP — QR CODE"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Step 1: Abrir Manager Evolution no navegador:"
  echo "    ${manager_url}/manager"
  echo ""
  echo "  Step 2: Clicar na instancia '${instance_name}'"
  echo ""
  echo "  Step 3: Escanear QR Code com WhatsApp no celular"
  echo "    (WhatsApp > Dispositivos conectados > Conectar dispositivo)"
  echo ""
  echo "  Step 4: Aguardar confirmacao de conexao (status: open)"
  echo "    O QR Code expira em ~60 segundos."
  echo "    Se expirar, recarregue a pagina e escaneie novamente."
  echo ""
  echo "  Step 5: Enviar mensagem de teste para confirmar"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de debug Evolution API
# Uso: hint_evolution_debug "$dominio" "$apikey" "$instance_name" "$stack_name"
hint_evolution_debug() {
  local dominio="${1:-api.exemplo.com}"
  local apikey="${2:-SUA_API_KEY}"
  local instance_name="${3:-legendsclaw}"
  local stack_name="${4:-evolution}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: EVOLUTION API — DEBUG"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Manager URL:"
  echo "    https://${dominio}/manager"
  echo ""
  echo "  Listar instancias:"
  echo "    curl -s -H 'apikey: ${apikey}' \\"
  echo "      https://${dominio}/instance/fetchInstances"
  echo ""
  echo "  Ver status instancia:"
  echo "    curl -s -H 'apikey: ${apikey}' \\"
  echo "      https://${dominio}/instance/connectionState/${instance_name}"
  echo ""
  echo "  Logs Docker:"
  echo "    docker service logs ${stack_name}_api --tail 100 -f"
  echo ""
  echo "  Restart service:"
  echo "    docker service update --force ${stack_name}_api"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de seguranca blocklist — verificacao Layer 1
# Uso: hint_seguranca_blocklist "$nome_agente"
hint_seguranca_blocklist() {
  local nome_agente="${1:-meu-agente}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: SEGURANCA LAYER 1 — BLOCKLIST"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Ver regras:"
  echo "    cat apps/${nome_agente}/skills/lib/blocklist.yaml"
  echo ""
  echo "  Testar matching:"
  echo "    grep \"rm -rf\" apps/${nome_agente}/skills/lib/blocklist.yaml"
  echo ""
  echo "  Editar regras:"
  echo "    nano apps/${nome_agente}/skills/lib/blocklist.yaml"
  echo ""
  echo "  Nota: teste de bloqueio em tempo real requer"
  echo "  Bridge.js (Story 5.3)"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de seguranca sandbox — verificacao Layer 2
# Uso: hint_seguranca_sandbox
hint_seguranca_sandbox() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: SEGURANCA LAYER 2 — SANDBOX"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Verificar container:"
  echo "    docker ps --filter name=sandbox"
  echo ""
  echo "  Testar isolamento de rede (deve falhar):"
  echo "    docker exec sandbox ping -c1 8.8.8.8"
  echo ""
  echo "  Verificar read-only (deve falhar):"
  echo "    docker exec sandbox touch /tmp/test"
  echo ""
  echo "  Ver limites de recursos:"
  echo "    docker stats sandbox --no-stream"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de seguranca logging — verificacao Layer 3
# Uso: hint_seguranca_logging
hint_seguranca_logging() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: SEGURANCA LAYER 3 — LOGGING"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Ver logs em tempo real:"
  echo "    journalctl -f -t legendsclaw"
  echo ""
  echo "  Verificar retencao:"
  echo "    journalctl --disk-usage"
  echo ""
  echo "  Ver rotacao:"
  echo "    ls -la /var/log/legendsclaw/"
  echo ""
  echo "  Testar logrotate:"
  echo "    sudo logrotate -f /etc/logrotate.d/legendsclaw"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de Bridge status — output esperado no SessionStart
# Uso: hint_bridge_status "$nome_agente"
hint_bridge_status() {
  local nome_agente="${1:-meu-agente}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: BRIDGE STATUS — OUTPUT ESPERADO"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Ao iniciar uma sessao Claude Code, voce vera:"
  echo ""
  echo "    =============================================="
  echo "    BRIDGE STATUS"
  echo "    =============================================="
  echo "    Service              Status         Latency"
  echo "    ${nome_agente}       OK             42ms"
  echo "    =============================================="
  echo ""
  echo "  Status possiveis:"
  echo "    OK       — Gateway respondendo normalmente"
  echo "    DEGRADED — Gateway lento (>2000ms)"
  echo "    FAIL     — Gateway nao respondeu"
  echo ""
  echo "  Se aparecer '[Bridge] Offline':"
  echo "    Tailscale pode estar desconectado"
  echo "    Execute: tailscale up"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de Bridge hooks — verificacao e troubleshooting
# Uso: hint_bridge_hooks
hint_bridge_hooks() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: BRIDGE HOOKS — VERIFICACAO"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Hooks configurados em .claude/settings.json:"
  echo ""
  echo "  SessionStart:"
  echo "    Executa 'bridge.js status' automaticamente"
  echo "    Mostra saude dos servicos ao iniciar sessao"
  echo ""
  echo "  PreToolUse (Bash):"
  echo "    Executa 'bridge.js validate-call' antes de Bash"
  echo "    Valida contra blocklist de seguranca (Layer 1)"
  echo ""
  echo "  PostToolUse (Bash):"
  echo "    Executa 'bridge.js log-execution' apos Bash"
  echo "    Registra no audit trail para auditoria"
  echo ""
  echo "  Verificar hooks ativos:"
  echo "    cat .claude/settings.json | grep bridge"
  echo ""
  echo "  Ver audit trail:"
  echo "    tail -20 ~/legendsclaw-logs/bridge-audit.log"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de Bridge debug — comandos manuais
# Uso: hint_bridge_debug "$nome_agente" "$gateway_url"
hint_bridge_debug() {
  local nome_agente="${1:-meu-agente}"
  local gateway_url="${2:-http://localhost:18789}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: BRIDGE DEBUG"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Testar bridge manualmente:"
  echo "    node .aios-core/infrastructure/services/bridge.js status"
  echo "    node .aios-core/infrastructure/services/bridge.js list"
  echo ""
  echo "  Testar conectividade com gateway:"
  echo "    curl -s ${gateway_url}/health"
  echo ""
  echo "  Verificar Tailscale:"
  echo "    tailscale status"
  echo "    tailscale ping \$(hostname)"
  echo ""
  echo "  Ver audit log:"
  echo "    tail -f ~/legendsclaw-logs/bridge-audit.log"
  echo ""
  echo "  Verificar servico ${nome_agente}:"
  echo "    node -e \"require('./.aios-core/infrastructure/services/${nome_agente}').health().then(console.log)\""
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de como interpretar o relatorio de validacao final
# Uso: hint_validation_report
hint_validation_report() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: COMO INTERPRETAR O RELATORIO"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  [OK]   — Componente funcionando corretamente"
  echo "  [FAIL] — Componente com problema (ver diagnostico)"
  echo "  [SKIP] — Componente nao instalado (dependencia ausente)"
  echo ""
  echo "  SKIP nao e um erro — significa que a ferramenta"
  echo "  correspondente ainda nao foi executada."
  echo ""
  echo "  FAIL requer atencao — execute o diagnostico indicado"
  echo "  e reexecute a ferramenta correspondente se necessario."
  echo ""
  echo "  Relatorio: ~/dados_vps/relatorio_instalacao.txt"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de troubleshooting por componente
# Uso: hint_validation_troubleshoot
hint_validation_troubleshoot() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: DEBUG POR COMPONENTE"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Docker Swarm:    docker info | grep Swarm"
  echo "  Traefik:         docker stack ps traefik"
  echo "  Portainer:       curl https://{URL}/api/system/status"
  echo "  OpenClaw:        curl http://{URL}/health"
  echo "  Tailscale:       tailscale status"
  echo "  LLM Router:      cat ~/dados_vps/dados_llm_router"
  echo "  Skills:          ls apps/{agente}/skills/"
  echo "  Evolution:       curl -H 'apikey: ...' {URL}/instance/fetchInstances"
  echo "  WhatsApp:        verificar pareamento QR Code"
  echo "  Blocklist:       cat apps/{agente}/skills/lib/blocklist.yaml"
  echo "  Sandbox:         cat ~/dados_vps/dados_seguranca"
  echo "  Hooks:           cat .claude/settings.json | grep bridge"
  echo ""
  echo "=============================================="
  echo ""
}

# Hint de como re-executar a validacao
# Uso: hint_validation_rerun
hint_validation_rerun() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: RE-EXECUTAR VALIDACAO"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  Apos corrigir componentes com FAIL:"
  echo ""
  echo "  1. Corrija o problema usando o diagnostico indicado"
  echo "  2. Re-execute: deployer.sh → Ferramenta [14]"
  echo "  3. O relatorio sera sobrescrito com resultados atualizados"
  echo ""
  echo "  Cada execucao gera um novo log em ~/legendsclaw-logs/"
  echo "  para manter historico de tentativas."
  echo ""
  echo "=============================================="
  echo ""
}

hint_llm_router() {
  local nome_agente="${1:-meu-agente}"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: LLM ROUTER — DEBUG E PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Verificar keys configuradas:"
  echo "     grep API_KEY /opt/openclaw/.env"
  echo ""
  echo "  2. Testar manualmente:"
  echo "     curl -H 'Authorization: Bearer \$OPENROUTER_API_KEY' \\"
  echo "       https://openrouter.ai/api/v1/models"
  echo ""
  echo "  3. Config do router:"
  echo "     apps/${nome_agente}/config/llm-router-config.yaml"
  echo ""
  echo "  4. Proximo: configurar skills do agente (Epics futuros)"
  echo ""
  echo "=============================================="
  echo ""
}
