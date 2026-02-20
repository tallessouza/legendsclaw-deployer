# Epic 7 — Deployer Config Generation & Guide Alignment

> **Autor:** Morgan (@pm) | **Data:** 2026-02-20
> **Origem:** `docs/qa/qa_conformidade_guide.md` (QA Review by Quinn)
> **Referencia:** `apps/aiosbot-vps-stack-master/` (source of truth)
> **Status:** Draft

---

## Epic Goal

Fechar os gaps criticos entre o deployer e o stack de referencia (`aiosbot-vps-stack-master`), fazendo o deployer produzir **todos os artefatos de configuracao** necessarios para um agente funcional. Simultaneamente, reordenar as ferramentas para alinhar com o fluxo do `guide.md`.

## Epic Description

### Existing System Context

- **Deployer atual:** 14 ferramentas bash seguindo SetupOrion v2.8.0, com error handling robusto (Story 6.1)
- **Technology stack:** Bash, Docker Swarm, Portainer API, systemd, Node.js
- **Problema:** Deployer cobre infra (9/10) mas nao gera configs do agente (1/10). Constroi a casa mas nao coloca os moveis.

### Enhancement Details

- **O que muda:** Reordenar ferramentas + adicionar 2 novas (workspace, gateway-config) + expandir LLM Router + expandir validacao
- **Integracao:** Novas ferramentas seguem mesmo padrao SetupOrion (ui.sh, logger.sh, common.sh, deploy.sh)
- **Success criteria:** Apos executar todas as ferramentas, o resultado deve ser equivalente ao `aiosbot-vps-stack-master`

### Nova Ordem das Ferramentas

```
ANTES (14)                    DEPOIS (15)                      ACAO
setup.sh                      setup.sh                         — manter
01-base.sh                    01-base.sh                       — manter
02-postgres.sh                (removido como standalone)       absorvido por cascade
03-evolution.sh               13-evolution.sh                  renumerar (03→13)
04-tailscale.sh               02-tailscale.sh                  renumerar (04→02)
05-openclaw.sh                03-openclaw.sh                   renumerar (05→03)
06-validacao-gw.sh            04-validacao-gw.sh               renumerar (06→04)
07-whitelabel.sh              05-whitelabel.sh                 renumerar (07→05)
—                             06-workspace.sh                  [NOVO]
08-llm-router.sh              07-llm-router.sh                 renumerar + expandir
09-skills.sh                  08-skills.sh                     renumerar (09→08)
10-elicitation.sh             09-elicitation.sh                renumerar (10→09)
11-elicitation-schema.sh      10-elicitation-schema.sh         renumerar (11→10)
12-seguranca.sh               11-seguranca.sh                  renumerar (12→11)
13-bridge.sh                  12-bridge.sh                     renumerar (13→12)
—                             14-gateway-config.sh             [NOVO]
14-validacao-final.sh         15-validacao-final.sh            renumerar + expandir
```

### Cascade de Postgres

Postgres deixa de ser ferramenta standalone. A lib `common.sh` ja tem `verificar_container_postgres()` e `criar_banco_postgres_da_stack()`. Ferramentas que precisam de Postgres (Evolution, Elicitation Schema) fazem cascade automatico — detectam se Postgres existe, e se nao, instalam como dependencia.

---

## Stories

### Story 7.1: Reordenar Ferramentas do Deployer

**Descricao:** Renumerar os arquivos em `deployer/ferramentas/` para alinhar com o guide.md. Absorver `02-postgres.sh` como cascade. Atualizar `deployer.sh` (menu principal) e qualquer referencia cruzada.

```yaml
executor: "@devops"
quality_gate: "@qa"
quality_gate_tools: [script_validation, menu_verification, dependency_check]
```

