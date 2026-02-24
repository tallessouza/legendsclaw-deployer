# Epic 11 — Setup Local + Bridge Bidirecional

> **Status:** Draft
> **Criado por:** @pm (Morgan)
> **Data:** 2026-02-24
> **Tipo:** Brownfield Enhancement
> **Estimativa:** 4 stories | M (Medium)

---

## Epic Goal

Permitir que o deployer funcione tanto na **VPS** quanto na **máquina local** do usuário, adicionando:
1. Menu seletor de ambiente (Local vs VPS)
2. Preparação automatizada do ambiente local (git, Node.js, Claude Code) nos 3 SOs principais
3. Inicialização do projeto AIOS via `npx aios-core init`
4. Bridge bidirecional confiável entre máquina local e VPS via Tailscale

---

## Existing System Context

- **Deployer atual:** 16 ferramentas bash em `deployer/ferramentas/`, entry point em `deployer/deployer.sh`
- **Repositório:** O deployer vive dentro do repo principal (`legendsclaw`) mas possui um **remote dedicado** (`deployer` → `github.com/tallessouza/legendsclaw-deployer.git`). O conteúdo foi integrado via subtree merge, não submodule. Pushes podem precisar ir para ambos os remotes (`origin` e `deployer`).
- **Libs existentes:** ui.sh, logger.sh, common.sh, deploy.sh, hints.sh, env-detect.sh, auto.sh
- **Bridge atual:** `.aios-core/infrastructure/services/bridge.js` — auto-discovery de services, comandos status/list/validate-call/log-execution
- **env-detect.sh:** Já tem `detectar_ambiente()` que retorna "local" ou "vps" baseado em Docker Swarm state
- **setup.sh:** Bootstrap para VPS — instala Docker, Node.js 22, pnpm, jq, git, python3. **Não suporta macOS ou Windows.**
- **install.sh:** One-liner para VPS — clona repo em `/opt/legendsclaw` e roda setup.sh

### Integration Points

- `deployer.sh` → novo menu seletor antes do menu de ferramentas
- `env-detect.sh` → expandir para detectar SO (Linux/macOS/Windows-WSL)
- `bridge.js` → refatorar para suportar configuração local→remoto
- `.claude/settings.json` → hooks configurados pela bridge (ferramenta 12)
- `~/dados_vps/` → state files (manter compatibilidade)

### Technology Stack Relevante

- Bash 4.3+ (deployer)
- Node.js 22+ (bridge, OpenClaw)
- Claude Code CLI (hooks, settings)
- Tailscale (VPN mesh)

---

## Stories

### Story 11.1: Menu Seletor + Setup Local

**Descrição:** Criar menu de seleção de ambiente (Local/VPS) como primeira tela do deployer, e ferramenta `setup-local.sh` que prepara a máquina local do usuário com as dependências necessárias para os 3 SOs principais.

**Executor:** `@dev`
**Quality Gate:** `@architect`
**Quality Gate Tools:** `[code_review, pattern_validation, cross_platform_test]`

**Acceptance Criteria:**

- [ ] AC1: `deployer.sh` exibe menu de seleção antes do menu de ferramentas: `[1] Setup Local (minha máquina)` / `[2] Deploy VPS (servidor remoto)` / `[0] Sair`
- [ ] AC2: Opção `[1]` executa `ferramentas/setup-local.sh`
- [ ] AC3: Opção `[2]` exibe o menu atual de 16 ferramentas (comportamento inalterado)
- [ ] AC4: `setup-local.sh` detecta SO via `uname -s` + verificação de WSL: Linux nativo, macOS, Windows (via WSL)
- [ ] AC5: Para cada SO, instala/verifica: **git** (apt/brew/winget), **Node.js ≥ 22** (NodeSource/brew/nvm), **Claude Code CLI** (`npm install -g @anthropic-ai/claude-code` ou verifica se já existe)
- [ ] AC6: Instala/verifica **Tailscale** client: `curl -fsSL https://tailscale.com/install.sh | sh` (Linux), `brew install tailscale` (macOS), instruções para download Windows
- [ ] AC7: Feedback visual usa pattern existente: `step_ok`, `step_fail`, `step_skip` (sourcing de libs)
- [ ] AC8: Salva estado em `~/dados_vps/dados_local_setup` com: SO detectado, versões instaladas, Tailscale status
- [ ] AC9: No final, exibe hints sobre próximos passos (rodar setup-local-bridge, conectar Tailscale)
- [ ] AC10: Em Windows sem WSL, exibe instrução clara para instalar WSL primeiro e re-executar

**Scope IN:**
- Menu seletor no deployer.sh
- setup-local.sh com detecção de SO
- Instalação de git, Node.js, Claude Code CLI, Tailscale
- Feedback visual, logging, state file

**Scope OUT:**
- Não instala Docker localmente (só VPS precisa)
- Não faz build do OpenClaw localmente
- Não configura hooks do Claude Code (story 11.2)

**Risks:**
- macOS com Apple Silicon pode precisar de Rosetta para alguns packages → mitigação: testar `arch` e usar brew nativo ARM
- Windows sem WSL não tem bash → mitigação: AC10 detecta e orienta

