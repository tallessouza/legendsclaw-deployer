#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Setup Local AIOS
# Story 11.3: AIOS Init + Registro de Agente
# Inicializa projeto AIOS e registra agente como ativavel
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
# Repo root — deployer/ esta um nivel abaixo do repo
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/auto.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

readonly NODE_MIN_VERSION=22
readonly TOTAL_STEPS=8

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "setup-local-aios"
[[ "${AUTO_MODE:-false}" == "true" ]] && auto_load_config
setup_trap
step_init "$TOTAL_STEPS"

# =============================================================================
# STEP 2: VERIFICAR DEPENDENCIAS (AC: 2)
# =============================================================================

# Node.js >= 22
if ! command -v node &>/dev/null; then
  step_fail "Node.js nao encontrado (requer v${NODE_MIN_VERSION}+)"
  echo "  Execute primeiro: ferramentas/setup-local.sh"
  exit 1
fi

node_major=$(node --version | sed 's/v//' | cut -d. -f1)
if [[ "$node_major" -lt "$NODE_MIN_VERSION" ]]; then
  step_fail "Node.js versao ${node_major} (requer v${NODE_MIN_VERSION}+)"
  echo "  Execute primeiro: ferramentas/setup-local.sh"
  exit 1
fi

# npm
if ! command -v npm &>/dev/null; then
  step_fail "npm nao encontrado"
  echo "  Instale npm (vem com Node.js): ferramentas/setup-local.sh"
  exit 1
fi

step_ok "Dependencias verificadas — Node $(node --version), npm $(npm --version 2>/dev/null)"

# =============================================================================
# STEP 3: COLETAR DADOS DO PROJETO (AC: 3)
# =============================================================================

nome_projeto=""
dir_destino=""

input "aios.nome_projeto" "Nome do projeto [$(basename "$PWD")]: " nome_projeto --default="$(basename "$PWD")"
input "aios.dir_destino" "Diretorio destino [$PWD]: " dir_destino --default="$PWD"

# Validar/criar diretorio
if [[ ! -d "$dir_destino" ]]; then
  auto_confirm "Diretorio '${dir_destino}' nao existe. Criar? (s/n): " criar_dir
  if [[ "$criar_dir" =~ ^[Ss]$ ]]; then
    mkdir -p "$dir_destino"
  else
    echo "Cancelado pelo usuario."
    exit 0
  fi
fi

conferindo_as_info \
  "Projeto=${nome_projeto}" \
  "Diretorio=${dir_destino}"

auto_confirm "As informacoes estao corretas? (s/n): " confirma
if ! [[ "$confirma" =~ ^[Ss]$ ]]; then
  echo "Cancelado pelo usuario."
  exit 0
fi

step_ok "Dados do projeto coletados"

# =============================================================================
# STEP 4: EXECUTAR npx aios-core init (AC: 4, 5)
# =============================================================================

aios_dir="${dir_destino}/.aios-core"
# aios-core init pode criar subdiretorio com nome do projeto
aios_dir_nested="${dir_destino}/${nome_projeto}/.aios-core"

if [[ -d "$aios_dir" ]]; then
  step_skip "AIOS ja inicializado em ${dir_destino}"
elif [[ -d "$aios_dir_nested" ]]; then
  # Init ja rodou antes e criou subdiretorio
  dir_destino="${dir_destino}/${nome_projeto}"
  aios_dir="$aios_dir_nested"
  step_skip "AIOS ja inicializado em ${dir_destino}"
else
  echo ""
  echo "  Executando npx aios-core init ${nome_projeto}..."
  echo "  (isto pode demorar na primeira execucao)"
  echo ""

  # Rodar direto no terminal (sem captura) — aios-core init e interativo
  (cd "$dir_destino" && npx aios-core init "$nome_projeto" </dev/tty >/dev/tty 2>&1)
  init_exit=$?

  if [[ "$init_exit" -ne 0 ]]; then
    step_fail "npx aios-core init falhou (exit code: ${init_exit})"
    echo ""
    echo "  Tente manualmente:"
    echo "    cd ${dir_destino}"
    echo "    npx aios-core init ${nome_projeto}"
    exit 1
  fi

  # aios-core init cria subdiretorio {nome_projeto}/.aios-core/
  # Verificar ambos os paths possiveis
  if [[ -d "$aios_dir_nested" ]]; then
    dir_destino="${dir_destino}/${nome_projeto}"
    aios_dir="$aios_dir_nested"
  elif [[ ! -d "$aios_dir" ]]; then
    step_fail ".aios-core/ nao encontrado apos init"
    echo "  Verificado: ${aios_dir}"
    echo "  Verificado: ${aios_dir_nested}"
    echo "  Verifique manualmente: ls -la ${dir_destino}/"
    exit 1
  fi

  step_ok "AIOS inicializado em ${dir_destino}"