**Acceptance Criteria:**
- [ ] AC1: Ferramentas renumeradas conforme tabela acima (02→13, 04→02, 05→03, 06→04, 07→05, 08→07, 09→08, 10→09, 11→10, 12→11, 13→12, 14→15)
- [ ] AC2: `02-postgres.sh` removido como standalone; funcao de cascade verificada em `03-evolution.sh` (nova 13) e `10-elicitation-schema.sh` (nova 10)
- [ ] AC3: `deployer.sh` menu atualizado com nova numeracao e nomes
- [ ] AC4: Nenhuma referencia cruzada quebrada (grep por numeros antigos)
- [ ] AC5: Todas as ferramentas ainda executam com sucesso (dry-run test)

**Quality Gates:**
- Pre-Commit: Verificar que `set -euo pipefail`, `setup_trap()`, `log_init()` presentes em todos
- Pre-PR: Grep por referencias a numeros antigos (01-14)

**Scope IN:**
- Renumerar arquivos
- Atualizar deployer.sh
- Verificar cascade de Postgres
- Atualizar testes existentes (`tests/deployer/lib-deploy.bats`)

**Scope OUT:**
- Nao alterar logica interna das ferramentas
- Nao criar ferramentas novas (stories separadas)

**Estimativa:** P (Pequeno) — Renomeacao + ajuste de menu

---

### Story 7.2: Criar Ferramenta 06-workspace.sh (Workspace Files)

**Descricao:** Nova ferramenta que gera os workspace files do agente a partir dos dados coletados pelo whitelabel. Produz os artefatos de personalidade que o stack de referencia define em `vps/workspace/`.

```yaml
executor: "@dev"
quality_gate: "@qa"
quality_gate_tools: [file_generation_validation, template_verification, content_review]
```

**Artefatos Gerados:**

| Arquivo | Fonte (stack referencia) | Dados de entrada |
|---------|------------------------|------------------|
| `SOUL.md` | `vps/workspace/SOUL.md` (42 linhas) | Persona, estilo, restricoes do `dados_whitelabel` |
| `AGENTS.md` | `vps/workspace/AGENTS.md` (202 linhas) | Skills ativas, categorias, heartbeat config |
| `BOOTSTRAP.md` | `vps/workspace/BOOTSTRAP.md` (51 linhas) | Nome agente, canais configurados |
| `MEMORY.md` | `vps/workspace/MEMORY.md` (16 linhas) | Template vazio com estrutura |
| `IDENTITY.md` | `vps/workspace/IDENTITY.md.template` | Nome, display, icon, persona, language do `dados_whitelabel` |
| `USER.md` | `vps/workspace/USER.md.template` | Nome usuario, org, preferencias (novo input ou elicitation) |

**Acceptance Criteria:**
- [ ] AC1: `06-workspace.sh` criado seguindo padrao SetupOrion (source libs, setup_trap, step_init, log_init)
- [ ] AC2: Carrega dados de `dados_whitelabel` (dependencia: 05-whitelabel.sh)
- [ ] AC3: Gera 6 arquivos no diretorio workspace do agente (`apps/{name}/workspace/` ou path configurado em `dados_openclaw`)
- [ ] AC4: SOUL.md gerado com persona, estilo e restricoes baseados nos dados coletados
- [ ] AC5: IDENTITY.md preenchido com nome, display, icon, persona, language
- [ ] AC6: USER.md coleta dados do usuario (nome, org) ou reutiliza de elicitation se disponivel
- [ ] AC7: AGENTS.md gerado com lista de skills ativas (referencia `dados_skills` se ja executou 08-skills)
- [ ] AC8: MEMORY.md e BOOTSTRAP.md gerados como templates com estrutura correta
- [ ] AC9: Estado salvo em `dados_workspace` (paths, arquivos gerados, status)
- [ ] AC10: `resumo_final()` exibe tabela com arquivos gerados e localizacao

**Quality Gates:**
- Pre-Commit: Verificar heredocs nao tem problemas de escaping
- Pre-PR: Comparar output com stack de referencia

**Scope IN:**
- Criar 06-workspace.sh
- Gerar 6 workspace files
- Salvar estado em dados_workspace

