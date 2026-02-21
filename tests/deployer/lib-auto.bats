#!/usr/bin/env bats

# =============================================================================
# Testes para deployer/lib/auto.sh
# Framework: bats-core
# Execucao: npx bats tests/deployer/lib-auto.bats
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../deployer" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

setup() {
  export TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR"
  export AUTO_CONFIG="$TEST_DIR/test-config.env"
  # Source lib removendo readonly
  source <(sed 's/^readonly //g' "$LIB_DIR/auto.sh" 2>/dev/null || true)
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# auto_load_config — parse basico
# -----------------------------------------------------------------------------
@test "auto_load_config parseia config corretamente" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.dominio_portainer: painel.exemplo.com
base.email_ssl: admin@exemplo.com
EOF
  auto_load_config
  [ "${_AUTO_VALUES[base.dominio_portainer]}" = "painel.exemplo.com" ]
  [ "${_AUTO_VALUES[base.email_ssl]}" = "admin@exemplo.com" ]
}

@test "auto_load_config ignora linhas vazias" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.key1: valor1

base.key2: valor2
EOF
  auto_load_config
  [ "${_AUTO_VALUES[base.key1]}" = "valor1" ]
  [ "${_AUTO_VALUES[base.key2]}" = "valor2" ]
}

@test "auto_load_config ignora comentarios" {
  cat > "$AUTO_CONFIG" << 'EOF'
# Comentario
base.key1: valor1
  # Comentario indentado
base.key2: valor2
EOF
  auto_load_config
  [ "${_AUTO_VALUES[base.key1]}" = "valor1" ]
  [ "${_AUTO_VALUES[base.key2]}" = "valor2" ]
  [ "${#_AUTO_VALUES[@]}" -eq 2 ]
}

@test "auto_load_config chave com espacos em valor" {
  cat > "$AUTO_CONFIG" << 'EOF'
workspace.user_name: Fulano de Tal
EOF
  auto_load_config
  [ "${_AUTO_VALUES[workspace.user_name]}" = "Fulano de Tal" ]
}

@test "auto_load_config chave duplicada usa ultimo valor" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.key1: primeiro
base.key1: segundo
EOF
  auto_load_config
  [ "${_AUTO_VALUES[base.key1]}" = "segundo" ]
}

@test "auto_load_config falha se AUTO_CONFIG vazio" {
  export AUTO_CONFIG=""
  run auto_load_config
  [ "$status" -eq 1 ]
  [[ "$output" == *"AUTO_CONFIG nao definido"* ]]
}

@test "auto_load_config falha se arquivo nao existe" {
  export AUTO_CONFIG="$TEST_DIR/nao-existe.env"
  run auto_load_config
  [ "$status" -eq 1 ]
  [[ "$output" == *"nao encontrado"* ]]
}

# -----------------------------------------------------------------------------
# input — AUTO_MODE=true
# -----------------------------------------------------------------------------
@test "input em AUTO_MODE retorna valor do config" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.dominio: painel.exemplo.com
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  input "base.dominio" "Dominio: " resultado
  [ "$resultado" = "painel.exemplo.com" ]
}

@test "input em AUTO_MODE exibe chave e valor" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.dominio: painel.exemplo.com
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  run bash -c "
    source <(sed 's/^readonly //g' '$LIB_DIR/auto.sh' 2>/dev/null || true)
    export AUTO_MODE=true
    export AUTO_CONFIG='$AUTO_CONFIG'
    auto_load_config
    input 'base.dominio' 'Dominio: ' resultado
  "
  [[ "$output" == *"[auto] base.dominio: painel.exemplo.com"* ]]
}

# -----------------------------------------------------------------------------
# input --required
# -----------------------------------------------------------------------------
@test "input --required falha se chave ausente em AUTO_MODE" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.outro: valor
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  run input "base.chave_inexistente" "Prompt: " resultado --required
  [ "$status" -eq 1 ]
  [[ "$output" == *"Chave obrigatoria ausente"* ]]
}

@test "input --required retorna OK se chave existe" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.dominio: painel.exemplo.com
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  input "base.dominio" "Dominio: " resultado --required
  [ "$resultado" = "painel.exemplo.com" ]
}

