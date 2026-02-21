#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Auto Runner
# Executa ferramentas sequencialmente em AUTO_MODE com logging e relatorio.
#
# Uso: bash deployer-auto.sh --config <path> [--from NN] [--to NN] [--only NN,NN] [--dry-run]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly AUTO_RUNNER_VERSION="1.0.0"

# --- Cores ANSI ---
readonly AR_RED='\033[0;31m'
readonly AR_GREEN='\033[0;32m'
readonly AR_YELLOW='\033[1;33m'
readonly AR_CYAN='\033[0;36m'
readonly AR_BOLD='\033[1m'
readonly AR_NC='\033[0m'

# --- Mapa de ferramentas (num:script:nome) ---
readonly FERRAMENTAS=(
  "01:01-base.sh:Traefik + Portainer (base)"
  "02:02-tailscale.sh:Tailscale VPN"
  "03:03-openclaw.sh:OpenClaw Gateway"
  "04:04-validacao-gw.sh:Validacao Gateway"
  "05:05-whitelabel.sh:Whitelabel — Identidade"
  "06:06-workspace.sh:Workspace Files"
  "07:07-llm-router.sh:LLM Router"
  "08:08-skills.sh:Skills AIOS"
  "09:09-elicitation.sh:Elicitation"
  "10:10-elicitation-schema.sh:Elicitation Schema"
  "11:11-seguranca.sh:Seguranca (3 Layers)"
  "12:12-bridge.sh:Bridge — Claude Code"
  "13:13-evolution.sh:Evolution API"
  "14:14-gateway-config.sh:Gateway Config"
  "15:15-validacao-final.sh:Validacao Final"
)

# --- Globals ---
CONFIG_FILE=""
FLAG_FROM=""
FLAG_TO=""
FLAG_ONLY=""
FLAG_DRY_RUN=false
MASTER_LOG=""
LOG_DIR="$HOME/legendsclaw-logs"

# Arrays de resultados
declare -a RESULT_NUMS=()
declare -a RESULT_NAMES=()
declare -a RESULT_STATUS=()
declare -a RESULT_TIME=()

TOTAL_START=0
COUNT_OK=0
COUNT_FAIL=0
COUNT_SKIP=0

# Exibe ajuda
# Uso: show_usage
show_usage() {
  cat <<'USAGE'
Legendsclaw Deployer — Auto Runner

USO:
  bash deployer-auto.sh --config <path> [opcoes]

OPCOES:
  --config <path>   Caminho para o arquivo de configuracao (obrigatorio)
  --from NN         Iniciar a partir da ferramenta NN (ex: --from 07)
  --to NN           Parar apos a ferramenta NN (ex: --to 10)
  --only NN,NN,...  Executar apenas ferramentas especificas (ex: --only 01,04,15)
  --dry-run         Validar config e listar ferramentas sem executar
  --help            Exibir esta ajuda

EXEMPLOS:
  # Run completo
  bash deployer-auto.sh --config auto-config.env

  # Retomar apos falha
  bash deployer-auto.sh --config auto-config.env --from 07

  # Apenas infra base
  bash deployer-auto.sh --config auto-config.env --from 01 --to 04

  # Ferramentas especificas
  bash deployer-auto.sh --config auto-config.env --only 01,02,03,04

  # Validar config
  bash deployer-auto.sh --config auto-config.env --dry-run
USAGE
}