**Files Estimados:**
- `deployer/deployer.sh` (modificar — menu seletor)
- `deployer/ferramentas/setup-local.sh` (novo)
- `deployer/lib/env-detect.sh` (expandir — detectar SO)

---

### Story 11.2: Bridge Local→VPS Bidirecional

**Descrição:** Refatorar a bridge para suportar o cenário onde o usuário está na máquina **local** e o gateway OpenClaw está na **VPS**. A bridge precisa: configurar a conexão Tailscale, validar conectividade, configurar hooks do Claude Code na máquina local, e garantir que o status mostra saúde real do gateway remoto.

**Executor:** `@dev`
**Quality Gate:** `@architect`
**Quality Gate Tools:** `[code_review, integration_test, security_review]`

**Acceptance Criteria:**

- [ ] AC1: Nova ferramenta `ferramentas/setup-local-bridge.sh` que configura a bridge na máquina local
- [ ] AC2: Coleta interativa (ou via auto-config): hostname Tailscale da VPS, porta do gateway (default 18789), nome do agente
- [ ] AC3: Verifica conectividade via `tailscale ping {hostname}` com timeout de 30s
- [ ] AC4: Verifica saúde do gateway remoto via `curl http://{hostname}.{tailnet}.ts.net:{porta}/health`
- [ ] AC5: Cria `.aios-core/infrastructure/services/{agent}/index.js` com URL do gateway remoto (Tailscale FQDN)
- [ ] AC6: Cria/atualiza `.claude/settings.json` com hooks (SessionStart, PreToolUse, PostToolUse) apontando para bridge.js local
- [ ] AC7: Testa bridge.js localmente: `node bridge.js status` retorna status real do gateway remoto
- [ ] AC8: Testa bridge.js list: mostra o serviço registrado
- [ ] AC9: Salva estado em `~/dados_vps/dados_bridge` (compatível com formato existente)
- [ ] AC10: Fallback graceful: se Tailscale não conectado, bridge reporta "offline" sem crashar
- [ ] AC11: Se `.claude/settings.json` já existe, faz merge das hooks sem sobrescrever outras configs (backup .bak antes)

**Scope IN:**
- Ferramenta setup-local-bridge.sh
- Verificação Tailscale local→VPS
- Configuração de hooks Claude Code
- Criação de service index para bridge auto-discovery
- Health check remoto via Tailscale

**Scope OUT:**
- Não instala Tailscale (isso é da story 11.1)
- Não configura o gateway no VPS (ferramentas 03/04 existentes fazem isso)
- Não altera bridge.js core (já funciona por auto-discovery)

**Risks:**
- Tailscale FQDN varia por tailnet (`.ts.net` suffix) → mitigação: detectar via `tailscale status --json`
- Firewalls corporativos podem bloquear Tailscale UDP → mitigação: hint sobre DERP relay

**Files Estimados:**
- `deployer/ferramentas/setup-local-bridge.sh` (novo)
- `deployer/lib/hints.sh` (expandir — hints de bridge local)
- `.claude/settings.json` (modificar — merge de hooks)

**Dependência:** Story 11.1 (setup-local.sh precisa ter rodado primeiro para ter Node.js e Tailscale)

---

### Story 11.3: AIOS Init + Registro de Agente

**Descrição:** Criar ferramenta que inicializa o projeto AIOS na máquina local via `npx aios-core init` e registra o agente criado pelo deployer como agente ativável no AIOS (arquivo `.aios-core/development/agents/{agent-name}.md`).

**Executor:** `@dev`
**Quality Gate:** `@architect`
**Quality Gate Tools:** `[code_review, pattern_validation, framework_compliance]`

**Acceptance Criteria:**

- [ ] AC1: Nova ferramenta `ferramentas/setup-local-aios.sh`
- [ ] AC2: Verifica Node.js ≥ 22 e npm disponíveis
- [ ] AC3: Pergunta nome do projeto (default: nome do diretório atual) e diretório destino
- [ ] AC4: Executa `npx aios-core init {nome_projeto}` no diretório escolhido
- [ ] AC5: Verifica que `.aios-core/` foi criado com sucesso
- [ ] AC6: Lê dados de `~/dados_vps/dados_whitelabel` (nome_agente, display_name, icone, persona, idioma) se existir
- [ ] AC7: Gera `.aios-core/development/agents/{agent-name}.md` com definição YAML completa (agent, persona, commands, dependencies) seguindo o formato dos agentes existentes no AIOS
- [ ] AC8: Os commands gerados incluem: `help`, `status`, `chat` e commands mapeados das skills ativas (lê `dados_skills`)
- [ ] AC9: As dependencies incluem referências às skills configuradas e tools disponíveis
- [ ] AC10: Salva estado em `~/dados_vps/dados_aios_init`
- [ ] AC11: Exibe instruções de uso: como ativar o agente (`@{agent-name}`), comandos disponíveis, como testar

**Scope IN:**
- Ferramenta setup-local-aios.sh
- `npx aios-core init`
- Geração de arquivo de definição do agente AIOS
- Mapeamento de skills existentes para commands do agente
- Instruções de uso

