#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Setup Local
# Story 11.1: Prepara maquina local com git, Node.js, Claude Code CLI, Tailscale
# Suporta: Linux nativo, macOS, Windows (via WSL)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/env-detect.sh"
source "${LIB_DIR}/hints.sh"

readonly STATE_DIR="$HOME/dados_vps"
readonly STATE_FILE="${STATE_DIR}/dados_local_setup"
readonly NODE_MIN_VERSION=22
readonly TOTAL_STEPS=6

# =============================================================================
# Helpers de instalacao por SO
# =============================================================================

# Verifica se um comando existe
# Uso: cmd_exists "git"
cmd_exists() {
  command -v "$1" &>/dev/null
}

# Obtem versao de um comando (primeiro numero X.Y.Z encontrado)
# Uso: get_version "git --version"
get_version() {
  eval "$1" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo ""
}

# Obtem versao major do Node.js
# Retorna: numero inteiro (ex: 22)
get_node_major() {
  local ver
  ver=$(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
  echo "$ver"
}

# =============================================================================
# Funcoes de instalacao
# =============================================================================

instalar_git() {
  local so="$1"
  if cmd_exists git; then
    local ver
    ver=$(get_version "git --version")
    step_ok "Git ja instalado (v${ver})" >&2
    echo "$ver"
    return 0
  fi

  case "$so" in
    linux|wsl)
      if sudo apt-get update -qq && sudo apt-get install -y -qq git; then
        local ver
        ver=$(get_version "git --version")
        step_ok "Git instalado (v${ver})" >&2
        echo "$ver"
        return 0
      else
        step_fail "Falha ao instalar git via apt" >&2
        return 1
      fi
      ;;
    macos)
      if cmd_exists brew; then
        if brew install git 2>/dev/null; then
          local ver
          ver=$(get_version "git --version")
          step_ok "Git instalado via Homebrew (v${ver})" >&2
          echo "$ver"
          return 0
        fi
      fi
      # Xcode CLT pode ter git
      if cmd_exists git; then
        local ver
        ver=$(get_version "git --version")
        step_ok "Git disponivel via Xcode CLT (v${ver})" >&2
        echo "$ver"
        return 0
      fi
      step_fail "Git nao encontrado. Instale Xcode CLT: xcode-select --install" >&2
      return 1
      ;;
  esac
}

instalar_nodejs() {
  local so="$1"
  local node_major
  node_major=$(get_node_major)

  if [[ "$node_major" -ge "$NODE_MIN_VERSION" ]]; then
    local ver
    ver=$(get_version "node --version")
    step_ok "Node.js ja instalado (v${ver})" >&2
    echo "$ver"
    return 0
  fi

  case "$so" in
    linux|wsl)
      # Tentar NodeSource
      if curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null \
         && sudo apt-get install -y -qq nodejs 2>/dev/null; then
        local ver
        ver=$(get_version "node --version")
        step_ok "Node.js instalado via NodeSource (v${ver})" >&2
        echo "$ver"
        return 0
      fi
      # Fallback: nvm
      if cmd_exists nvm || [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh"
        if nvm install 22 && nvm use 22; then
          local ver
          ver=$(get_version "node --version")
          step_ok "Node.js instalado via nvm (v${ver})" >&2
          echo "$ver"
          return 0
        fi
      fi
      step_fail "Falha ao instalar Node.js >= ${NODE_MIN_VERSION}" >&2
      return 1
      ;;
    macos)
      if cmd_exists brew; then
        if brew install node@22 2>/dev/null; then
          # Adicionar ao PATH se necessario
          if [[ -d "$(brew --prefix)/opt/node@22/bin" ]]; then
            export PATH="$(brew --prefix)/opt/node@22/bin:$PATH"
          fi
          local ver
          ver=$(get_version "node --version")
          step_ok "Node.js instalado via Homebrew (v${ver})" >&2
          echo "$ver"
          return 0
        fi
      fi
      step_fail "Falha ao instalar Node.js. Instale Homebrew primeiro: https://brew.sh" >&2
      return 1
      ;;
  esac
}

instalar_claude_code() {
  if cmd_exists claude; then
    local ver
    ver=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    step_ok "Claude Code CLI ja instalado (${ver})" >&2
    echo "$ver"
    return 0
  fi

  if ! cmd_exists npm; then
    step_fail "npm nao encontrado. Instale Node.js primeiro" >&2
    return 1
  fi

  if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
    local ver
    ver=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    step_ok "Claude Code CLI instalado (${ver})" >&2
    echo "$ver"
    return 0
  else
    step_fail "Falha ao instalar Claude Code CLI via npm" >&2
    return 1
  fi
}