**Scope OUT:**
- Nao alterar 05-whitelabel.sh (apenas ler dados dele)
- Nao gerar aiosbot.json (story 7.4)

**Estimativa:** M (Medio) — Nova ferramenta com geracao de 6 arquivos

---

### Story 7.3: Expandir 07-llm-router.sh para Config Completa

**Descricao:** Expandir a ferramenta de LLM Router para gerar configuracao completa equivalente ao `vps/config/llm-router-config.yaml` do stack de referencia (167 linhas). Adicionar keywords com weights, fallback strategy, skill mapping granular e metrics config.

```yaml
executor: "@dev"
quality_gate: "@architect"
quality_gate_tools: [config_validation, yaml_lint, tier_cost_verification]
```

**Gaps a fechar (ref QA GAP-I1):**

| Aspecto | Atual | Esperado |
|---------|-------|----------|
| Tiers | 3 basicos (budget/standard/premium) | 4 completos (budget/standard/quality/premium) com max_cost e modelos especificos |
| Skill mapping | Apenas tier default | 12+ mappings granulares (skill→tier) |
| Keywords | Nenhum | 4 categorias com weights (0.3→0.9) |
| Fallback | Nenhum | max_retries_per_model, tier_escalation, anthropic_direct_fallback, on_error handlers |
| Metrics | Nenhum | enabled flag + storage config |

**Acceptance Criteria:**
- [ ] AC1: YAML gerado tem 4 tiers completos (budget, standard, quality, premium) com modelos e max_cost por tier
- [ ] AC2: Skill mapping gerado baseado nas skills ativas em `dados_skills` (se nao disponivel, usa defaults do stack)
- [ ] AC3: Keywords section gerado com 4 categorias e weights (budget:0.3, standard:0.5, quality:0.7, premium:0.9)
- [ ] AC4: Fallback strategy completa com max_retries_per_model (2), max_total_retries (5), tier_escalation (true), on_error handlers
- [ ] AC5: Metrics section gerado (enabled: false por default, configuravel)
- [ ] AC6: Backup do config anterior antes de sobrescrever
- [ ] AC7: Teste de validacao do YAML gerado (parse sem erros)
- [ ] AC8: Teste de tier budget com curl (ja existente, manter)

**Quality Gates:**
- Pre-Commit: YAML lint, verificar que max_cost values sao coerentes
- Pre-PR: Comparar output com `vps/config/llm-router-config.yaml` do stack

**Scope IN:**
- Expandir 07-llm-router.sh (nova numeracao)
- Gerar YAML completo
- Manter backward compatibility (teste de tier)

**Scope OUT:**
- Nao alterar lib/deploy.sh ou outras libs
- Nao implementar metrics collection (apenas config flag)

**Estimativa:** M (Medio) — Expansao de ferramenta existente

---

### Story 7.4: Criar Ferramenta 14-gateway-config.sh (Consolidacao)

**Descricao:** Nova ferramenta que consolida todos os dados coletados pelas ferramentas anteriores e gera os artefatos finais de configuracao: `aiosbot.json`, `node.json`, `.env` unificado e `mcp-config.json`. Esta ferramenta e o "assembler" — le de todos os `dados_*` e produz os configs prontos para uso.

```yaml
executor: "@dev"
quality_gate: "@architect"
quality_gate_tools: [json_validation, config_completeness, security_review]
```

**Artefatos Gerados:**

| Arquivo | Linhas ref | Dados de entrada (dados_*) |
|---------|-----------|---------------------------|
| `aiosbot.json` | 235 | portainer, openclaw, whitelabel, workspace, llm_router, skills, seguranca, evolution, tailscale, bridge |
| `node.json` | 10 | vps (hostname), tailscale (IP, tailnet), openclaw (port) |
| `.env` | 50+ | Todos os dados_* consolidados |
| `mcp-config.json` | 23 | skills, whitelabel (paths) |