**Scope OUT:**
- Não cria stories ou tasks no AIOS (são workflows separados)
- Não configura MCPs (ferramenta separada, se necessário)
- Não faz `git push` (delegado a @devops)

**Risks:**
- `npx aios-core init` pode mudar de API entre versões → mitigação: pin version ou verificar output
- dados_whitelabel pode não existir se usuário começou pelo local → mitigação: coleta interativa como fallback

**Files Estimados:**
- `deployer/ferramentas/setup-local-aios.sh` (novo)
- `deployer/lib/hints.sh` (expandir — hints de AIOS)

**Dependência:** Story 11.1 (Node.js precisa existir)

---

### Story 11.4: Validação E2E Local

**Descrição:** Criar ferramenta de validação end-to-end para o setup local, verificando todos os componentes instalados e a conectividade com a VPS.

**Executor:** `@dev`
**Quality Gate:** `@qa`
**Quality Gate Tools:** `[integration_test, e2e_validation]`

**Acceptance Criteria:**

- [ ] AC1: Nova ferramenta `ferramentas/validacao-local.sh`
- [ ] AC2: Checklist de 8 pontos com feedback visual (step_ok/step_fail/step_skip):
  1. Git instalado e funcional
  2. Node.js ≥ 22 instalado
  3. Claude Code CLI instalado e funcional (`claude --version`)
  4. Tailscale instalado e conectado
  5. AIOS-Core inicializado (`.aios-core/` existe)
  6. Agente registrado no AIOS (`.aios-core/development/agents/{agent}.md` existe)
  7. Bridge conectando ao gateway remoto (`node bridge.js status` retorna OK)
  8. Claude Code hooks configurados (`.claude/settings.json` contém bridge.js)
- [ ] AC3: Se gateway remoto disponível, faz teste de mensagem via `curl` ao health endpoint
- [ ] AC4: Gera relatório em `~/dados_vps/relatorio_local.txt` com resultado de cada check
- [ ] AC5: Exibe resumo final com contagem OK/FAIL/SKIP
- [ ] AC6: Se algum check FAIL, exibe hint contextual sobre como corrigir (referenciando a ferramenta correta)
- [ ] AC7: Suporta `--quick` flag para checagem rápida (skip testes de rede se Tailscale offline)

**Scope IN:**
- Ferramenta validacao-local.sh
- 8-point checklist
- Relatório e hints contextuais
- Flag --quick

**Scope OUT:**
- Não corrige problemas automaticamente (apenas reporta)
- Não testa skills ou elicitation (validação do VPS, não local)

**Files Estimados:**
- `deployer/ferramentas/validacao-local.sh` (novo)
- `deployer/lib/hints.sh` (expandir — hints de validação local)

**Dependência:** Stories 11.1, 11.2, 11.3 (todas precisam ter rodado)

---

## Compatibility Requirements

- [ ] Menu de ferramentas VPS (01-16) permanece **100% inalterado**
- [ ] State files em `~/dados_vps/` mantêm formato `key: value` existente
- [ ] Libs (ui.sh, logger.sh, etc.) reutilizadas sem breaking changes
- [ ] `env-detect.sh` expandido de forma retrocompatível
- [ ] Bridge.js core não alterado — novas ferramentas usam a auto-discovery existente
- [ ] `deployer-auto.sh` (modo automático) não afetado

## Risk Mitigation

- **Primary Risk:** Incompatibilidade cross-platform (macOS/Windows)
  - **Mitigation:** Detecção de SO no início de cada ferramenta, fallback para instruções manuais
- **Secondary Risk:** Tailscale FQDN discovery falhar
  - **Mitigation:** Permitir input manual do hostname + verificação de conectividade
- **Rollback Plan:** Todas as ferramentas novas (setup-local, setup-local-bridge, setup-local-aios, validacao-local) são **adições** — remover é simplesmente deletar os arquivos e reverter o menu seletor no deployer.sh

## Definition of Done

- [ ] Todas as 4 stories completas com ACs atendidos
- [ ] Menu seletor funcional no deployer.sh
- [ ] Setup local funcional em Linux (testado)
- [ ] Bridge local→VPS funcional via Tailscale
- [ ] Agente registrado e ativável via `@{agent-name}` no AIOS
- [ ] Validação E2E passando
- [ ] Nenhuma regressão nas ferramentas VPS existentes (01-16)

---

## Story Manager Handoff

"Please develop detailed user stories for this brownfield epic. Key considerations:

- This is an enhancement to the existing Legendsclaw Deployer (bash scripts + Node.js bridge)
- Integration points: deployer.sh menu, env-detect.sh, bridge.js auto-discovery, ~/dados_vps/ state
- Existing patterns to follow: step_ok/step_fail/step_skip feedback, dados() state loading, conferindo_as_info confirmation, auto_confirm for auto-mode
- Critical compatibility: VPS ferramentas (01-16) must remain 100% unchanged
- Each story must verify that existing VPS functionality remains intact

The epic should maintain system integrity while delivering cross-platform local setup + bridge connectivity."

---

*— Morgan, planejando o futuro 📊*