fi

# =============================================================================
# STEP 5: LER DADOS DO WHITELABEL (AC: 6)
# =============================================================================
dados

nome_agente=""
display_name=""
icone=""
persona=""
idioma=""

# Tentar carregar de dados_whitelabel primeiro, depois dados_bridge como fallback
if [[ -f "$STATE_DIR/dados_whitelabel" ]]; then
  nome_agente=$(grep "^Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
  display_name=$(grep "^Display Name:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
  icone=$(grep "^Icone:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
  persona=$(grep "^Persona:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
  idioma=$(grep "^Idioma:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
  step_ok "Dados do agente carregados de dados_whitelabel"
else
  # Fallback: reusar nome do agente do bridge (evita pedir 2x)
  if [[ -f "$STATE_DIR/dados_bridge" ]]; then
    nome_agente=$(grep "^Agente:" "$STATE_DIR/dados_bridge" 2>/dev/null | awk -F': ' '{print $2}' || true)
    if [[ -n "$nome_agente" ]]; then
      echo "  Nome do agente recuperado do bridge: ${nome_agente}"
    fi
  fi

  if [[ -z "$nome_agente" ]]; then
    echo ""
    echo "  dados_whitelabel nao encontrado — coleta interativa"
    echo ""
    input "aios.nome_agente" "Nome tecnico do agente (kebab-case, ex: jarvis): " nome_agente --default="meu-agente"
    while [[ ! "$nome_agente" =~ ^[a-z][a-z0-9-]*$ ]]; do
      echo -e "  ${UI_RED:-\033[0;31m}Nome invalido: use kebab-case (a-z, 0-9, hifens, comecando com letra)${UI_NC:-\033[0m}"
      input "aios.nome_agente" "Nome tecnico do agente: " nome_agente --default="meu-agente"
    done
  fi

  # Dados complementares — sempre perguntar se nao vieram do whitelabel
  input "aios.display_name" "Display name [${nome_agente^}]: " display_name --default="${nome_agente^}"
  input "aios.icone" "Icone/emoji [🤖]: " icone --default="🤖"
  input "aios.persona" "Persona/descricao curta [Assistente IA especializado]: " persona --default="Assistente IA especializado"
  input "aios.idioma" "Idioma [pt-br]: " idioma --default="pt-br"

  step_ok "Dados do agente coletados"
fi

# =============================================================================
# STEP 6: LER SKILLS ATIVAS (AC: 8, 9)
# =============================================================================

skills_list=""
skills_count=0
declare -a skills_array=()

if [[ -f "$STATE_DIR/dados_skills" ]]; then
  skills_list=$(grep "^Skills Ativas:" "$STATE_DIR/dados_skills" 2>/dev/null | awk -F': ' '{print $2}' || true)
  if [[ -n "$skills_list" ]]; then
    IFS=', ' read -ra skills_array <<< "$skills_list"
    skills_count=${#skills_array[@]}
    step_ok "${skills_count} skills mapeadas como commands"
  else
    step_skip "dados_skills sem skills ativas — commands basicos"
  fi
else
  step_skip "Sem dados_skills — commands basicos (help, status, chat)"
fi

# =============================================================================
# STEP 7: GERAR ARQUIVO DE DEFINICAO DO AGENTE (AC: 7, 8, 9)
# =============================================================================

agents_dir="${dir_destino}/.aios-core/development/agents"
agent_file="${agents_dir}/${nome_agente}.md"

mkdir -p "$agents_dir"

# Backup se ja existe
if [[ -f "$agent_file" ]]; then
  cp -p "$agent_file" "${agent_file}.bak"
  echo "  Backup criado: ${agent_file}.bak"
fi

# Montar commands YAML
commands_yaml="  - name: help
    visibility: [full, quick, key]
    description: 'Show all available commands with descriptions'
  - name: status
    visibility: [full, quick, key]
    description: 'Show current agent status and health'
  - name: chat
    visibility: [full, quick, key]
    description: 'Start a conversation with the agent'"

# Adicionar commands das skills
for skill in "${skills_array[@]}"; do
  # Trim whitespace
  skill=$(echo "$skill" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$skill" ]] && continue
  commands_yaml="${commands_yaml}
  - name: ${skill}
    visibility: [full, quick]
    description: 'Execute ${skill} skill'"
done

# Montar dependencies tools
deps_tools="    - git"
for skill in "${skills_array[@]}"; do
  skill=$(echo "$skill" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$skill" ]] && continue
  deps_tools="${deps_tools}
    - ${skill}"
done

# Montar lista de quick commands para markdown
quick_commands="- \`*help\` - Show all available commands
- \`*status\` - Show agent status
- \`*chat\` - Start conversation"
for skill in "${skills_array[@]}"; do
  skill=$(echo "$skill" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$skill" ]] && continue
  quick_commands="${quick_commands}
- \`*${skill}\` - Execute ${skill}"
done

# Gerar arquivo de definicao
cat > "$agent_file" << AGENTEOF
# ${nome_agente}

ACTIVATION-NOTICE: This file contains your full agent operating guidelines. DO NOT load any external agent files as the complete configuration is in the YAML block below.

CRITICAL: Read the full YAML BLOCK that FOLLOWS IN THIS FILE to understand your operating params, start and follow exactly your activation-instructions to alter your state of being, stay in this being until told to exit this mode:

## COMPLETE AGENT DEFINITION FOLLOWS - NO EXTERNAL FILES NEEDED

\`\`\`yaml
activation-instructions:
  - STEP 1: Read THIS ENTIRE FILE - it contains your complete persona definition
  - STEP 2: Adopt the persona defined in the 'agent' and 'persona' sections below
  - STEP 3: Display greeting and HALT to await user input
  - STAY IN CHARACTER!
agent:
  name: ${display_name}
  id: ${nome_agente}
  title: ${display_name} Agent
  icon: ${icone}
  whenToUse: |
    ${persona}
  customization: null

persona_profile:
  archetype: Assistant
  communication:
    tone: professional
    emoji_frequency: medium
    vocabulary:
      - ajudar
      - resolver
      - executar
      - analisar
      - otimizar
    greeting_levels:
      minimal: '${icone} ${nome_agente} Agent ready'
      named: '${icone} ${display_name} ready!'
      archetypal: '${icone} ${display_name} the Assistant ready!'
    signature_closing: '— ${display_name} ${icone}'

persona:
  role: ${persona}
  style: Professional, helpful, precise
  identity: AI assistant specialized in helping users
  focus: Executing user requests with precision and clarity

commands:
${commands_yaml}

dependencies:
  tools:
${deps_tools}

autoClaude:
  version: '3.0'
\`\`\`

---

## Quick Commands

${quick_commands}

Type \`*help\` to see all commands.

---

*Generated by Legendsclaw Deployer (Story 11.3) — $(date '+%Y-%m-%d %H:%M:%S')*
AGENTEOF

step_ok "Agente '${nome_agente}' registrado em ${agent_file}"

# =============================================================================
# STEP 8: SALVAR ESTADO (AC: 10) + HINTS (AC: 11) + RESUMO
# =============================================================================

# Montar lista de commands para state file
all_commands="help,status,chat"
for skill in "${skills_array[@]}"; do
  skill=$(echo "$skill" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$skill" ]] && continue
  all_commands="${all_commands},${skill}"
done

mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/dados_aios_init" << EOF
Projeto: ${nome_projeto}
Diretorio: ${dir_destino}
AIOS Inicializado: true
Agente Registrado: ${nome_agente}
Display Name: ${display_name}
Icone: ${icone}
Idioma: ${idioma}
Commands: ${all_commands}
Skills Mapeadas: ${skills_count}
Agent File: .aios-core/development/agents/${nome_agente}.md
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_aios_init"

step_ok "Estado salvo em ~/dados_vps/dados_aios_init"

# Hints
hint_aios_init_usage "$nome_agente" "$display_name" "$all_commands"
hint_aios_init_next_steps

# Resumo
resumo_final

echo -e "${UI_BOLD:-\033[1m}  Setup Local AIOS — Configuracao Completa${UI_NC:-\033[0m}"
echo ""
echo "  Projeto:       ${nome_projeto}"
echo "  Diretorio:     ${dir_destino}"
echo "  Agente:        ${nome_agente} (${display_name} ${icone})"
echo "  Commands:      ${all_commands}"
echo "  Skills:        ${skills_count}"
echo ""
echo "  Agent File:    ${agent_file}"
echo "  Estado:        ~/dados_vps/dados_aios_init"
echo "  Log:           ${LOG_FILE}"
echo ""

log_finish