**Acceptance Criteria:**
- [ ] AC1: `14-gateway-config.sh` criado seguindo padrao SetupOrion
- [ ] AC2: Le dados de TODOS os `dados_*` em `~/dados_vps/` (pelo menos: vps, portainer, openclaw, whitelabel, llm_router, skills, seguranca, tailscale)
- [ ] AC3: Gera `aiosbot.json` completo com secoes: meta, env.vars, browser, models (providers + aliases), agents.defaults (model, workspace, memorySearch, compaction, heartbeat, subagents), tools (shell denyPatterns, filesystem), hooks, channels, gateway, skills
- [ ] AC4: Models section inclui provider `anthropic-router` + fallbacks + 10 aliases (reasoning, media, fast, haiku, sonnet, opus, etc) baseados nas API keys disponiveis
- [ ] AC5: Tools.shell.denyPatterns preenchido a partir de `dados_seguranca` (blocklist)
- [ ] AC6: Channels.whatsapp preenchido a partir de `dados_evolution` (se disponivel)
- [ ] AC7: Gateway config com port de `dados_openclaw`, auth password (novo input ou gerado), tailscale mode de `dados_tailscale`
- [ ] AC8: Gera `node.json` com UUID auto-gerado, displayName de `dados_vps`, gateway host de `dados_tailscale`
- [ ] AC9: Gera `.env` consolidado com todas as variaveis organizadas por categoria (Identity, VPS, Security, LLM, Supabase, Services, Advanced)
- [ ] AC10: Gera `mcp-config.json` com Brave Search (se API key disponivel), Filesystem (workspace path), Memory (se Supabase configurado)
- [ ] AC11: Todos os arquivos gerados com `chmod 600` (contem credenciais)
- [ ] AC12: Resumo final mostra tabela com artefatos gerados, paths e tamanhos
- [ ] AC13: JSON gerado e valido (parse sem erros via `node -e`)

**Quality Gates:**
- Pre-Commit: JSON lint, verificar que nenhuma API key e placeholder
- Pre-PR: Comparar estrutura do aiosbot.json gerado com template do stack

**Scope IN:**
- Criar 14-gateway-config.sh
- Gerar 4 artefatos (aiosbot.json, node.json, .env, mcp-config.json)
- Ler de todos os dados_* existentes

**Scope OUT:**
- Nao alterar ferramentas anteriores
- Nao implementar logica de deploy dos configs (apenas gerar)
- Nao implementar todos os 10 aliases se API keys nao disponiveis (graceful: apenas aliases com keys)

**Estimativa:** G (Grande) — Ferramenta complexa que consolida todo o estado

---

### Story 7.5: Expandir 15-validacao-final.sh para Novos Artefatos

**Descricao:** Expandir a validacao final para verificar os novos artefatos gerados: workspace files, aiosbot.json, node.json, .env consolidado, mcp-config.json, e LLM Router completo.

```yaml
executor: "@dev"
quality_gate: "@qa"
quality_gate_tools: [validation_completeness, checklist_coverage, regression_test]
```

**Novos Checks (alem dos 12 existentes):**

| # | Check | Valida |
|---|-------|--------|
| 13 | Workspace files existem | SOUL.md, AGENTS.md, IDENTITY.md, USER.md em workspace/ |
| 14 | aiosbot.json valido | JSON parse OK + secoes obrigatorias presentes |
| 15 | node.json valido | UUID presente, gateway host preenchido |
| 16 | .env consolidado | Arquivo existe + variaveis criticas presentes (OPENROUTER, ANTHROPIC) |
| 17 | mcp-config.json valido | JSON parse OK |
| 18 | LLM Router completo | YAML parse OK + 4 tiers + skill_mapping + fallback presentes |

