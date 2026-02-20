# QA — Conformidade: Deployer vs Guide + Stack de Referencia

> **Revisor:** Quinn (@qa) + Morgan (@pm) | **Data:** 2026-02-20
> **Referencias:**
> - `docs/objetivo/guide.md` (v1.0, 2026-02-14) — Instrucoes de instalacao
> - `apps/aiosbot-vps-stack-master/` — Simulacao do produto final (source of truth)
> **Escopo:** Deployer (`deployer/`) — 14 ferramentas + setup.sh + libs
> **Veredicto Geral:** FAIL (gaps criticos na geracao de configs do agente)

---

## 1. Resumo Executivo

O deployer foi avaliado em duas dimensoes:

1. **Deployer vs Guide** — O deployer cobre as fases de instalacao do guide?
2. **Deployer vs Stack** — O deployer produz o resultado esperado (aiosbot-vps-stack)?

### Contexto Arquitetural

- **`aiosbot-vps-stack-master`** = Simulacao do produto final (como ficaria no mundo real)
- **`guide.md`** = Instrucoes de instalacao (o manual que o deployer automatiza)
- **`deployer/`** = Automacao que executa o guide e produz o stack

O deployer e forte em **infraestrutura** (Docker Swarm, Traefik, Portainer, Tailscale, Postgres, Evolution) mas fraco na **geracao de configuracoes do agente** — que e exatamente o que o stack de referencia define.

### Scores

| Dimensao | Score | Nota |
|----------|-------|------|
| Deployer vs Guide (infraestrutura) | **85%** | Fases de infra bem cobertas |
| Deployer vs Stack (configs do agente) | **~30%** | Gaps criticos em configs, workspace, skills |
| Score combinado | **~55%** | Infra OK, configs do agente faltando |

---

## 2. Deployer vs Guide — Matriz de Conformidade

> **Nota:** N8N, ClickUp e Slack sao **configuracao do agente** feita pelo usuario seguindo o guide. Nao sao escopo do deployer.

### Fase 1 — Instalar OpenClaw Gateway

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Clone repositorio | `git clone` + `pnpm install` | `05-openclaw.sh` step 6-7 | OK |
| Build (ui:build + build) | `pnpm ui:build && pnpm build` | `05-openclaw.sh` step 8-9 | OK |
| Onboard daemon | `pnpm openclaw onboard --install-daemon` | `05-openclaw.sh` step 10 | OK |
| Teste local (porta 18789) | `openclaw doctor` + `openclaw agent --message` | `06-validacao-gw.sh` step 5-7 | OK |

**Status: COBERTO**

---

### Fase 2 — Configurar VPS + Tailscale

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Atualizar sistema | `apt update && apt upgrade` | `setup.sh` step 3 | OK |
| Instalar Node.js 22 | `nodesource setup_22.x` | `setup.sh` step 10-11 | OK |
| Instalar pnpm | `npm install -g pnpm` | `setup.sh` step 12 | OK |
| Instalar Docker | `apt install docker.io` | `setup.sh` step 6-7 | OK |
| Instalar Tailscale | `curl tailscale.com/install.sh` | `04-tailscale.sh` step 4 | OK |
| Autenticar Tailscale | `tailscale up --hostname=` | `04-tailscale.sh` step 6 | OK |
| Tailscale Funnel | `tailscale funnel 18789` | `04-tailscale.sh` step 8 | OK |
| Deploy OpenClaw VPS + systemd | Clone + build + unit file | `05-openclaw.sh` steps 5-13 | OK |

**Status: COBERTO (100%)**

---

### Fase 3 — Customizar Identidade Whitelabel

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Definir nome agente | Placeholder `{AGENT_NAME}` | `07-whitelabel.sh` step 2 | OK |
| Criar `apps/{name}/` com subdirs | config, hooks, lib, skills | `07-whitelabel.sh` step 4 | OK |
| Customizar config.js | Trocar URLs, IDs, credenciais | `07-whitelabel.sh` step 5 | OK |

**Status: COBERTO (guide)** — Mas ver Secao 3 para gaps vs stack

---