instalar_tailscale() {
  local so="$1"

  if cmd_exists tailscale; then
    local ts_status
    ts_status=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    if [[ "$ts_status" == "Running" ]]; then
      step_ok "Tailscale instalado e conectado" >&2
      echo "connected"
    else
      step_ok "Tailscale instalado (status: ${ts_status})" >&2
      echo "disconnected"
    fi
    return 0
  fi

  case "$so" in
    linux|wsl)
      # Forcar reinstall se binario ausente (ex: removido manualmente)
      if ! command -v tailscale &>/dev/null && [[ ! -x /usr/bin/tailscale ]]; then
        sudo apt-get install --reinstall tailscale -y 2>/dev/null || true
      fi
      if ! command -v tailscale &>/dev/null && [[ ! -x /usr/bin/tailscale ]]; then
        curl -fsSL https://tailscale.com/install.sh | sh 2>/dev/null || true
      fi
      hash -r 2>/dev/null || true
      export PATH="/usr/bin:/usr/sbin:/usr/local/bin:$PATH"
      if command -v tailscale &>/dev/null || [[ -x /usr/bin/tailscale ]]; then
        step_ok "Tailscale instalado" >&2
        echo "not_connected"
        return 0
      else
        step_fail "Falha ao instalar Tailscale" >&2
        echo "not_installed"
        return 1
      fi
      ;;
    macos)
      if cmd_exists brew; then
        if brew install tailscale 2>/dev/null; then
          step_ok "Tailscale instalado via Homebrew" >&2
          echo "not_connected"
          return 0
        fi
      fi
      step_fail "Falha ao instalar Tailscale. Baixe em: https://tailscale.com/download/mac" >&2
      echo "not_installed"
      return 1
      ;;
  esac
}

# =============================================================================
# Hint de proximos passos para setup local
# =============================================================================

hint_setup_local() {
  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  HINT: PROXIMOS PASSOS"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""
  echo "  1. Conectar Tailscale (se ainda nao conectou):"
  echo "     sudo tailscale up"
  echo ""
  echo "  2. Configurar bridge local → VPS:"
  echo "     deployer.sh → [1] Setup Local → setup-local-bridge"
  echo "     (Story 11.2 — requer Tailscale conectado)"
  echo ""
  echo "  3. Inicializar AIOS no projeto:"
  echo "     deployer.sh → [1] Setup Local → setup-local-aios"
  echo "     (Story 11.3 — requer Node.js)"
  echo ""
  echo "=============================================="
  echo ""
}

# =============================================================================
# Salvar estado
# =============================================================================

salvar_estado() {
  local so="$1"
  local git_ver="$2"
  local node_ver="$3"
  local claude_ver="$4"
  local ts_installed="$5"
  local ts_status="$6"

  mkdir -p "$STATE_DIR"
  cat > "$STATE_FILE" <<EOF
so_detectado: ${so}
git_version: ${git_ver}
node_version: ${node_ver}
claude_code_version: ${claude_ver}
tailscale_installed: ${ts_installed}
tailscale_status: ${ts_status}
setup_date: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
  log_init "setup-local"

  echo ""
  echo -e "${UI_BOLD:-\033[1m}=============================================="
  echo "  LEGENDSCLAW — SETUP LOCAL"
  echo -e "==============================================${UI_NC:-\033[0m}"
  echo ""

  # Detectar SO
  local so
  so=$(detectar_so)
  echo "  Sistema detectado: ${so}"
  echo ""

  # Windows sem WSL: instrucao e saida
  if [[ "$so" == "windows-no-wsl" ]]; then
    echo -e "${UI_RED:-\033[0;31m}Windows sem WSL detectado.${UI_NC:-\033[0m}"
    echo ""
    echo "  O Legendsclaw Deployer requer WSL (Windows Subsystem for Linux)."
    echo ""
    echo "  Para instalar WSL:"
    echo "    1. Abra PowerShell como Administrador"
    echo "    2. Execute: wsl --install"
    echo "    3. Reinicie o computador"
    echo "    4. Abra o terminal Ubuntu e re-execute este script"
    echo ""
    echo "  Documentacao: https://learn.microsoft.com/windows/wsl/install"
    echo ""
    log_finish
    exit 1
  fi

  step_init "$TOTAL_STEPS"

  # Variaveis de estado
  local git_ver="" node_ver="" claude_ver=""
  local ts_installed="false" ts_status="not_installed"

  # --- Step 1: Git ---
  git_ver=$(instalar_git "$so") || git_ver=""

  # --- Step 2: Node.js ---
  node_ver=$(instalar_nodejs "$so") || node_ver=""

  # --- Step 3: Claude Code CLI ---
  claude_ver=$(instalar_claude_code) || claude_ver=""

  # --- Step 4: Tailscale ---
  local ts_result
  ts_result=$(instalar_tailscale "$so") || ts_result="not_installed"
  case "$ts_result" in
    connected)     ts_installed="true"; ts_status="connected" ;;
    disconnected)  ts_installed="true"; ts_status="disconnected" ;;
    not_connected) ts_installed="true"; ts_status="disconnected" ;;
    *)             ts_installed="false"; ts_status="not_installed" ;;
  esac

  # --- Step 5: Salvar estado ---
  salvar_estado "$so" "$git_ver" "$node_ver" "$claude_ver" "$ts_installed" "$ts_status"
  step_ok "Estado salvo em ${STATE_FILE}"

  # --- Step 6: Resumo + Hints ---
  resumo_final
  hint_setup_local

  log_finish
}

main "$@"