**Acceptance Criteria:**
- [ ] AC1: 6 novos checks adicionados (13-18)
- [ ] AC2: Check 14 (aiosbot.json) valida presenca de secoes: models, agents, tools, gateway
- [ ] AC3: Check 16 (.env) valida que API keys nao sao placeholders
- [ ] AC4: Relatorio final (`relatorio_instalacao.txt`) inclui status dos novos checks
- [ ] AC5: Score final reflete nova contagem (18 checks total)
- [ ] AC6: Hints de falha para cada novo check

**Quality Gates:**
- Pre-Commit: Verificar que checks nao quebram em ambiente sem os novos artefatos (graceful skip)
- Pre-PR: Executar validacao completa em ambiente de teste

**Scope IN:**
- Expandir 15-validacao-final.sh (nova numeracao)
- 6 novos checks
- Atualizar relatorio

**Scope OUT:**
- Nao alterar logica dos 12 checks existentes
- Nao criar testes automatizados (bats)

**Estimativa:** P (Pequeno) — Adicionar checks ao script existente

---

## Compatibilidade e Riscos

### Compatibilidade

- [ ] Ferramentas renumeradas mantém mesma logica interna
- [ ] `dados_vps/` structure nao muda (apenas novos arquivos: dados_workspace, etc)
- [ ] Libs compartilhadas (ui.sh, logger.sh, common.sh, deploy.sh) nao precisam de alteracao
- [ ] Cascade de Postgres ja implementado em evolution.sh — apenas remover standalone

### Riscos

| Risco | Probabilidade | Impacto | Mitigacao |
|-------|--------------|---------|-----------|
| Renumeracao quebra referencias | Media | Alto | Grep exhaustivo por numeros antigos |
| aiosbot.json incompativel com gateway | Baixa | Alto | Comparar com template do stack |
| Workspace files com conteudo generico demais | Media | Medio | Usar stack como referencia direta |
| .env com credenciais expostas | Baixa | Alto | chmod 600 + .gitignore |

### Rollback Plan

Cada ferramenta pode ser revertida independentemente:
- Renumeracao: `git checkout` dos arquivos originais
- Novas ferramentas: Simplesmente nao executar (deployer.sh menu)
- LLM Router: Backup criado antes de sobrescrever

---

## Ordem de Execucao

```
Story 7.1 (reorder) ─────────────────────────────────────> pode comecar imediatamente
Story 7.2 (workspace) ───> depende de 7.1 (nova numeracao)
Story 7.3 (llm-router) ──> depende de 7.1 (nova numeracao)
Story 7.4 (gateway-config) > depende de 7.1 + 7.2 + 7.3 (le dados de todos)
Story 7.5 (validacao) ────> depende de 7.4 (valida artefatos)
```

Wave 1: Story 7.1
Wave 2: Story 7.2 + 7.3 (paralelo)
Wave 3: Story 7.4
Wave 4: Story 7.5

---

## Definition of Done

- [ ] Todas as 15 ferramentas executam sem erro
- [ ] Novos artefatos gerados (aiosbot.json, node.json, workspace files, .env, mcp-config.json)
- [ ] LLM Router config equivalente ao stack de referencia
- [ ] Validacao final passa com 18/18 checks
- [ ] Menu do deployer.sh atualizado
- [ ] Nenhuma regressao nas ferramentas existentes
- [ ] QA re-review score >= 85% contra stack de referencia

---

## Handoff to Story Manager

"Por favor desenvolva stories detalhadas para este epic de brownfield. Consideracoes:

- Sistema existente: Deployer bash com 14 ferramentas seguindo SetupOrion v2.8.0
- Stack de referencia: `apps/aiosbot-vps-stack-master/` (simulacao do produto final)
- Padroes a seguir: source libs, setup_trap(), step_init(), log_init(), step_ok/fail/skip, resumo_final()
- Integracao: Novos dados salvos em `~/dados_vps/dados_*`, lidos pela ferramenta consolidadora
- Cada story deve verificar que ferramentas existentes continuam funcionando

O epic deve transformar o deployer de 'instalador de infra' para 'gerador de produto completo'."

---

*— Morgan, planejando o futuro*