# Parseia argumentos da linha de comando
# Uso: parse_args "$@"
# Retorna: 0 sucesso, 1 erro
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        if [[ $# -lt 2 ]]; then
          echo "ERRO: --config requer um argumento" >&2
          return 1
        fi
        CONFIG_FILE="$2"
        shift 2
        ;;
      --from)
        if [[ $# -lt 2 ]]; then
          echo "ERRO: --from requer um argumento" >&2
          return 1
        fi
        FLAG_FROM="$2"
        shift 2
        ;;
      --to)
        if [[ $# -lt 2 ]]; then
          echo "ERRO: --to requer um argumento" >&2
          return 1
        fi
        FLAG_TO="$2"
        shift 2
        ;;
      --only)
        if [[ $# -lt 2 ]]; then
          echo "ERRO: --only requer um argumento" >&2
          return 1
        fi
        FLAG_ONLY="$2"
        shift 2
        ;;
      --dry-run)
        FLAG_DRY_RUN=true
        shift
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        echo "ERRO: Flag desconhecida: $1" >&2
        show_usage >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$CONFIG_FILE" ]]; then
    echo "ERRO: --config e obrigatorio" >&2
    show_usage >&2
    return 1
  fi

  return 0
}

# Valida que um numero de ferramenta e valido (01-15)
# Uso: validate_tool_num "07"
# Retorna: 0 valido, 1 invalido
validate_tool_num() {
  local num="$1"
  local found=false
  for entry in "${FERRAMENTAS[@]}"; do
    local entry_num="${entry%%:*}"
    if [[ "$entry_num" == "$num" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == "false" ]]; then
    echo "ERRO: Numero de ferramenta invalido: $num (validos: 01-15)" >&2
    return 1
  fi
  return 0
}

# Valida flags --from, --to, --only
# Uso: validate_flags
# Retorna: 0 sucesso, 1 erro
validate_flags() {
  if [[ -n "$FLAG_FROM" ]]; then
    validate_tool_num "$FLAG_FROM" || return 1
  fi
  if [[ -n "$FLAG_TO" ]]; then
    validate_tool_num "$FLAG_TO" || return 1
  fi
  if [[ -n "$FLAG_ONLY" ]]; then
    IFS=',' read -ra only_nums <<< "$FLAG_ONLY"
    for num in "${only_nums[@]}"; do
      num="$(echo "$num" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      validate_tool_num "$num" || return 1
    done
  fi
  if [[ -n "$FLAG_ONLY" && ( -n "$FLAG_FROM" || -n "$FLAG_TO" ) ]]; then
    echo "ERRO: --only nao pode ser combinado com --from/--to" >&2
    return 1
  fi
  return 0
}

# Monta a lista de ferramentas a executar
# Uso: build_execution_list
# Retorna: lista em EXEC_LIST (array global)
declare -a EXEC_LIST=()
build_execution_list() {
  EXEC_LIST=()

  if [[ -n "$FLAG_ONLY" ]]; then
    # --only: filtrar ferramentas especificas (na ordem natural)
    IFS=',' read -ra only_nums <<< "$FLAG_ONLY"
    for entry in "${FERRAMENTAS[@]}"; do
      local entry_num="${entry%%:*}"
      for num in "${only_nums[@]}"; do
        num="$(echo "$num" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        if [[ "$entry_num" == "$num" ]]; then
          EXEC_LIST+=("$entry")
          break
        fi
      done
    done
  else
    # --from/--to: range (default: todas)
    local in_range=false
    [[ -z "$FLAG_FROM" ]] && in_range=true

    for entry in "${FERRAMENTAS[@]}"; do
      local entry_num="${entry%%:*}"

      if [[ -n "$FLAG_FROM" && "$entry_num" == "$FLAG_FROM" ]]; then
        in_range=true
      fi

      if [[ "$in_range" == "true" ]]; then
        EXEC_LIST+=("$entry")
      fi

      if [[ -n "$FLAG_TO" && "$entry_num" == "$FLAG_TO" ]]; then
        break
      fi
    done
  fi
}

# Valida o arquivo de config
# Uso: validate_config
# Retorna: 0 sucesso, 1 erro
validate_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERRO: Arquivo de config nao encontrado: $CONFIG_FILE" >&2
    return 1
  fi

  # Converter para path absoluto
  CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"

  # Testar parsing via auto.sh
  export AUTO_MODE=true
  export AUTO_CONFIG="$CONFIG_FILE"
  source "${SCRIPT_DIR}/lib/auto.sh"
  auto_load_config || return 1

  return 0
}

# Inicializa o master log
# Uso: init_master_log
init_master_log() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  MASTER_LOG="${LOG_DIR}/auto-runner-${timestamp}.log"
  mkdir -p "$LOG_DIR"

  # Redirecionar stdout+stderr para tee (tela + master log)
  exec > >(tee -a "$MASTER_LOG") 2>&1

  echo "=============================================="
  echo "  LEGENDSCLAW DEPLOYER AUTO v${AUTO_RUNNER_VERSION}"
  echo "=============================================="
  echo "  Data:      $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  Hostname:  $(hostname)"
  echo "  Config:    ${CONFIG_FILE}"
  echo "  Chaves:    ${#_AUTO_VALUES[@]}"
  if [[ -n "$FLAG_FROM" ]]; then echo "  --from:    ${FLAG_FROM}"; fi
  if [[ -n "$FLAG_TO" ]]; then echo "  --to:      ${FLAG_TO}"; fi
  if [[ -n "$FLAG_ONLY" ]]; then echo "  --only:    ${FLAG_ONLY}"; fi
  echo "  Ferramentas: ${#EXEC_LIST[@]}"
  echo "  Master log:  ${MASTER_LOG}"
  echo "=============================================="
  echo ""
}

# Executa uma ferramenta e captura resultado
# Uso: run_single_tool "01:01-base.sh:Traefik + Portainer"
# Retorna: 0 se OK, 1 se FAIL
run_single_tool() {
  local entry="$1"
  local num="${entry%%:*}"
  local rest="${entry#*:}"
  local script="${rest%%:*}"
  local name="${rest#*:}"

  echo ""
  echo -e "${AR_CYAN}${AR_BOLD}━━━ [${num}] ${name} ━━━${AR_NC}"
  echo "[$(date '+%H:%M:%S')] Iniciando ${script}..."

  local start_seconds=$SECONDS
  local exit_code=0

  AUTO_MODE=true AUTO_CONFIG="$CONFIG_FILE" bash "${SCRIPT_DIR}/ferramentas/${script}" || exit_code=$?

  local elapsed=$(( SECONDS - start_seconds ))

  RESULT_NUMS+=("$num")
  RESULT_NAMES+=("$name")
  RESULT_TIME+=("$elapsed")

  if [[ $exit_code -eq 0 ]]; then
    RESULT_STATUS+=("OK")
    COUNT_OK=$(( COUNT_OK + 1 ))
    echo -e "[$(date '+%H:%M:%S')] [${num}] ${AR_GREEN}OK${AR_NC} (${elapsed}s)"
    return 0
  else
    RESULT_STATUS+=("FAIL")
    COUNT_FAIL=$(( COUNT_FAIL + 1 ))
    echo -e "[$(date '+%H:%M:%S')] [${num}] ${AR_RED}FAIL${AR_NC} (exit ${exit_code}, ${elapsed}s)"
    return 1
  fi
}

# Formata segundos em "Xm Ys"
# Uso: format_time 272
format_time() {
  local total="$1"
  if [[ $total -ge 60 ]]; then
    echo "$(( total / 60 ))m $(( total % 60 ))s"
  else
    echo "${total}s"
  fi
}

# Exibe relatorio final
# Uso: show_report
show_report() {
  local total_elapsed=$(( SECONDS - TOTAL_START ))

  # Calcular skips (ferramentas planejadas mas nao executadas)
  local executed=$(( COUNT_OK + COUNT_FAIL ))
  COUNT_SKIP=$(( ${#EXEC_LIST[@]} - executed ))

  echo ""
  echo -e "${AR_BOLD}=============================================="
  echo "  DEPLOYER AUTO — RELATORIO"
  echo -e "==============================================${AR_NC}"
  printf "  %-38s %-8s %s\n" "Ferramenta" "Status" "Tempo"
  printf "  %-38s %-8s %s\n" "----------" "------" "-----"

  for i in "${!RESULT_NUMS[@]}"; do
    local status="${RESULT_STATUS[$i]}"
    local color="$AR_GREEN"
    [[ "$status" == "FAIL" ]] && color="$AR_RED"
    printf "  [%s] %-34s ${color}%-8s${AR_NC} %s\n" \
      "${RESULT_NUMS[$i]}" "${RESULT_NAMES[$i]}" "$status" "$(format_time "${RESULT_TIME[$i]}")"
  done

  # Mostrar ferramentas skipadas
  if [[ $COUNT_SKIP -gt 0 ]]; then
    for entry in "${EXEC_LIST[@]}"; do
      local num="${entry%%:*}"
      local rest="${entry#*:}"
      local name="${rest#*:}"
      local was_executed=false
      for rn in "${RESULT_NUMS[@]}"; do
        [[ "$rn" == "$num" ]] && was_executed=true && break
      done
      if [[ "$was_executed" == "false" ]]; then
        printf "  [%s] %-34s ${AR_YELLOW}%-8s${AR_NC} %s\n" "$num" "$name" "SKIP" "-"
      fi
    done
  fi

  echo -e "${AR_BOLD}=============================================="
  echo -n "  Total: "
  echo -ne "${AR_GREEN}${COUNT_OK} OK${AR_NC}"
  echo -ne " | ${AR_RED}${COUNT_FAIL} FAIL${AR_NC}"
  echo -e " | ${AR_YELLOW}${COUNT_SKIP} SKIP${AR_NC}"
  echo "  Tempo total: $(format_time "$total_elapsed")"
  echo "  Master log: ${MASTER_LOG}"
  echo -e "==============================================${AR_NC}"
  echo ""
}

# Funcao principal
main() {
  parse_args "$@"
  validate_flags
  validate_config
  build_execution_list

  if [[ ${#EXEC_LIST[@]} -eq 0 ]]; then
    echo "ERRO: Nenhuma ferramenta selecionada para execucao" >&2
    exit 1
  fi

  # --- Dry-run mode ---
  if [[ "$FLAG_DRY_RUN" == "true" ]]; then
    echo ""
    echo "=============================================="
    echo "  DEPLOYER AUTO — DRY RUN"
    echo "=============================================="
    echo "  Config: ${CONFIG_FILE}"
    echo "  Chaves no config: ${#_AUTO_VALUES[@]}"
    echo ""
    echo "  Ferramentas a executar (${#EXEC_LIST[@]}):"
    for entry in "${EXEC_LIST[@]}"; do
      local num="${entry%%:*}"
      local rest="${entry#*:}"
      local name="${rest#*:}"
      echo "    [${num}] ${name}"
    done
    echo ""
    echo "  Nenhuma ferramenta sera executada (--dry-run)"
    echo "=============================================="
    exit 0
  fi

  # --- Execucao real ---
  init_master_log
  TOTAL_START=$SECONDS

  local failed_num=""
  for entry in "${EXEC_LIST[@]}"; do
    if ! run_single_tool "$entry"; then
      local num="${entry%%:*}"
      failed_num="$num"
      echo ""
      echo -e "${AR_RED}${AR_BOLD}Ferramenta [${num}] falhou.${AR_NC}"

      # Calcular proxima ferramenta para --from
      local next_num=""
      local found_current=false
      for next_entry in "${EXEC_LIST[@]}"; do
        local next_n="${next_entry%%:*}"
        if [[ "$found_current" == "true" ]]; then
          next_num="$next_n"
          break
        fi
        [[ "$next_n" == "$num" ]] && found_current=true
      done

      if [[ -n "$next_num" ]]; then
        echo -e "Para retomar: ${AR_CYAN}bash deployer-auto.sh --config ${CONFIG_FILE} --from ${next_num}${AR_NC}"
      fi
      break
    fi
  done

  show_report

  if [[ $COUNT_FAIL -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
