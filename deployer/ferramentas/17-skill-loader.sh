#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 17: Skill Loader
# Configura extraDirs no openclaw.json, limpa sessions e reinicia o gateway
# para que skills customizadas em apps/{AGENTE}/skills/ sejam carregadas.
#
# Contexto técnico:
#   O OpenClaw escaneia skills em 6 locais (workspace.ts → loadSkillEntries):
#     1. extraDirs (config)        — menor precedência
#     2. bundled (/opt/openclaw/skills/)
#     3. managed (~/.openclaw/skills/)
#     4. personal (~/.agents/skills/)
#     5. project  ({workspace}/.agents/skills/)
#     6. workspace ({workspace}/skills/) — maior precedência
#
#   Skills em {workspace}/apps/*/skills/ NÃO são escaneadas automaticamente.
#   Este script registra o path via extraDirs no openclaw.json.
#
#   O skillsSnapshot é cacheado por session — sessions existentes não veem
#   skills novas. Por isso limpamos sessions e reiniciamos o gateway.
#
#   Paths nos SKILL.md devem usar ~ (til) — nunca /home/user hardcoded.
#   A LLM expande ~ corretamente. O OpenClaw faz resolveUserPath() no scan.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Funções standalone (não depende das libs do deployer)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()        { echo -e "  ${GREEN}[OK]${NC} $1"; }
fail()      { echo -e "  ${RED}[FAIL]${NC} $1"; exit 1; }
info()      { echo -e "  ${BLUE}[INFO]${NC} $1"; }
warn()      { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
step_ok()   { ok "$1"; }
step_fail() { fail "$1"; }
step_skip() { info "$1"; }

# =============================================================================
# DETECTAR HOME E PATHS
# =============================================================================
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  REAL_HOME="$HOME"
fi

OPENCLAW_DIR="/opt/openclaw"
OPENCLAW_CONFIG="${REAL_HOME}/.openclaw/openclaw.json"
WORKSPACE_DIR="${REAL_HOME}/.openclaw/workspace"
SESSIONS_DIR="${REAL_HOME}/.openclaw/agents/main/sessions"

# =============================================================================
# VALIDAÇÕES
# =============================================================================
echo ""
echo "========================================="
echo "  Skill Loader — Configurar extraDirs"
echo "========================================="
echo ""

# Verificar openclaw instalado
if [[ ! -f "${OPENCLAW_DIR}/openclaw.mjs" ]]; then
  fail "OpenClaw não encontrado em ${OPENCLAW_DIR}"
fi

# Verificar config existe
if [[ ! -f "${OPENCLAW_CONFIG}" ]]; then
  fail "Config não encontrado em ${OPENCLAW_CONFIG}"
fi

ok "OpenClaw instalado em ${OPENCLAW_DIR}"
ok "Config em ${OPENCLAW_CONFIG}"

# =============================================================================
# DETECTAR AGENTE (apps/{nome}/skills/)
# =============================================================================
echo ""
info "Buscando agentes em ${WORKSPACE_DIR}/apps/..."

AGENTS_FOUND=()
if [[ -d "${WORKSPACE_DIR}/apps" ]]; then
  for agent_dir in "${WORKSPACE_DIR}/apps"/*/; do
    [[ ! -d "$agent_dir" ]] && continue
    agent_name=$(basename "$agent_dir")
    skills_dir="${agent_dir}skills"
    if [[ -d "$skills_dir" ]]; then
      # Contar SKILL.md (diretos e em subpastas)
      skill_count=$(find "$skills_dir" -name "SKILL.md" 2>/dev/null | wc -l)
      if [[ "$skill_count" -gt 0 ]]; then
        AGENTS_FOUND+=("$agent_name")
        ok "Agente '${agent_name}' — ${skill_count} skills encontradas"
      fi
    fi
  done
fi

if [[ ${#AGENTS_FOUND[@]} -eq 0 ]]; then
  fail "Nenhum agente com skills encontrado em ${WORKSPACE_DIR}/apps/"
fi

# Se mais de um agente, perguntar qual
if [[ ${#AGENTS_FOUND[@]} -eq 1 ]]; then
  AGENT_NAME="${AGENTS_FOUND[0]}"
  ok "Agente selecionado: ${AGENT_NAME}"
else
  echo ""
  echo "  Agentes encontrados:"
  for i in "${!AGENTS_FOUND[@]}"; do
    echo "    $((i+1))) ${AGENTS_FOUND[$i]}"
  done
  echo ""
  read -rp "  Escolha o agente [1-${#AGENTS_FOUND[@]}]: " choice
  choice=${choice:-1}
  idx=$((choice - 1))
  if [[ $idx -lt 0 || $idx -ge ${#AGENTS_FOUND[@]} ]]; then
    fail "Escolha inválida"
  fi
  AGENT_NAME="${AGENTS_FOUND[$idx]}"
  ok "Agente selecionado: ${AGENT_NAME}"
fi

SKILLS_PATH="${WORKSPACE_DIR}/apps/${AGENT_NAME}/skills"

# =============================================================================
# STEP 1: ADICIONAR extraDirs NO openclaw.json
# =============================================================================
echo ""
info "Configurando extraDirs no openclaw.json..."

python3 -c "
import json, sys

config_path = '${OPENCLAW_CONFIG}'
skills_path = '${SKILLS_PATH}'

with open(config_path) as f:
    cfg = json.load(f)

skills = cfg.setdefault('skills', {})
load = skills.setdefault('load', {})
extra_dirs = load.setdefault('extraDirs', [])

if skills_path in extra_dirs:
    print('ALREADY_EXISTS')
else:
    extra_dirs.append(skills_path)
    with open(config_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print('ADDED')
" | while read -r result; do
  case "$result" in
    ADDED)
      ok "extraDirs adicionado: ${SKILLS_PATH}" ;;
    ALREADY_EXISTS)
      step_skip "extraDirs já contém: ${SKILLS_PATH}" ;;
  esac
done

# =============================================================================
# STEP 2: CORRIGIR PATHS NOS SKILL.MD (substituir /home/user → ~)
# =============================================================================
echo ""
info "Verificando paths hardcoded nos SKILL.md..."

fix_count=0
while IFS= read -r skill_file; do
  # Corrigir /home/user/ → ~/
  if grep -q '/home/user/' "$skill_file" 2>/dev/null; then
    sed -i 's|/home/user/|~/|g' "$skill_file"
    ok "Corrigido /home/user/ → ~/ em $(basename "$(dirname "$skill_file")")/SKILL.md"
    fix_count=$((fix_count + 1))
  fi
  # Corrigir {{user}}/ → ~/
  if grep -q '{{user}}/' "$skill_file" 2>/dev/null; then
    sed -i 's|{{user}}/|~/|g' "$skill_file"
    ok "Corrigido {{user}}/ → ~/ em $(basename "$(dirname "$skill_file")")/SKILL.md"
    fix_count=$((fix_count + 1))
  fi
  # Corrigir /opt/legendsclaw/deployer/apps/{NOME_DO_AGENTE} → ~/
  if grep -q '/opt/legendsclaw/deployer/apps/{NOME_DO_AGENTE}' "$skill_file" 2>/dev/null; then
    sed -i "s|/opt/legendsclaw/deployer/apps/{NOME_DO_AGENTE}|~/.openclaw/workspace/apps/${AGENT_NAME}|g" "$skill_file"
    ok "Corrigido path legado em $(basename "$(dirname "$skill_file")")/SKILL.md"
    fix_count=$((fix_count + 1))
  fi
done < <(find "$SKILLS_PATH" -name "SKILL.md" 2>/dev/null)

if [[ $fix_count -eq 0 ]]; then
  ok "Nenhum path hardcoded encontrado — tudo limpo"
else
  ok "${fix_count} correções aplicadas"
fi

# =============================================================================
# STEP 3: LIMPAR SESSIONS (forçar novo skillsSnapshot)
# =============================================================================
echo ""
info "Limpando sessions para forçar novo skillsSnapshot..."

if [[ -d "$SESSIONS_DIR" ]]; then
  session_count=$(find "$SESSIONS_DIR" -name "*.jsonl" 2>/dev/null | wc -l)
  rm -f "${SESSIONS_DIR}"/*.jsonl
  rm -f "${SESSIONS_DIR}/sessions.json"
  ok "Sessions limpas (${session_count} removidas)"
else
  step_skip "Diretório de sessions não existe ainda"
fi

# =============================================================================
# STEP 4: REINICIAR GATEWAY
# =============================================================================
echo ""
info "Reiniciando gateway..."

if systemctl is-active openclaw &>/dev/null; then
  sudo systemctl restart openclaw
  sleep 3
  if systemctl is-active openclaw &>/dev/null; then
    ok "Gateway reiniciado e ativo"
  else
    fail "Gateway não voltou após restart"
  fi
else
  warn "Service openclaw não está ativo — pulando restart"
fi

# =============================================================================
# STEP 5: VERIFICAR SKILLS CARREGADAS
# =============================================================================
echo ""
info "Verificando skills do agente '${AGENT_NAME}'..."

skill_list=$(find "$SKILLS_PATH" -maxdepth 2 -name "SKILL.md" 2>/dev/null | while read -r f; do
  dirname "$f" | xargs basename
done | sort)

skill_total=$(echo "$skill_list" | wc -l)

echo ""
echo "  Skills disponíveis (${skill_total}):"
echo "$skill_list" | while read -r name; do
  echo "    /${name}"
done

# =============================================================================
# RESUMO
# =============================================================================
echo ""
echo "========================================="
echo "  Skill Loader — Concluído"
echo "========================================="
echo ""
echo "  Agente:      ${AGENT_NAME}"
echo "  Skills path: ${SKILLS_PATH}"
echo "  Config:      ${OPENCLAW_CONFIG}"
echo "  Sessions:    limpas (novo snapshot na próxima mensagem)"
echo "  Gateway:     $(systemctl is-active openclaw 2>/dev/null || echo 'desconhecido')"
echo ""
echo "  Próximo passo:"
echo "  Mande uma mensagem no WhatsApp para testar as skills."
echo "  Ex: /${AGENT_NAME}  ou  /nome-da-skill"
echo ""
echo "  Nota sobre paths nos SKILL.md:"
echo "  Use ~ para home do usuário. Nunca /home/user ou {{user}}."
echo "  A LLM expande ~ corretamente para o home real."
echo ""
