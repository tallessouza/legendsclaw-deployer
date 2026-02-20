#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 04: Tailscale VPN Mesh
# Story 1.4: Instala e configura Tailscale para mesh VPN
# Dual-mode: local e VPS
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
log_init "tailscale"
step_init 9

# =============================================================================
# STEP 2: RESOURCE GATE — verificar curl disponivel
# =============================================================================
if command -v curl &>/dev/null; then
  step_ok "curl disponivel"
else
  step_fail "curl nao encontrado — necessario para instalacao Tailscale"
  echo "Instale curl: apt install -y curl"
  exit 1
fi

# =============================================================================
# STEP 3: LOAD STATE
# =============================================================================
dados
step_ok "Estado carregado"

# =============================================================================
# STEP 4: VERIFICAR SE TAILSCALE JA ESTA INSTALADO
# =============================================================================
tailscale_ja_instalado=false
if command -v tailscale &>/dev/null; then
  tailscale_ja_instalado=true
  step_skip "Tailscale ja instalado ($(tailscale version 2>/dev/null | head -1 || echo 'versao desconhecida'))"
else
  # STEP 5: INSTALAR TAILSCALE
  instalado=false
  for tentativa in 1 2 3; do
    echo "  Tentativa ${tentativa}/3: Instalando Tailscale..."
    if curl -fsSL https://tailscale.com/install.sh | sh; then
      instalado=true
      break
    else
      echo "  Falha na tentativa ${tentativa}/3 (exit code: $?)"
      if [[ "$tentativa" -lt 3 ]]; then
        sleep 5
      fi
    fi
  done

  if $instalado; then
    step_ok "Tailscale instalado com sucesso"
  else
    step_fail "Falha ao instalar Tailscale apos 3 tentativas"
    exit 1
  fi
fi

# =============================================================================
# STEP 6: INPUT COLLECTION — hostname Tailscale
# =============================================================================
ambiente=$(detectar_ambiente)

while true; do
  echo ""
  read -rp "Hostname Tailscale (ex: legendsclaw-gw): " hostname_tailscale

  if [[ -z "$hostname_tailscale" ]]; then
    echo "Hostname nao pode ser vazio."
    continue
  fi

  conferindo_as_info "Hostname Tailscale=${hostname_tailscale}" "Ambiente=${ambiente}"

  read -rp "As informacoes estao corretas? (s/n): " confirma
  if [[ "$confirma" =~ ^[Ss]$ ]]; then
    break
  fi
done

step_ok "Inputs coletados"

# =============================================================================
# STEP 7: AUTENTICAR TAILSCALE
# =============================================================================
echo ""
echo -e "${UI_BOLD}Iniciando autenticacao Tailscale...${UI_NC}"
echo ""
echo "  IMPORTANTE: Tailscale vai exibir um link de autenticacao."
echo "  Copie o link e abra no navegador para autorizar esta maquina."
echo ""

tailscale up --hostname="$hostname_tailscale" &
ts_pid=$!

# Polling: aguardar autenticacao (timeout 5 min = 30 iter x 10s)
autenticado=false
for iter in $(seq 1 30); do
  sleep 10
  ts_status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "")
  if [[ "$ts_status" == "Running" ]]; then
    autenticado=true
    break
  fi
  echo "  Aguardando autenticacao... (${iter}/30)"
done

# Cleanup background process if still running
if kill -0 "$ts_pid" 2>/dev/null; then
  wait "$ts_pid" 2>/dev/null || true
fi

if $autenticado; then
  step_ok "Tailscale autenticado com sucesso"
else
  step_fail "Timeout aguardando autenticacao Tailscale (5 min)"
  echo "  Execute manualmente: tailscale up --hostname=${hostname_tailscale}"
  exit 1
fi

# =============================================================================
# STEP 8: VERIFICAR CONECTIVIDADE
# =============================================================================
ip_tailscale=$(tailscale ip -4 2>/dev/null || echo "desconhecido")

if tailscale status &>/dev/null; then
  step_ok "Conectividade verificada — IP: ${ip_tailscale}"
else
  step_fail "Falha na verificacao de conectividade"
  exit 1
fi

# =============================================================================
# STEP 8b: HINTS DE SETUP LOCAL
# =============================================================================
hint_tailscale_desktop "$hostname_tailscale" "$ip_tailscale" "$ambiente"

step_ok "Hints de setup desktop exibidos"

# =============================================================================
# STEP 8c: TAILSCALE FUNNEL (OPCIONAL)
# =============================================================================
funnel_ativo="Inativo"
porta_funnel=""

echo ""
read -rp "Deseja habilitar Tailscale Funnel para HTTPS publico? (s/N): " habilitar_funnel

if [[ "$habilitar_funnel" =~ ^[Ss]$ ]]; then
  read -rp "Porta para Funnel (default 18789): " porta_funnel_input
  porta_funnel="${porta_funnel_input:-18789}"

  if tailscale funnel "$porta_funnel" &>/dev/null; then
    funnel_ativo="Ativo"
    step_ok "Tailscale Funnel habilitado na porta ${porta_funnel}"
  else
    step_skip "Tailscale Funnel nao suportado (requer HTTPS certs do Tailscale)"
    porta_funnel=""
  fi
else
  step_skip "Tailscale Funnel nao solicitado"
fi

# =============================================================================
# STEP 9: SALVAR ESTADO + RESUMO
# =============================================================================
mkdir -p "$STATE_DIR"

cat > "$STATE_DIR/dados_tailscale" << EOF
Hostname Tailscale: ${hostname_tailscale}
IP Tailscale: ${ip_tailscale}
Funnel: ${funnel_ativo}
Porta Funnel: ${porta_funnel:-N/A}
EOF
chmod 600 "$STATE_DIR/dados_tailscale"

step_ok "Credenciais salvas em ~/dados_vps/dados_tailscale"

# =============================================================================
# RESUMO FINAL
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  Tailscale VPN Mesh${UI_NC}"
echo ""
echo "  Hostname:  ${hostname_tailscale}"
echo "  IP:        ${ip_tailscale}"
echo "  Funnel:    ${funnel_ativo}"
if [[ "$funnel_ativo" == "Ativo" ]]; then
  echo "  Porta:     ${porta_funnel}"
fi
echo ""
echo "  Dados:     ~/dados_vps/dados_tailscale"
echo "  Log:       ${LOG_FILE}"
echo ""
echo "  Para conectar o desktop:"
echo "    tailscale ping ${hostname_tailscale}"
echo ""

log_finish