# -----------------------------------------------------------------------------
# input --default=X
# -----------------------------------------------------------------------------
@test "input --default preenche valor quando chave ausente em AUTO_MODE" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.outro: valor
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  input "base.porta" "Porta: " resultado --default=18789
  [ "$resultado" = "18789" ]
}

@test "input --default nao sobrescreve valor existente" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.porta: 9999
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  input "base.porta" "Porta: " resultado --default=18789
  [ "$resultado" = "9999" ]
}

# -----------------------------------------------------------------------------
# input --secret
# -----------------------------------------------------------------------------
@test "input --secret redact no log em AUTO_MODE" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.pass: MinhaSenh4Segura!
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  run bash -c "
    source <(sed 's/^readonly //g' '$LIB_DIR/auto.sh' 2>/dev/null || true)
    export AUTO_MODE=true
    export AUTO_CONFIG='$AUTO_CONFIG'
    auto_load_config
    input 'base.pass' 'Senha: ' resultado --secret
  "
  [[ "$output" == *"********"* ]]
  [[ "$output" != *"MinhaSenh4Segura"* ]]
}

@test "input --secret atribui valor corretamente" {
  cat > "$AUTO_CONFIG" << 'EOF'
base.pass: MinhaSenh4Segura!
EOF
  export AUTO_MODE="true"
  auto_load_config
  local resultado=""
  input "base.pass" "Senha: " resultado --secret
  [ "$resultado" = "MinhaSenh4Segura!" ]
}

# -----------------------------------------------------------------------------
# input — modo interativo (AUTO_MODE=false)
# -----------------------------------------------------------------------------
@test "input em modo normal chama read via stdin" {
  export AUTO_MODE="false"
  local resultado=""
  # Simular input do usuario via redirecionamento (sem pipe para preservar nameref)
  input "base.key" "Prompt: " resultado <<< "valor_digitado"
  [ "$resultado" = "valor_digitado" ]
}

@test "input --default em modo interativo preenche quando vazio" {
  export AUTO_MODE="false"
  local resultado=""
  # Enter vazio — default deve ser aplicado
  input "base.porta" "Porta: " resultado --default=18789 <<< ""
  [ "$resultado" = "18789" ]
}

# -----------------------------------------------------------------------------
# auto_confirm
# -----------------------------------------------------------------------------
@test "auto_confirm retorna s em AUTO_MODE" {
  export AUTO_MODE="true"
  local resultado=""
  auto_confirm "Confirma? (s/n): " resultado
  [ "$resultado" = "s" ]
}

@test "auto_confirm exibe mensagem de confirmacao automatica" {
  export AUTO_MODE="true"
  local resultado=""
  run bash -c "
    source <(sed 's/^readonly //g' '$LIB_DIR/auto.sh' 2>/dev/null || true)
    export AUTO_MODE=true
    auto_confirm 'Confirma? ' resultado
  "
  [[ "$output" == *"[auto] Confirmado automaticamente"* ]]
}

@test "auto_confirm em modo normal chama read via stdin" {
  export AUTO_MODE="false"
  local resultado=""
  auto_confirm "Confirma? " resultado <<< "n"
  [ "$resultado" = "n" ]
}

# -----------------------------------------------------------------------------
# AUTO_MODE=false nao altera comportamento (noop)
# -----------------------------------------------------------------------------
@test "AUTO_MODE=false nao altera comportamento quando sourced" {
  export AUTO_MODE="false"
  # Verificar que _AUTO_VALUES esta vazio e nenhuma funcao falha
  [ "${#_AUTO_VALUES[@]}" -eq 0 ]
  # auto_load_config nao e chamado em modo normal, mas nao deve falhar se config nao existe
  [ "$AUTO_MODE" = "false" ]
}

# -----------------------------------------------------------------------------
# Script syntax
# -----------------------------------------------------------------------------
@test "auto.sh tem syntax valida" {
  run bash -n "$LIB_DIR/auto.sh"
  [ "$status" -eq 0 ]
}

@test "auto.sh tem shebang correto" {
  run head -1 "$LIB_DIR/auto.sh"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}