### Fase 4 — Configurar LLM Router

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Copiar config YAML | De clawdbot | `07-whitelabel.sh` cria placeholder | OK |
| Configurar .env com API keys | OpenRouter, Anthropic, DeepSeek | `08-llm-router.sh` steps 3, 6 | OK |
| Editar tiers | budget/standard/premium | `08-llm-router.sh` step 4 | OK |

**Status: COBERTO (guide)** — Mas ver Secao 3 para gaps vs stack

---

### Fase 5 — Instalar Skills AIOS

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Copiar skills base | `cp -r apps/clawdbot/skills/*` | `09-skills.sh` step 6 | OK |
| npm install | `cd skills && npm install` | `09-skills.sh` step 10 | OK |
| Customizar por skill | Team ID, Workflow IDs | `09-skills.sh` steps 3-4 | OK |
| Elicitation skill (extra) | Nao no guide | `10-elicitation.sh` + `11-schema.sh` | EXTRA |

**Status: COBERTO + extras**

---

### Fase 6 — Seguranca (3 Layers)

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Layer 1: Blocklist + command-safety | YAML + JS | `12-seguranca.sh` steps 3-5 | OK |
| Layer 2: Docker sandbox | Alpine, network:none, 256m | `12-seguranca.sh` steps 6-7 | OK |
| Layer 3: journald + logrotate | 6 meses retencao | `12-seguranca.sh` steps 8-9 | OK |

**Status: COBERTO (100%)**

---

### Fase 7 — Integrar com Claude Code (Hooks + Bridge)

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| Criar service index.js | `.aios-core/infrastructure/services/{agent}/` | `13-bridge.sh` step 5 | OK |
| Configurar hooks (SessionStart, PreToolUse, PostToolUse) | settings.json | `13-bridge.sh` step 7 | OK |
| Testar bridge | `bridge.js status` + `list` | `13-bridge.sh` step 8 | OK |

**Status: COBERTO (100%)**

---

### Fases 8-9 — N8N + Canais (FORA DE ESCOPO)

N8N, ClickUp e Slack sao **configuracao do agente** que o usuario faz seguindo o guide. O deployer nao precisa automatizar estas fases. WhatsApp/Evolution **e** coberto pelo deployer (`03-evolution.sh`) como extra.

---

### Fase 10 — Validacao Final

| Aspecto | Guide | Deployer | Status |
|---------|-------|----------|--------|
| 8 checks do guide | Gateway, Tailscale, Bridge, LLM, Skills, Security, Hooks | `14-validacao-final.sh` (12 checks) | OK+ |
| Teste E2E | 7 passos manuais | Automatizado + teste WhatsApp opcional | OK+ |

**Status: COBERTO — Deployer excede o guide (12 checks vs 8)**

---

### Resumo Guide

| Fase | Status |
|------|--------|
| Fase 1: OpenClaw Gateway | OK |
| Fase 2: VPS + Tailscale | OK |
| Fase 3: Whitelabel | OK (guide) |
| Fase 4: LLM Router | OK (guide) |
| Fase 5: Skills | OK + extras |
| Fase 6: Seguranca | OK |
| Fase 7: Bridge + Hooks | OK |
| Fase 8-9: N8N/Canais | Fora de escopo |
| Fase 10: Validacao | OK+ |

**Score Guide: 85%** (descontando fases fora de escopo)

---

## 3. Deployer vs Stack — Analise de Produto Final

Esta e a analise **critica**. O `aiosbot-vps-stack-master` e a simulacao do que o deployer deve produzir. Comparamos artefato por artefato.

### 3.1 Gateway Config (`aiosbot.json`)

**Referencia:** `vps/config/aiosbot.json.template` (235 linhas)

Contem configuracao completa do gateway:
- `env.vars` — Todas as API keys e credenciais
- `browser` — Headless browser config
- `models` — Providers (anthropic-router, fallbacks), aliases (reasoning, media, fast, haiku, sonnet, opus)
- `agents.defaults` — Model primary/fallbacks, workspace, memorySearch, contextPruning, compaction, heartbeat, subagents
- `tools` — Shell denyPatterns, filesystem restrictions, web search/fetch, media
- `hooks` — Token-based hook auth
- `channels` — WhatsApp/Telegram config com dmPolicy
- `gateway` — Port, mode, bind, auth, tailscale config
- `skills` — Skills entries

