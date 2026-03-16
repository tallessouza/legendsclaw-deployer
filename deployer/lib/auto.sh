#!/usr/bin/env bash
# =============================================================================
# Legendsclaw Deployer — Auto Mode Functions
# input(), auto_load_config(), auto_confirm()
# Permite execucao automatizada das ferramentas via arquivo de config.
# NOTE: This file is sourced (not executed standalone).
#       It inherits set -euo pipefail from the calling script.
# COMPAT: Bash 3.2+ (macOS) — no namerefs, no associative arrays
# =============================================================================

# --- Auto Mode Globals ---
# AUTO_MODE: "true" para modo automatizado, "false" (default) para interativo
AUTO_MODE="${AUTO_MODE:-false}"

# AUTO_CONFIG: caminho para o arquivo de configuracao
AUTO_CONFIG="${AUTO_CONFIG:-}"

# Config file path (usado por auto_get_value para lookup)
_AUTO_CONFIG_FILE=""

# Parseia arquivo de configuracao — apenas salva path para lookup posterior
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

  _AUTO_CONFIG_FILE="$AUTO_CONFIG"
  return 0
}

# Busca valor de uma chave no config file
# Uso: auto_get_value "config.key"
# Retorna: valor via stdout (vazio se nao encontrado)
auto_get_value() {
  local _key="$1"
  if [[ -z "$_AUTO_CONFIG_FILE" || ! -f "$_AUTO_CONFIG_FILE" ]]; then
    echo ""
    return
  fi
  local _line _k _v
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    [[ -z "$_line" ]] && continue
    [[ "$_line" =~ ^[[:space:]]*# ]] && continue
    _k="${_line%%:*}"
    _v="${_line#*: }"
    _k="$(echo "$_k" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ "$_k" == "$_line" ]] && continue
    _v="$(echo "$_v" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ "$_k" == "$_key" ]]; then
      echo "$_v"
      return
    fi
  done < "$_AUTO_CONFIG_FILE"
  echo ""
}

# Funcao input() — substitui read -rp com suporte a AUTO_MODE
# Usa eval para atribuir na variavel do caller (compativel Bash 3.2).
#
# Uso: input "config.key" "Prompt: " variable [--secret] [--required] [--default=X]
#
# Parametros:
#   $1 — config key (ex: "base.dominio_portainer")
#   $2 — prompt string (ex: "Dominio do Portainer: ")
#   $3 — nome da variavel do caller (string, atribuida via eval)
#   $4+ — flags opcionais: --secret, --required, --default=VALUE
#
# Retorna: 0 se sucesso, 1 se --required e chave ausente em AUTO_MODE
input() {
  local _config_key="$1"
  local _prompt="$2"
  local _var_name="$3"
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
    # Modo automatizado — buscar no config file
    local _auto_val
    _auto_val=$(auto_get_value "$_config_key")

    if [[ -n "$_auto_val" ]]; then
      eval "$_var_name=\"\$_auto_val\""
      if [[ "$_secret" == "true" ]]; then
        echo "[auto] ${_config_key}: ********"
      else
        echo "[auto] ${_config_key}: ${_auto_val}"
      fi
    elif [[ -n "$_default_val" ]]; then
      eval "$_var_name=\"\$_default_val\""
      echo "[auto] ${_config_key}: ${_default_val} (default)"
    elif [[ "$_required" == "true" ]]; then
      echo "ERRO: Chave obrigatoria ausente no config: ${_config_key}" >&2
      return 1
    else
      eval "$_var_name=''"
    fi
  else
    # Modo interativo — read normal
    local _input_tmp=""
    if [[ "$_secret" == "true" ]]; then
      read -rsp "$_prompt" _input_tmp
      echo ""
    else
      read -rp "$_prompt" _input_tmp
    fi

    # Aplicar default se vazio
    if [[ -z "$_input_tmp" && -n "$_default_val" ]]; then
      _input_tmp="$_default_val"
    fi

    eval "$_var_name=\"\$_input_tmp\""
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
#   $2 — nome da variavel do caller (string, atribuida via eval)
auto_confirm() {
  local _confirm_prompt="$1"
  local _confirm_var="$2"

  if [[ "$AUTO_MODE" == "true" ]]; then
    eval "$_confirm_var='s'"
    echo "[auto] Confirmado automaticamente"
  else
    local _confirm_tmp=""
    read -rp "$_confirm_prompt" _confirm_tmp
    eval "$_confirm_var=\"\$_confirm_tmp\""
  fi
}
