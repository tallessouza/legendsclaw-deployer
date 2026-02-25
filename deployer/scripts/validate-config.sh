#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# Legendsclaw Deployer — Validate Config
# Verifica configs gerados antes de ativar o agente.
# Uso: ./validate-config.sh [agent_name]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYER_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${DEPLOYER_DIR}/lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"

# --- Detectar agent name ---
detect_agent_name() {
  # 1. Argumento CLI
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return 0
  fi

  # 2. Fallback: dados_whitelabel
  local wl_file="${STATE_DIR}/dados_whitelabel"
  if [[ -f "$wl_file" ]]; then
    local name
    name=$(grep "^agent_name:" "$wl_file" 2>/dev/null | awk -F': ' '{print $2}' || true)
    if [[ -n "$name" ]]; then
      echo "$name"
      return 0
    fi
  fi

  # 3. Fallback: prompt interativo
  if [[ -t 0 ]]; then
    read -rp "Nome do agente: " name </dev/tty
    if [[ -n "$name" ]]; then
      echo "$name"
      return 0
    fi
  fi

  echo ""
  return 1
}

# --- Variáveis obrigatórias ---
REQUIRED_VARS=(AGENT_NAME VPS_IP GATEWAY_HOSTNAME TAILNET_ID GATEWAY_PASSWORD HOOKS_TOKEN)
API_KEY_VARS=(OPENROUTER_API_KEY ANTHROPIC_ADMIN_KEY OPENAI_API_KEY GEMINI_API_KEY)

# --- Secret patterns (não devem aparecer fora do .env) ---
SECRET_PATTERNS=(
  'sk-or-v1-'
  'sk-ant-'
  'sk-proj-'
  'AIza'
)

# --- Main ---
main() {
  local agent_name
  agent_name=$(detect_agent_name "${1:-}") || true

  if [[ -z "$agent_name" ]]; then
    echo "ERRO: Nome do agente nao fornecido e nao detectado automaticamente."
    echo "Uso: $0 <agent_name>"
    exit 1
  fi

  local apps_dir="${DEPLOYER_DIR}/apps/${agent_name}"
  local config_dir="${apps_dir}/config"
  local env_file="${config_dir}/.env"

  log_init "validate-config"
  setup_trap

  echo ""
  echo -e "${UI_BOLD}Validando configuracao do agente: ${agent_name}${UI_NC}"
  echo ""

  step_init 7

  # --- AC1: .env existência e permissões ---
  if [[ ! -f "$env_file" ]]; then
    step_fail ".env nao encontrado em ${config_dir}/"
  else
    local perms
    perms=$(stat -c '%a' "$env_file" 2>/dev/null || echo "???")
    if [[ "$perms" == "600" ]]; then
      step_ok ".env existe com permissoes ${perms}"
    else
      step_fail ".env existe mas permissoes sao ${perms} (esperado: 600)"
    fi
  fi

  # --- AC2: Placeholders não resolvidos ---
  if [[ ! -d "$config_dir" ]]; then
    step_skip "Diretorio config/ nao existe — nada a verificar"
  else
    local placeholder_hits
    placeholder_hits=$(grep -rn '{{' "$config_dir"/ 2>/dev/null | grep -v '\.env' || true)
    if [[ -z "$placeholder_hits" ]]; then
      step_ok "Nenhum placeholder {{...}} nao resolvido"
    else
      step_fail "Placeholders nao resolvidos encontrados:"
      echo "$placeholder_hits" | while IFS= read -r line; do
        echo "    $line"
      done
    fi
  fi

  # --- AC3: JSON syntax ---
  local json_files=(aiosbot.json node.json mcp-config.json)
  local json_errors=0
  local json_checked=0
  for jf in "${json_files[@]}"; do
    local jpath="${config_dir}/${jf}"
    if [[ -f "$jpath" ]]; then
      json_checked=$((json_checked + 1))
      if ! node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$jpath" 2>/dev/null; then
        echo "    JSON invalido: ${jf}"
        json_errors=$((json_errors + 1))
      fi
    fi
  done
  if [[ $json_checked -eq 0 ]]; then
    step_skip "Nenhum JSON config encontrado para validar"
  elif [[ $json_errors -eq 0 ]]; then
    step_ok "JSON syntax OK (${json_checked} arquivos verificados)"
  else
    step_fail "JSON syntax invalido em ${json_errors}/${json_checked} arquivos"
  fi

  # --- AC4: Variáveis obrigatórias ---
  if [[ ! -f "$env_file" ]]; then
    step_fail "Variaveis obrigatorias: .env nao existe"
  else
    local missing_vars=()
    for var in "${REQUIRED_VARS[@]}"; do
      if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
        missing_vars+=("$var")
      elif [[ -z "$(grep "^${var}=" "$env_file" | cut -d= -f2-)" ]]; then
        missing_vars+=("${var} (vazio)")
      fi
    done

    # Check pelo menos uma API key
    local has_api_key=false
    for var in "${API_KEY_VARS[@]}"; do
      local val
      val=$(grep "^${var}=" "$env_file" 2>/dev/null | cut -d= -f2- || true)
      if [[ -n "$val" ]]; then
        has_api_key=true
        break
      fi
    done

    local var_issues=()
    [[ ${#missing_vars[@]} -gt 0 ]] && var_issues+=("faltando: ${missing_vars[*]}")
    [[ "$has_api_key" == "false" ]] && var_issues+=("nenhuma API key configurada (OPENROUTER_API_KEY|ANTHROPIC_ADMIN_KEY|OPENAI_API_KEY|GEMINI_API_KEY)")

    if [[ ${#var_issues[@]} -eq 0 ]]; then
      step_ok "Variaveis obrigatorias presentes"
    else
      step_fail "Variaveis obrigatorias com problemas:"
      for issue in "${var_issues[@]}"; do
        echo "    - ${issue}"
      done
    fi
  fi

  # --- AC5: Secrets vazados em non-.env ---
  if [[ ! -d "$config_dir" ]]; then
    step_skip "Diretorio config/ nao existe — nada a escanear"
  else
    local secret_hits=""
    for pattern in "${SECRET_PATTERNS[@]}"; do
      local hits
      hits=$(grep -rn "$pattern" "$config_dir"/ 2>/dev/null | grep -v '\.env' || true)
      if [[ -n "$hits" ]]; then
        secret_hits+="${hits}"$'\n'
      fi
    done
    if [[ -z "$secret_hits" ]]; then
      step_ok "Nenhum secret vazado em arquivos non-.env"
    else
      step_fail "Secrets detectados fora do .env:"
      echo "$secret_hits" | while IFS= read -r line; do
        [[ -n "$line" ]] && echo "    $line"
      done
    fi
  fi

  # --- AC6: Ports disponíveis ---
  local ports=(18789 55119)
  local port_issues=0
  for port in "${ports[@]}"; do
    local port_info
    port_info=$(ss -tlnp "sport = :${port}" 2>/dev/null | tail -n +2 || true)
    if [[ -n "$port_info" ]]; then
      local proc
      proc=$(echo "$port_info" | grep -oP 'users:\(\("\K[^"]+' || echo "desconhecido")
      echo "    Porta ${port} em uso por: ${proc}"
      port_issues=$((port_issues + 1))
    fi
  done
  if [[ $port_issues -eq 0 ]]; then
    step_ok "Portas 18789 e 55119 disponiveis"
  else
    step_fail "${port_issues} porta(s) ja em uso"
  fi

  # --- Resumo ---
  resumo_final

  # Exit code baseado em falhas
  if [[ $STEP_FAIL -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