| Aspecto | Stack tem | Deployer gera | Status |
|---------|-----------|---------------|--------|
| aiosbot.json completo | Sim (235 linhas, 10+ secoes) | **NAO** | **CRITICO** |
| Model providers + aliases | 10+ aliases (reasoning, media, fast...) | Nenhum | **CRITICO** |
| Agent defaults (memory, compaction, heartbeat) | Sim | Nenhum | **CRITICO** |
| Tool restrictions (shell deny, filesystem) | Sim | Parcial (blocklist em `12-seguranca.sh`) | PARCIAL |
| Channel config (WhatsApp dmPolicy, allowlist) | Sim | Nenhum (Evolution faz deploy, nao config) | **GAP** |
| Gateway auth (password, bind, tailscale mode) | Sim | Nenhum | **GAP** |

**Veredicto: 0% — Deployer nao gera aiosbot.json**

---

### 3.2 Node Registry (`node.json`)

**Referencia:** `vps/config/node.json.template` (10 linhas)

| Aspecto | Stack tem | Deployer gera | Status |
|---------|-----------|---------------|--------|
| node.json com UUID | Sim | **NAO** | **CRITICO** |
| displayName + gateway host/port/tls | Sim | Nenhum | **CRITICO** |

**Veredicto: 0% — Deployer nao gera node.json**

---

### 3.3 LLM Router Config (`llm-router-config.yaml`)

**Referencia:** `vps/config/llm-router-config.yaml` (167 linhas)

| Aspecto | Stack tem | Deployer gera | Status |
|---------|-----------|---------------|--------|
| 4 tiers (budget/standard/quality/premium) | Sim, com modelos especificos e max_cost | Gera tiers basicos | PARCIAL |
| Skill mapping (12+ skills → tiers) | Sim | Apenas tier default | **GAP** |
| Keywords com weights (0.3→0.9) | Sim | Nenhum | **GAP** |
| Fallback strategy (tier escalation, retries, backoff) | Sim (detalhado) | Nenhum | **GAP** |
| Metrics config | Sim | Nenhum | **GAP** |

**Veredicto: ~25% — Deployer gera versao simplificada, faltam keywords, fallback, metrics**

---

### 3.4 Environment Variables (`.env`)

**Referencia:** `.env.example` (50+ variaveis em 8 categorias)

| Categoria | Stack tem | Deployer gera | Status |
|-----------|-----------|---------------|--------|
| Identity (ORG_NAME, USER_NAME, AGENT_NAME) | Sim | Parcial (07-whitelabel coleta nome) | PARCIAL |
| VPS Config (IP, hostname, tailnet) | Sim | Parcial (04-tailscale salva em dados_vps) | PARCIAL |
| Security (GATEWAY_PASSWORD, HOOKS_TOKEN) | Sim | Nenhum | **GAP** |
| LLM API Keys (4 providers) | Sim | Sim (08-llm-router) | OK |
| Supabase (URL, keys, DB) | Sim | Parcial (11-schema coleta URL/key) | PARCIAL |
| Services (ClickUp, N8N, WhatsApp) | Sim | Parcial | PARCIAL |
| Advanced (LOG_LEVEL, DAILY_BUDGET_USD) | Sim | Nenhum | **GAP** |

**Veredicto: ~40% — Deployer coleta dados mas nao consolida em .env unificado**

---

### 3.5 Workspace Files (Personalidade do Agente)

**Referencia:** `vps/workspace/` (6 arquivos)

| Arquivo | Descricao | Stack tem | Deployer gera | Status |
|---------|-----------|-----------|---------------|--------|
| SOUL.md | Identidade core, restricoes, estilo | Sim (42 linhas) | **NAO** | **CRITICO** |
| AGENTS.md | Guia do workspace, skills, heartbeat | Sim (202 linhas) | **NAO** | **CRITICO** |
| BOOTSTRAP.md | Primeiro uso, onboarding | Sim (51 linhas) | **NAO** | **GAP** |
| MEMORY.md | Template de memoria persistente | Sim (16 linhas) | **NAO** | **GAP** |
| IDENTITY.md.template | Identidade gerada | Sim | **NAO** | **CRITICO** |
| USER.md.template | Contexto do usuario | Sim | **NAO** | **CRITICO** |

