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
# TOTAL_STEPS definido dinamicamente em main() (7 no macOS, 6 nos demais)

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

# Uso: instalar_git "linux" _resultado _mensagem
# Seta _resultado=versao e _mensagem=texto via eval (Bash 3.2 compat)
instalar_git() {
  local so="$1"
  local _vname="$2"
  local _mname="$3"
  eval "$_vname=''"

  if cmd_exists git; then
    local _v; _v=$(get_version "git --version")
    eval "$_vname=\"\$_v\""
    eval "$_mname=\"Git ja instalado (v\${_v})\""
    return 0
  fi

  case "$so" in
    linux|wsl)
      if sudo apt-get update -qq && sudo apt-get install -y -qq git; then
        local _v; _v=$(get_version "git --version")
        eval "$_vname=\"\$_v\""
        eval "$_mname=\"Git instalado (v\${_v})\""
        return 0
      else
        eval "$_mname='Falha ao instalar git via apt'"
        return 1
      fi
      ;;
    macos)
      if cmd_exists git; then
        local _v; _v=$(get_version "git --version")
        eval "$_vname=\"\$_v\""
        eval "$_mname=\"Git disponivel via Xcode CLT (v\${_v})\""
        return 0
      fi
      # Instalar Xcode CLT (traz git, make, clang)
      echo "  Instalando Xcode Command Line Tools..."
      xcode-select --install 2>/dev/null || true
      # Aguardar instalacao (xcode-select --install abre dialog do sistema)
      echo "  Aguardando instalacao do Xcode CLT (confirme o dialog do sistema)..."
      until cmd_exists git; do
        sleep 5
      done
      local _v; _v=$(get_version "git --version")
      eval "$_vname=\"\$_v\""
      eval "$_mname=\"Git instalado via Xcode CLT (v\${_v})\""
      return 0
      ;;
  esac
}

# Uso: instalar_nodejs "linux" _resultado _mensagem
instalar_nodejs() {
  local so="$1"
  local _vname="$2"
  local _mname="$3"
  eval "$_vname=''"
  local node_major
  node_major=$(get_node_major)

  if [[ "$node_major" -ge "$NODE_MIN_VERSION" ]]; then
    local _v; _v=$(get_version "node --version")
    eval "$_vname=\"\$_v\""
    eval "$_mname=\"Node.js ja instalado (v\${_v})\""
    return 0
  fi

  case "$so" in
    linux|wsl)
      if curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null \
         && sudo apt-get install -y -qq nodejs 2>/dev/null; then
        local _v; _v=$(get_version "node --version")
        eval "$_vname=\"\$_v\""
        eval "$_mname=\"Node.js instalado via NodeSource (v\${_v})\""
        return 0
      fi
      if cmd_exists nvm || [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh"
        if nvm install 22 && nvm use 22; then
          local _v; _v=$(get_version "node --version")
          eval "$_vname=\"\$_v\""
          eval "$_mname=\"Node.js instalado via nvm (v\${_v})\""
          return 0
        fi
      fi
      eval "$_mname=\"Falha ao instalar Node.js >= ${NODE_MIN_VERSION}\""
      return 1
      ;;
    macos)
      # Prioridade 1: fnm (binario pre-compilado, rapido)
      if ! cmd_exists fnm; then
        echo "  Instalando fnm (Fast Node Manager)..."
        if curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell 2>/dev/null; then
          export PATH="$HOME/.local/share/fnm:$HOME/.fnm:$PATH"
          # fnm pode instalar em locais diferentes
          if [[ -d "$HOME/.local/share/fnm" ]]; then
            eval "$("$HOME/.local/share/fnm/fnm" env --shell bash 2>/dev/null)" 2>/dev/null || true
          fi
        fi
      fi
      if cmd_exists fnm; then
        if fnm install 22 && fnm use 22 && fnm default 22; then
          eval "$(fnm env --shell bash 2>/dev/null)" 2>/dev/null || true
          local _v; _v=$(get_version "node --version")
          eval "$_vname=\"\$_v\""
          eval "$_mname=\"Node.js instalado via fnm (v\${_v})\""
          return 0
        fi
      fi
      # Prioridade 2: nvm
      if cmd_exists nvm || [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh"
        if nvm install 22 && nvm use 22; then
          local _v; _v=$(get_version "node --version")
          eval "$_vname=\"\$_v\""
          eval "$_mname=\"Node.js instalado via nvm (v\${_v})\""
          return 0
        fi
      fi
      # Prioridade 3: brew (lento, compila OpenSSL)
      if cmd_exists brew; then
        echo "  Instalando Node.js via Homebrew (pode demorar)..."
        if brew install node@22 2>/dev/null; then
          if [[ -d "$(brew --prefix)/opt/node@22/bin" ]]; then
            export PATH="$(brew --prefix)/opt/node@22/bin:$PATH"
          fi
          local _v; _v=$(get_version "node --version")
          eval "$_vname=\"\$_v\""
          eval "$_mname=\"Node.js instalado via Homebrew (v\${_v})\""
          return 0
        fi
      fi
      eval "$_mname='Falha ao instalar Node.js >= ${NODE_MIN_VERSION}'"
      return 1
      ;;
  esac
}

