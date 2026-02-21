#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Auto Mode Functions
# input(), auto_load_config(), auto_confirm()
# Permite execucao automatizada das ferramentas via arquivo de config.
# NOTE: This file is sourced (not executed standalone).
#       It inherits set -euo pipefail from the calling script.
# =============================================================================

# --- Auto Mode Globals ---
# AUTO_MODE: "true" para modo automatizado, "false" (default) para interativo
AUTO_MODE="${AUTO_MODE:-false}"

# AUTO_CONFIG: caminho para o arquivo de configuracao
AUTO_CONFIG="${AUTO_CONFIG:-}"

# Associative array com valores do config (preenchido por auto_load_config)
declare -gA _AUTO_VALUES

# Parseia arquivo de configuracao para o associative array _AUTO_VALUES
# Formato: "key: value" (ignora linhas vazias e comentarios #)
# Uso: auto_load_config
# Retorna: 0 se sucesso, 1 se arquivo nao encontrado
auto_load_config() {
  if [[ -z "$AUTO_CONFIG" ]]; then
    echo "ERRO: AUTO_CONFIG nao definido" >&2
    return 1
  fi

  if [[ ! -f "$AUTO_CONFIG" ]]; then
    echo "ERRO: Arquivo de config nao encontrado: $AUTO_CONFIG" >&2
    return 1
  fi

  # Limpa valores anteriores
  _AUTO_VALUES=()

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Ignora linhas vazias e comentarios
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Split em ": " (primeiro ": " encontrado)
    key="${line%%:*}"
    value="${line#*: }"

    # Trim whitespace do key
    key="$(echo "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    # Se value == line inteira (nao tinha ": "), pula
    if [[ "$key" == "$line" ]]; then
      continue
    fi

    # Trim whitespace do value
    value="$(echo "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    _AUTO_VALUES["$key"]="$value"
  done < "$AUTO_CONFIG"

  return 0
}

# Funcao input() — substitui read -rp com suporte a AUTO_MODE
# Usa Bash 4.3+ nameref para atribuir diretamente na variavel do caller.
#
# Uso: input "config.key" "Prompt: " variable [--secret] [--required] [--default=X]
#
# Parametros:
#   $1 — config key (ex: "base.dominio_portainer")
#   $2 — prompt string (ex: "Dominio do Portainer: ")
#   $3 — nome da variavel do caller (nameref)
#   $4+ — flags opcionais: --secret, --required, --default=VALUE
#
# Retorna: 0 se sucesso, 1 se --required e chave ausente em AUTO_MODE
input() {
  local _config_key="$1"
  local _prompt="$2"
  local -n _var_ref="$3"
  shift 3

  # Parse flags
  local _secret=false
  local _required=false
  local _default_val=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --secret)
        _secret=true
        ;;
      --required)
        _required=true
        ;;
      --default=*)
        _default_val="${1#--default=}"
        ;;
    esac
    shift
  done

  if [[ "$AUTO_MODE" == "true" ]]; then
    # Modo automatizado — buscar no associative array
    local _auto_val="${_AUTO_VALUES[$_config_key]:-}"

    if [[ -n "$_auto_val" ]]; then
      _var_ref="$_auto_val"
      if [[ "$_secret" == "true" ]]; then
        echo "[auto] ${_config_key}: ********"
      else
        echo "[auto] ${_config_key}: ${_auto_val}"
      fi
    elif [[ -n "$_default_val" ]]; then
      _var_ref="$_default_val"
      echo "[auto] ${_config_key}: ${_default_val} (default)"
    elif [[ "$_required" == "true" ]]; then
      echo "ERRO: Chave obrigatoria ausente no config: ${_config_key}" >&2
      return 1
    else
      _var_ref=""
    fi
  else
    # Modo interativo — read normal
    if [[ "$_secret" == "true" ]]; then
      read -rsp "$_prompt" _var_ref
      echo ""
    else
      read -rp "$_prompt" _var_ref
    fi

    # Aplicar default se vazio
    if [[ -z "$_var_ref" && -n "$_default_val" ]]; then
      _var_ref="$_default_val"
    fi
  fi

  return 0
}

# Funcao auto_confirm() — substitui read -rp para confirmacoes (s/n)
# Em AUTO_MODE retorna "s" automaticamente.
#
# Uso: auto_confirm "Prompt (s/n): " variable
#
# Parametros:
#   $1 — prompt string
#   $2 — nome da variavel do caller (nameref)
auto_confirm() {
  local _confirm_prompt="$1"
  local -n _confirm_ref="$2"

  if [[ "$AUTO_MODE" == "true" ]]; then
    _confirm_ref="s"
    echo "[auto] Confirmado automaticamente"
  else
    read -rp "$_confirm_prompt" _confirm_ref
  fi
}