**Veredicto: 0% — Deployer nao gera nenhum workspace file**

---

### 3.6 Skills (32 vs 6)

**Referencia:** `vps/skills/` (32 skills em 6 categorias)

| Categoria | Stack tem | Deployer gera | Status |
|-----------|-----------|---------------|--------|
| Infrastructure (4) | supabase-query, n8n-trigger, clickup-ops, allos-status | `09-skills.sh` gera estas 4 + alerts + memory | OK |
| Memory (4) | knowledge-graph, unified-memory, context-recovery, todo-tracker | **NAO** | **GAP** |
| Dev (5) | react-best-practices, composition-patterns, web-design, vercel-deploy, react-native | **NAO** | **GAP** |
| Superpowers (14) | brainstorming, writing-plans, TDD, executing, verification, code-review, etc | **NAO** | **GAP** |
| Orchestration (2) | planner, task-orchestrator | **NAO** | **GAP** |
| System (3) | model-router, cost-monitor, skill-creator | **NAO** | **GAP** |

**Veredicto: ~15% — Deployer gera 6 skills basicas de infraestrutura. Stack tem 32 skills organizadas em 6 categorias.**

**Nota:** Muitas skills do stack sao **arquivos README/markdown** que definem padroes e guidelines, nao codigo executavel. O deployer poderia copiar/referenciar estas skills ao inves de gerá-las.

---

### 3.7 MCP Config

**Referencia:** `vps/mcps/mcp-config.json.template`

| Aspecto | Stack tem | Deployer gera | Status |
|---------|-----------|---------------|--------|
| mcp-config.json | Brave Search, Filesystem, Memory | **NAO** | **GAP** |

**Veredicto: 0%**

---

### 3.8 Bridge + Hooks

**Referencia:** `local/bridge/bridge.js` + `local/hooks/session-start.sh`

| Aspecto | Stack tem | Deployer gera | Status |
|---------|-----------|---------------|--------|
| bridge.js (200 linhas) | Discovery, health, validate, audit | `13-bridge.sh` gera service index (nao bridge completo) | PARCIAL |
| session-start.sh | Hook para Claude Code | `13-bridge.sh` configura via settings.json | OK |

**Veredicto: ~50%**

---

### 3.9 Testes de Validacao

**Referencia:** `tests/` (4 scripts)

| Script | Stack tem | Deployer tem | Status |
|--------|-----------|-------------|--------|
| test-gateway.sh | Sim | `06-validacao-gw.sh` + `14-validacao-final.sh` | OK |
| test-local.sh | Sim | Nenhum | **GAP** |
| test-mcps.sh | Sim | Nenhum | **GAP** |
| test-skills.sh | Sim | Health check em `09-skills.sh` | PARCIAL |

**Veredicto: ~40%**

---

### 3.10 Setup Wizard + Install Scripts

**Referencia:** `setup.sh` + `vps/install.sh` + `local/install.sh`

| Aspecto | Stack tem | Deployer tem | Status |
|---------|-----------|-------------|--------|
| Setup wizard interativo | Sim (coleta tudo, gera .env, processa templates) | Deployer faz por ferramenta separada | DIFERENTE |
| VPS install.sh | Cria user, instala CLI, copia configs | `setup.sh` + ferramentas | PARCIAL |
| Local install.sh | Instala CLI local, bridge, hooks, testa VPS | **NAO** | **GAP** |

**Veredicto: ~50% — Abordagem diferente (modular vs wizard), mas falta install local**

---

## 4. Inventario de Gaps Consolidado

### CRITICOS (bloqueiam produto funcional)

#### GAP-C1: Sem geracao de `aiosbot.json`
- **O que falta:** Config completa do gateway (models, agents, tools, hooks, channels, auth)
- **Impacto:** Gateway nao tem configuracao — modelos, aliases, workspace, memory, compaction, channels nao funcionam
- **Ferramentas afetadas:** Nenhuma ferramenta gera este arquivo