# Uso: instalar_claude_code _resultado _mensagem
instalar_claude_code() {
  local _vname="$1"
  local _mname="$2"
  eval "$_vname=''"

  if cmd_exists claude; then
    local _v; _v=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    eval "$_vname=\"\$_v\""
    eval "$_mname=\"Claude Code CLI ja instalado (\${_v})\""
    return 0
  fi

  if ! cmd_exists npm; then
    eval "$_mname='npm nao encontrado. Instale Node.js primeiro'"
    return 1
  fi

  if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
    local _v; _v=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    eval "$_vname=\"\$_v\""
    eval "$_mname=\"Claude Code CLI instalado (\${_v})\""
    return 0
  else
    eval "$_mname='Falha ao instalar Claude Code CLI via npm'"
    return 1
  fi
}

# Uso: instalar_tailscale "linux" _resultado _mensagem
# _resultado: connected | disconnected | not_connected | not_installed
instalar_tailscale() {
  local so="$1"
  local _sname="$2"
  local _mname="$3"
  eval "$_sname='not_installed'"

  if cmd_exists tailscale; then
    local ts_state
    ts_state=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    if [[ "$ts_state" == "Running" ]]; then
      eval "$_sname='connected'"
      eval "$_mname='Tailscale instalado e conectado'"
    else
      eval "$_sname='disconnected'"
      eval "$_mname=\"Tailscale instalado (status: \${ts_state})\""
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
        eval "$_sname='not_connected'"
        eval "$_mname='Tailscale instalado'"
        return 0
      else
        eval "$_sname='not_installed'"
        eval "$_mname='Falha ao instalar Tailscale'"
        return 1
      fi
      ;;
    macos)
      # Checar se Tailscale.app esta instalado (Mac App Store ou download direto)
      if [[ -d "/Applications/Tailscale.app" ]]; then
        eval "$_sname='not_connected'"
        eval "$_mname='Tailscale.app encontrado (abra o app para conectar)'"
        return 0
      fi
      # Nao usar brew install tailscale (compila dependencias, demora muito)
      # Instruir download direto do .app
      eval "$_sname='not_installed'"
      eval "$_mname='Tailscale nao encontrado. Baixe o app: https://tailscale.com/download/mac'"
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

  step_init 6

  # Variaveis de estado
  local git_ver="" node_ver="" claude_ver="" _msg=""
  local ts_installed="false" ts_status="not_installed"

  # --- Step 1: Git ---
  if instalar_git "$so" git_ver _msg; then
    step_ok "$_msg"
  else
    step_fail "$_msg"
  fi

  # --- Step 2: Node.js ---
  if instalar_nodejs "$so" node_ver _msg; then
    step_ok "$_msg"
  else
    step_fail "$_msg"
  fi

  # --- Step 3: Claude Code CLI ---
  if instalar_claude_code claude_ver _msg; then
    step_ok "$_msg"
  else
    step_fail "$_msg"
  fi

  # --- Step 4: Tailscale ---
  local ts_result=""
  if instalar_tailscale "$so" ts_result _msg; then
    step_ok "$_msg"
  else
    step_fail "$_msg"
  fi
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
