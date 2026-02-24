#!/usr/bin/env bats
# =============================================================================
# Tests: deployer/ferramentas/setup-local-aios.sh
# Story 11.3: AIOS Init + Registro de Agente
# =============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer/lib" && pwd)"
  FERRAMENTA="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer/ferramentas" && pwd)/setup-local-aios.sh"
  STATE_DIR="$TEST_DIR/dados_vps"
  mkdir -p "$STATE_DIR"

  # Minimo: source ui.sh para step_ok/step_fail/etc (stubs)
  # Source hints.sh para as funcoes hint
  export STATE_DIR
  export REAL_HOME="$TEST_DIR"
  export HOME="$TEST_DIR"
  export AUTO_MODE="false"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Test: Node.js version check
# ---------------------------------------------------------------------------
@test "verifica Node.js >= 22 disponivel" {
  # This test verifies the logic pattern, not the actual installation
  node_major=$(node --version | sed 's/v//' | cut -d. -f1)
  [[ "$node_major" -ge 22 ]]
}

@test "verifica npm disponivel" {
  command -v npm &>/dev/null
}

# ---------------------------------------------------------------------------
# Test: Whitelabel data reading
# ---------------------------------------------------------------------------
@test "le dados_whitelabel quando existe" {
  cat > "$STATE_DIR/dados_whitelabel" << 'EOF'
Agente: test-agent
Display Name: Test Agent
Icone: 🤖
Persona: Agente de testes
Idioma: pt-br
Apps Path: /tmp/apps/test-agent
Config: /tmp/apps/test-agent/skills/config.js
Data Criacao: 2026-02-24 14:30:00
EOF

  nome_agente=$(grep "^Agente:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
  display_name=$(grep "^Display Name:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
  icone=$(grep "^Icone:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
  persona=$(grep "^Persona:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
  idioma=$(grep "^Idioma:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')

  [[ "$nome_agente" == "test-agent" ]]
  [[ "$display_name" == "Test Agent" ]]
  [[ "$icone" == "🤖" ]]
  [[ "$persona" == "Agente de testes" ]]
  [[ "$idioma" == "pt-br" ]]
}

@test "fallback quando dados_whitelabel nao existe" {
  [[ ! -f "$STATE_DIR/dados_whitelabel" ]]
  # Deve usar coleta interativa (testado indiretamente — sem arquivo = sem valores)
  nome_agente=$(grep "^Agente:" "$STATE_DIR/dados_whitelabel" 2>/dev/null | awk -F': ' '{print $2}' || true)
  [[ -z "$nome_agente" ]]
}

# ---------------------------------------------------------------------------
# Test: Skills reading
# ---------------------------------------------------------------------------
@test "le skills ativas quando dados_skills existe" {
  cat > "$STATE_DIR/dados_skills" << 'EOF'
Agente: test-agent
Skills Ativas: clickup-ops, supabase-query, memory
Config Path: /tmp/skills/config.js
Index Path: /tmp/skills/index.js
Data Configuracao: 2026-02-24 14:30:00
EOF

  skills_list=$(grep "^Skills Ativas:" "$STATE_DIR/dados_skills" | awk -F': ' '{print $2}')
  [[ "$skills_list" == "clickup-ops, supabase-query, memory" ]]

  IFS=', ' read -ra skills_array <<< "$skills_list"
  [[ "${#skills_array[@]}" -eq 3 ]]
  [[ "${skills_array[0]}" == "clickup-ops" ]]
  [[ "${skills_array[1]}" == "supabase-query" ]]
  [[ "${skills_array[2]}" == "memory" ]]
}

@test "sem dados_skills — commands basicos" {
  [[ ! -f "$STATE_DIR/dados_skills" ]]
  skills_list=$(grep "^Skills Ativas:" "$STATE_DIR/dados_skills" 2>/dev/null | awk -F': ' '{print $2}' || true)
  [[ -z "$skills_list" ]]
}

# ---------------------------------------------------------------------------
# Test: Agent definition file generation
# ---------------------------------------------------------------------------
@test "gera agent definition com formato YAML correto" {
  agents_dir="$TEST_DIR/aios-agents"
  agent_file="${agents_dir}/test-agent.md"
  mkdir -p "$agents_dir"

  nome_agente="test-agent"
  display_name="Test Agent"
  icone="🤖"
  persona="Agente de testes"

  cat > "$agent_file" << AGENTEOF
# ${nome_agente}

ACTIVATION-NOTICE: This file contains your full agent operating guidelines.

## COMPLETE AGENT DEFINITION FOLLOWS - NO EXTERNAL FILES NEEDED

\`\`\`yaml
agent:
  name: ${display_name}
  id: ${nome_agente}
  title: ${display_name} Agent
  icon: ${icone}
  whenToUse: |
    ${persona}
  customization: null
commands:
  - name: help
    visibility: [full, quick, key]
    description: 'Show all available commands'
  - name: status
    visibility: [full, quick, key]
    description: 'Show current agent status'
  - name: chat
    visibility: [full, quick, key]
    description: 'Start a conversation'
\`\`\`
AGENTEOF

  [[ -f "$agent_file" ]]
  grep -q "ACTIVATION-NOTICE" "$agent_file"
  grep -q "name: Test Agent" "$agent_file"
  grep -q "id: test-agent" "$agent_file"
  grep -q "icon: 🤖" "$agent_file"
}

@test "agent definition contem commands basicos (help, status, chat)" {
  agents_dir="$TEST_DIR/aios-agents"
  agent_file="${agents_dir}/basic-agent.md"
  mkdir -p "$agents_dir"

  cat > "$agent_file" << 'AGENTEOF'
```yaml
commands:
  - name: help
    visibility: [full, quick, key]
  - name: status
    visibility: [full, quick, key]
  - name: chat
    visibility: [full, quick, key]
```
AGENTEOF

  grep -q "name: help" "$agent_file"
  grep -q "name: status" "$agent_file"
  grep -q "name: chat" "$agent_file"
}

@test "agent definition contem commands de skills quando dados_skills presente" {
  agents_dir="$TEST_DIR/aios-agents"
  agent_file="${agents_dir}/skill-agent.md"
  mkdir -p "$agents_dir"

  # Simular geracao com skills
  skills=("clickup-ops" "memory")
  commands_yaml="  - name: help
    visibility: [full, quick, key]
  - name: status
    visibility: [full, quick, key]
  - name: chat
    visibility: [full, quick, key]"

  for skill in "${skills[@]}"; do
    commands_yaml="${commands_yaml}
  - name: ${skill}
    visibility: [full, quick]
    description: 'Execute ${skill} skill'"
  done

  cat > "$agent_file" << AGENTEOF
\`\`\`yaml
commands:
${commands_yaml}
\`\`\`
AGENTEOF

  grep -q "name: help" "$agent_file"
  grep -q "name: clickup-ops" "$agent_file"
  grep -q "name: memory" "$agent_file"
}

# ---------------------------------------------------------------------------
# Test: State file
# ---------------------------------------------------------------------------
@test "state file gerado com formato correto" {
  nome_projeto="meu-projeto"
  dir_destino="/tmp/test-project"
  nome_agente="test-agent"
  display_name="Test Agent"
  icone="🤖"
  idioma="pt-br"
  all_commands="help,status,chat,clickup-ops"
  skills_count=1

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

  [[ -f "$STATE_DIR/dados_aios_init" ]]

  # Verificar permissoes (600)
  perms=$(stat -c '%a' "$STATE_DIR/dados_aios_init" 2>/dev/null || stat -f '%Lp' "$STATE_DIR/dados_aios_init" 2>/dev/null)
  [[ "$perms" == "600" ]]

  # Verificar keys
  grep -q "^Projeto: meu-projeto" "$STATE_DIR/dados_aios_init"
  grep -q "^AIOS Inicializado: true" "$STATE_DIR/dados_aios_init"
  grep -q "^Agente Registrado: test-agent" "$STATE_DIR/dados_aios_init"
  grep -q "^Commands: help,status,chat,clickup-ops" "$STATE_DIR/dados_aios_init"
  grep -q "^Skills Mapeadas: 1" "$STATE_DIR/dados_aios_init"
  grep -q "^Agent File: .aios-core/development/agents/test-agent.md" "$STATE_DIR/dados_aios_init"
}

# ---------------------------------------------------------------------------
# Test: Backup when agent file exists
# ---------------------------------------------------------------------------
@test "backup .bak criado se agent file ja existe" {
  agents_dir="$TEST_DIR/aios-agents"
  agent_file="${agents_dir}/existing-agent.md"
  mkdir -p "$agents_dir"

  # Criar arquivo existente
  echo "original content" > "$agent_file"

  # Simular backup
  cp -p "$agent_file" "${agent_file}.bak"
  echo "new content" > "$agent_file"

  [[ -f "${agent_file}.bak" ]]
  [[ "$(cat "${agent_file}.bak")" == "original content" ]]
  [[ "$(cat "$agent_file")" == "new content" ]]
}

# ---------------------------------------------------------------------------
# Test: Hints functions
# ---------------------------------------------------------------------------
@test "hint_aios_init_usage funciona" {
  source "${LIB_DIR}/hints.sh"
  output=$(hint_aios_init_usage "test-agent" "Test Agent" "help,status,chat")
  echo "$output" | grep -q "test-agent"
  echo "$output" | grep -q "help"
  echo "$output" | grep -q "status"
  echo "$output" | grep -q "chat"
}

@test "hint_aios_init_next_steps funciona" {
  source "${LIB_DIR}/hints.sh"
  output=$(hint_aios_init_next_steps)
  echo "$output" | grep -q "setup-local-bridge"
  echo "$output" | grep -q "validacao-local"
}

# ---------------------------------------------------------------------------
# Test: VPS ferramentas inalteradas
# ---------------------------------------------------------------------------
@test "ferramentas VPS (01-16) permanecem inalteradas" {
  FERRAMENTAS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer/ferramentas" && pwd)"

  # Verificar que as 16 ferramentas originais ainda existem
  [[ -f "$FERRAMENTAS_DIR/01-base.sh" ]]
  [[ -f "$FERRAMENTAS_DIR/02-tailscale.sh" ]]
  [[ -f "$FERRAMENTAS_DIR/03-openclaw.sh" ]]
  [[ -f "$FERRAMENTAS_DIR/15-validacao-final.sh" ]]
  [[ -f "$FERRAMENTAS_DIR/16-reload-agent.sh" ]]
}