#### GAP-C2: Sem geracao de `node.json`
- **O que falta:** Registry do no (UUID, hostname, gateway endpoint)
- **Impacto:** Node nao registrado na rede, nao pode ser descoberto
- **Ferramentas afetadas:** Nenhuma

#### GAP-C3: Sem workspace files (SOUL, AGENTS, IDENTITY, USER)
- **O que falta:** Personalidade do agente, guia do workspace, identidade, contexto do usuario
- **Impacto:** Agente sem personalidade definida, sem bootstrap flow, sem memory template
- **Ferramentas afetadas:** `07-whitelabel.sh` coleta nome/icon mas nao gera estes arquivos

---

### IMPORTANTES (produto funcional mas incompleto)

#### GAP-I1: LLM Router incompleto
- **O que falta:** Keywords com weights, fallback strategy detalhada, skill mapping granular, metrics
- **Deployer gera:** Versao simplificada (tiers + API keys)
- **Stack tem:** 167 linhas com 4 tiers, 12+ skill mappings, keyword weights (0.3→0.9), fallback com tier escalation

#### GAP-I2: Skills limitadas (6 vs 32)
- **O que falta:** 26 skills (memory, dev, superpowers, orchestration, system)
- **Deployer gera:** 6 skills de infraestrutura
- **Nota:** Muitas skills do stack sao guidelines/patterns (README), nao codigo. Podem ser copiadas.

#### GAP-I3: .env incompleto
- **O que falta:** Consolidacao de todas as variaveis em .env unificado (Identity, Security, Advanced)
- **Deployer faz:** Cada ferramenta salva em `dados_vps/` separados, nao consolida

#### GAP-I4: MCP Config ausente
- **O que falta:** `mcp-config.json` com Brave Search, Filesystem, Memory

---

### MENORES (nice-to-have)

#### GAP-M1: Sem install local (`local/install.sh`)
- **O que falta:** Script de instalacao para desktop (CLI, bridge, hooks, teste VPS)
- **Impacto:** Usuario configura lado local manualmente

#### GAP-M2: Testes de validacao incompletos
- **O que falta:** `test-local.sh`, `test-mcps.sh`
- **Deployer tem:** Validacao de gateway e health checks

#### GAP-M3: BOOTSTRAP.md + MEMORY.md template
- **O que falta:** First-run guide e template de memoria
- **Impacto:** Baixo — usuario pode criar manualmente

---

## 5. Ferramentas Extras (Deployer > Stack)

O deployer tem capacidades que o stack de referencia **nao** tem:

| Ferramenta | Descricao | Valor |
|------------|-----------|-------|
| `02-postgres.sh` | PostgreSQL 16 + pgvector como servico dedicado | Alto |
| `03-evolution.sh` | Deploy completo Evolution API + Redis + multi-instance WhatsApp | Alto |
| `10-elicitation.sh` | Skill de entrevistas estruturadas com LLM extraction | Medio |
| `11-elicitation-schema.sh` | Migrations + seeds Supabase para elicitation | Medio |
| `12-seguranca.sh` | Docker sandbox + journald + logrotate (3 layers) | Alto |
| Error handling (Story 6.1) | Trap handlers, rollback, `set -euo pipefail` em todas ferramentas | Alto |

Estas sao diferenciais positivos do deployer.

---

## 6. Mapeamento Deployer ↔ Guide ↔ Stack

| Deployer Ferramenta | Guide Fase | Stack Equivalente | Conformidade |
|---------------------|-----------|-------------------|-------------|
| `setup.sh` | Fase 2 (parcial) | `vps/install.sh` (parcial) | OK |
| `01-base.sh` | Fase 2 (Docker Swarm) | `docker-compose.yml` (alternativo) | OK |
| `02-postgres.sh` | — | — (extra) | EXTRA |
| `03-evolution.sh` | Fase 9 (WhatsApp) | `channels.whatsapp` em aiosbot.json | PARCIAL |
| `04-tailscale.sh` | Fase 2 (Tailscale) | `gateway.tailscale` em aiosbot.json | OK |
| `05-openclaw.sh` | Fase 1 + 2 | `vps/install.sh` | OK |
| `06-validacao-gw.sh` | Fase 10 (parcial) | `tests/test-gateway.sh` | OK |
| `07-whitelabel.sh` | Fase 3 | `setup.sh` + `workspace/` + `IDENTITY.md` | **PARCIAL** |
| `08-llm-router.sh` | Fase 4 | `vps/config/llm-router-config.yaml` | **PARCIAL** |
| `09-skills.sh` | Fase 5 | `vps/skills/` (6 de 32) | **PARCIAL** |
| `10-elicitation.sh` | — | — (extra) | EXTRA |
| `11-elicitation-schema.sh` | — | — (extra) | EXTRA |
| `12-seguranca.sh` | Fase 6 | `tools.shell.denyPatterns` em aiosbot.json | OK+ |
| `13-bridge.sh` | Fase 7 | `local/bridge/` + `local/hooks/` | PARCIAL |
| `14-validacao-final.sh` | Fase 10 | `tests/` (4 scripts) | OK |
| — | — | `vps/config/aiosbot.json.template` | **AUSENTE** |
| — | — | `vps/config/node.json.template` | **AUSENTE** |
| — | — | `vps/workspace/SOUL.md` | **AUSENTE** |
| — | — | `vps/workspace/AGENTS.md` | **AUSENTE** |
| — | — | `vps/mcps/mcp-config.json.template` | **AUSENTE** |
| — | — | `local/install.sh` | **AUSENTE** |
| — | — | `.env` consolidado | **AUSENTE** |

---

## 7. Veredicto Final

### Score por Dimensao

| Dimensao | Score | Justificativa |
|----------|-------|---------------|
| Infraestrutura (Docker, Traefik, Tailscale, systemd) | **9/10** | Excelente — SetupOrion pattern, error handling, rollback |
| Servicos (Postgres, Evolution, Security) | **9/10** | Excelente — extras alem do guide |
| Config do Agente (aiosbot.json, node.json, workspace) | **1/10** | Critico — nenhum artefato de config gerado |
| LLM Router (config completa) | **4/10** | Parcial — tiers basicos sem keywords/fallback/metrics |
| Skills (32 do stack) | **2/10** | 6 de 32 skills |
| Ambiente Local (install, bridge, hooks) | **5/10** | Hooks OK, bridge parcial, sem install local |
| Testes/Validacao | **7/10** | Gateway e E2E bons, faltam local e MCPs |

### Decisao: **FAIL**

O deployer automatiza com excelencia a camada de **infraestrutura** mas **nao produz o produto final esperado**. O stack de referencia define um agente completo com gateway config, personalidade, 32 skills, MCP, e testes. O deployer gera apenas a infraestrutura onde esse agente rodaria, sem configurar o agente em si.

### Analogia

O deployer constroi a **casa** (Docker Swarm, Traefik, Portainer, Tailscale, Postgres) mas nao coloca os **moveis** (aiosbot.json, workspace files, skills completas, MCP config).

### Acoes Recomendadas (priorizadas)

1. **[CRITICO]** Criar ferramenta que gera `aiosbot.json` a partir dos dados coletados pelas ferramentas existentes (GAP-C1)
2. **[CRITICO]** Criar ferramenta que gera `node.json` com UUID e hostname (GAP-C2)
3. **[CRITICO]** Criar ferramenta que gera workspace files (SOUL.md, AGENTS.md, IDENTITY.md, USER.md) a partir dos dados do whitelabel (GAP-C3)
4. **[IMPORTANTE]** Expandir `08-llm-router.sh` para gerar config completa com keywords, fallback, metrics (GAP-I1)
5. **[IMPORTANTE]** Expandir skills para incluir categorias memory, dev, superpowers, orchestration, system (GAP-I2)
6. **[IMPORTANTE]** Consolidar variaveis em `.env` unificado (GAP-I3)
7. **[IMPORTANTE]** Gerar `mcp-config.json` (GAP-I4)
8. **[MENOR]** Criar `local/install.sh` para setup desktop (GAP-M1)
9. **[MENOR]** Adicionar testes local e MCPs (GAP-M2)

---

*— Quinn, guardiao da qualidade + Morgan, planejando o futuro*
