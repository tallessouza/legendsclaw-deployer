# Epic 12 — Alinhamento Deployer ↔ OpenClaw Architecture

> **Status:** Draft
> **Criado por:** @pm (Morgan)
> **Data:** 2026-02-25
> **Tipo:** Brownfield Enhancement
> **Estimativa:** 12 stories | L (Large) | 5 waves
> **Revisão:** v3 — auditado contra OpenClaw instalado (v2026.2.21, source em /opt/openclaw)

---

## Epic Goal

Alinhar o deployer à arquitetura **real** do OpenClaw, corrigindo os gaps onde:

1. Configs gerados pelo deployer (`aiosbot.json`) **não são consumidos** pelo gateway (`~/.openclaw/openclaw.json`)
2. Agentes não são registrados em `agents.list[]` do openclaw.json
3. Skills usam `index.js` registry quando OpenClaw espera discovery via `SKILL.md`
4. Workspace falta 2 dos 8 bootstrap files que o OpenClaw espera
5. Tailscale Serve não é configurado no openclaw.json (`gateway.tailscale.mode: "off"`)

**Após este epic:**
1. **VPS:** `14-gateway-config.sh` mergeia configs no `~/.openclaw/openclaw.json` incluindo `agents.list[]`, `skills.load.extraDirs` e `models.providers`
2. **VPS:** Agente registrado em `agents.list[]` com workspace e skills allowlist próprios
3. **Local:** `install --local` gera `~/.openclaw/openclaw.json` com `gateway.mode: "remote"` via WSS/Tailscale
4. **Skills:** Cada skill tem `SKILL.md` (discovery nativo do OpenClaw) + nosso `index.js` runtime
5. **LLM Router:** Registrado como custom provider no openclaw.json

---

## Architecture: OpenClaw Real (auditado v2026.2.21)

### Config: `~/.openclaw/openclaw.json`

Gerado pelo `pnpm openclaw onboard`. Único config que o gateway lê. Suporta:

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/auto" },
      "workspace": "/root/.openclaw/workspace"
    },
    "list": [
      {
        "id": "jim",
        "workspace": "/opt/legendsclaw/deployer/apps/jim/workspace",
        "skills": ["memory", "planner"]
      }
    ]
  },
  "models": {
    "providers": {
      "llm-router": {
        "baseUrl": "http://localhost:55119",
        "api": "openai-completions",
        "apiKey": "dummy",
        "models": [{ "id": "router-auto", "name": "Smart Router" }]
      }
    }
  },
  "skills": {
    "load": {
      "extraDirs": ["/opt/legendsclaw/deployer/apps/jim/skills"]
    },
    "entries": {
      "memory": { "enabled": true }
    }
  },
  "gateway": {
    "port": 19888,
    "mode": "local",
    "tailscale": { "mode": "serve" }
  },
  "plugins": {
    "entries": { "whatsapp": { "enabled": true } }
  }
}
```

### Workspace: 8 Bootstrap Files

OpenClaw auto-descobre e carrega na sessão do agente (`workspace.ts:308-314`):

| Arquivo | Obrigatório | Auto-criado | Deployer gera |
|---------|------------|-------------|---------------|
| AGENTS.md | Sim | Sim (template) | Sim |
| SOUL.md | Sim | Sim (template) | Sim |
| IDENTITY.md | Sim | Sim (template) | Sim |
| USER.md | Sim | Sim (template) | Sim |
| BOOTSTRAP.md | Não (após onboard) | Sim (1x) | Sim |
| MEMORY.md | Não | Não | Sim |
| **TOOLS.md** | **Sim** | **Sim (template)** | **NÃO** |
| **HEARTBEAT.md** | **Sim** | **Sim (template)** | **NÃO** |

### Skills: Discovery via SKILL.md

OpenClaw escaneia diretórios procurando `SKILL.md` em subpastas. Configurável via:
- `skills.load.extraDirs` — diretórios adicionais para scan
- `skills.entries` — config por skill (enabled, env, apiKey)
- `agents[].skills` — allowlist por agente (omitir = todas)

**IMPORTANTE:** O nosso `index.js` + `health()` é o runtime separado, não o mecanismo de discovery do OpenClaw. Ambos coexistem.

### Agent Resolution (`agent-scope.ts:178-194`)

```
Para agente com ID no agents.list[] → usa workspace configurado
Para agente default → usa agents.defaults.workspace
Para agente desconhecido → ~/.openclaw/workspace-{agentId}
```

### LLM Router Integration

O OpenClaw suporta custom providers via `models.providers`. Nosso LLM Router na porta 55119 encaixa como provider OpenAI-compatible. O gateway chama `http://localhost:55119/v1/chat/completions` e o router decide o tier internamente.

### Plugins vs MCPs

No OpenClaw, MCPs são expostos via `plugins` (não via `mcp-config.json`). O `mcp-config.json` que geramos é para o **Claude Code local** (via bridge), não para o gateway.

---

## Gap Atual (Pré-Epic)

| Artefato | Onde vai | Quem lê | Problema |
|----------|---------|---------|----------|
| `aiosbot.json` | `apps/{agent}/config/` | **Ninguém** | OpenClaw lê `openclaw.json`, não `aiosbot.json` |
| `openclaw.json` | `~/.openclaw/` | **OpenClaw gateway** | Gerado pelo wizard, nunca atualizado pelo deployer |
| `agents.list[]` | Deveria estar em openclaw.json | **OpenClaw** | **NÃO EXISTE** — agentes não registrados |
| `skills.load.extraDirs` | Deveria estar em openclaw.json | **OpenClaw** | **NÃO EXISTE** — skills não descobertas |
| TOOLS.md, HEARTBEAT.md | Workspace do agente | **OpenClaw** | **NÃO GERADOS** pelo deployer |
| `gateway.tailscale.mode` | openclaw.json | **OpenClaw** | Está `"off"` — WSS não funciona |
| `llm-router-config.yaml` | `apps/{agent}/config/` | **Nosso router** | OK — funciona |
| `mcp-config.json` | `apps/{agent}/config/` | **Claude Code (bridge)** | OK — funciona para Claude Code, não para gateway |

---

## Existing System Context

- **Deployer atual:** 16 ferramentas bash em `deployer/ferramentas/`, libs em `deployer/lib/`
- **Local setup (Epic 11):** `setup-local.sh`, `setup-local-bridge.sh`, `setup-local-aios.sh`
- **install.sh:** One-liner com modo `--local`
- **03-openclaw.sh:** Instala OpenClaw, roda `pnpm openclaw onboard` → gera `~/.openclaw/openclaw.json`
- **14-gateway-config.sh:** Gera `aiosbot.json`, `node.json`, `.env`, `mcp-config.json` — mas NÃO mergeia no `openclaw.json`
- **OpenClaw instalado:** v2026.2.21, source em `/opt/openclaw`, service em porta 19888

### Technology Stack

- Bash 4.3+ (deployer)
- Node.js 18+ (OpenClaw, bridge, LLM router)
- OpenClaw v2026.2.21 (gateway — lê `openclaw.json`, discovery via `SKILL.md`, custom providers)
- Tailscale (VPN mesh, WSS via `gateway.tailscale.mode: "serve"`)

---

## Stories (5 Waves, 12 stories)

### Wave 0: Fix Fundamental (BLOCKER — sem isso, nada funciona)

#### Story 12.0: Merge Config + Registrar Agente no openclaw.json
- **Executor:** `@dev` | **Quality Gate:** `@architect`
- **Complexidade:** M | ~120 linhas
- **Modifica:** `deployer/ferramentas/14-gateway-config.sh`
- **Depende de:** Nenhuma (corrige bug existente)

**O que faz:** Após gerar `aiosbot.json` (artefato de referência), mergeia no `~/.openclaw/openclaw.json`:
1. `models.providers` — registra LLM Router como custom provider
2. `agents.list[]` — registra agente com workspace e skills allowlist
3. `skills.load.extraDirs` — aponta para diretório de skills do agente
4. `gateway.tailscale.mode: "serve"` — habilita WSS via Tailscale
5. `gateway.auth` — auth token
6. `channels.whatsapp` — se Evolution configurado

---

### Wave 1: Core Remote Runtime (CRITICAL — desbloqueia uso local)

#### Story 12.1: Configurar OpenClaw Local em Mode Remote
- **Executor:** `@dev` | **Quality Gate:** `@architect`
- **Complexidade:** M | ~150 linhas
- **Cria:** `deployer/ferramentas/setup-local-openclaw.sh`
- **Depende de:** Story 12.0, setup-local.sh (Node.js), setup-local-bridge.sh (dados_bridge)

**O que faz:** Instala OpenClaw na máquina local e gera `~/.openclaw/openclaw.json` com `gateway.mode: "remote"` + `gateway.remote.url: "wss://..."` apontando para a VPS via Tailscale. **NÃO usa `~/.aiosbot/`** — o config vai em `~/.openclaw/openclaw.json` que é o path real do OpenClaw.

#### Story 12.2: Gerar openclaw-local.json na VPS
- **Executor:** `@dev` | **Quality Gate:** `@architect`
- **Complexidade:** S | ~50 linhas
- **Modifica:** `deployer/ferramentas/14-gateway-config.sh`
- **Depende de:** Story 12.0

**O que faz:** Gera `apps/{agent}/config/openclaw-local.json` com `gateway.mode: "remote"` + WSS URL. O `setup-local-openclaw.sh` (12.1) copia este arquivo para `~/.openclaw/openclaw.json` na máquina local.

#### Story 12.3: Session Hooks Aprimorados para Gateway Remoto
- **Executor:** `@dev` | **Quality Gate:** `@architect`
- **Complexidade:** S | ~30 linhas
- **Modifica:** `deployer/ferramentas/setup-local-bridge.sh`
- **Depende de:** Story 12.1

---

### Wave 2: Workspace e Skills (HIGH — degrada experiência sem eles)

#### Story 12.4: Popular Workspace VPS com Todos os Bootstrap Files
- **Executor:** `@dev` | **Quality Gate:** `@qa`
- **Complexidade:** S | ~40 linhas (aumentou — precisa gerar 8 files, não 6)
- **Modifica:** `deployer/ferramentas/06-workspace.sh`
- **Depende de:** Nenhuma

**O que faz:** Expande 06-workspace.sh para gerar os 8 bootstrap files que o OpenClaw espera, incluindo TOOLS.md e HEARTBEAT.md que faltam hoje.

#### Story 12.5: Popular Skills com SKILL.md Discovery
- **Executor:** `@dev` | **Quality Gate:** `@qa`
- **Complexidade:** M | ~120 linhas
- **Modifica:** `deployer/ferramentas/08-skills.sh`
- **Depende de:** Story 12.4

**O que faz:** Cada skill ganha um `SKILL.md` (para discovery nativo do OpenClaw) além do `index.js` (nosso runtime). Registra `skills.load.extraDirs` e `skills.entries` no merge do openclaw.json.

#### Story 12.6: Configuração MCP — Bridge (Claude Code) vs Gateway (Plugins)
- **Executor:** `@dev` | **Quality Gate:** `@qa`
- **Complexidade:** XS | ~15 linhas
- **Modifica:** `deployer/ferramentas/14-gateway-config.sh` (validação)
- **Depende de:** Nenhuma

**O que faz:** Clarifica que `mcp-config.json` é para o Claude Code local (bridge), não para o gateway OpenClaw. Plugins do gateway são configurados via `plugins.entries` no openclaw.json.

---

### Wave 3: Gestão Pós-Install (HIGH — operações dia-a-dia)

#### Story 12.7: Script de Validação de Configuração
- **Executor:** `@dev` | **Quality Gate:** `@qa`
- **Complexidade:** M | ~200 linhas
- **Cria:** `deployer/scripts/validate-config.sh`
- **Depende de:** Wave 1

#### Story 12.8: Scripts de Validação Geral e Update
- **Executor:** `@dev` | **Quality Gate:** `@qa`
- **Complexidade:** M | ~150 linhas
- **Cria:** `deployer/scripts/validate.sh`, `deployer/scripts/update.sh`
- **Depende de:** Story 12.7

---

### Wave 4: Qualidade e Observabilidade (MEDIUM — nice to have)

#### Story 12.9: Test Suite para Gateway e Local
- **Executor:** `@dev` | **Quality Gate:** `@qa`
- **Complexidade:** S | ~100 linhas
- **Cria:** `deployer/scripts/test-gateway.sh`, `deployer/scripts/test-local.sh`
- **Depende de:** Wave 1

#### Story 12.10: LLM Router Metrics, Cost Tracking e Skill Mapping Completo
- **Executor:** `@dev` | **Quality Gate:** `@architect`
- **Complexidade:** S | ~50 linhas
- **Modifica:** `deployer/ferramentas/07-llm-router.sh`
- **Depende de:** Story 12.5 (skills completos para mapear)

**O que faz:** Expande métricas + atualiza `generate_skill_mapping()` para mapear as 6 categorias. O `skill_mapping` é conceito do NOSSO LLM Router (não do OpenClaw). O router decide o tier internamente quando o OpenClaw faz a chamada via custom provider.

#### Story 12.11: Skill Creator (System Skill)
- **Executor:** `@dev` | **Quality Gate:** `@architect`
- **Complexidade:** S | ~80 linhas
- **Cria:** `deployer/apps/_template/skills/system/skill-creator/SKILL.md`, `index.js`
- **Depende de:** Story 12.5

---

## Grafo de Dependências

```
Wave 0 (BLOCKER):
  12.0 (merge openclaw.json + agents.list + skills.load) ─┬─> 12.1, 12.2
                                                            └─> desbloqueia tudo

Wave 1 (CRITICAL):
  12.1 (OpenClaw local mode:remote) ──> 12.3 (session hooks)
  12.2 (gerar openclaw-local.json)

Wave 2 (HIGH):
  12.4 (workspace 8 files) ──> 12.5 (skills + SKILL.md discovery)
  12.6 (MCP clarification)    (independente)

Wave 3 (HIGH):
  12.7 (validate-config) ──> 12.8 (validate + update)

Wave 4 (MEDIUM):
  12.9  (test suite)        (precisa Wave 1)
  12.5 ──> 12.10 (metrics + skill mapping)
  12.5 ──> 12.11 (skill creator)
```

---

## Compatibility Requirements

- [ ] Menu de ferramentas VPS (01-16) permanece **100% inalterado**
- [ ] State files em `~/dados_vps/` mantêm formato `key: value` existente
- [ ] Libs (ui.sh, logger.sh, etc.) reutilizadas sem breaking changes
- [ ] install.sh mantém comportamento VPS intacto
- [ ] `aiosbot.json` continua sendo gerado como artefato de referência (backward compat)
- [ ] `openclaw.json` original preservado via backup `.bak` antes de merge
- [ ] `deployer-auto.sh` (modo automático) não afetado

## Risk Mitigation

- **Primary Risk:** Merge no `openclaw.json` sobrescreve campos do `onboard` wizard
  - **Mitigation:** Deep merge com whitelist — só toca campos que o deployer gera
  - **Rollback:** Backup `.bak` antes de qualquer merge
- **Secondary Risk:** `agents.list[]` conflita com agent default
  - **Mitigation:** Se `agents.list` já existe, merge por ID (não overwrite)
- **Tertiary Risk:** OpenClaw atualiza formato do `openclaw.json`
  - **Mitigation:** Merge por campo (Node.js inline), não substituição total
- **Performance Note:** LLM Router como proxy adiciona ~50-100ms de latência por request (hop extra localhost:55119). Aceitável para o use case.
- **Rollback Plan:** Todas as novas ferramentas são **adições**. Merges no `openclaw.json` têm backup `.bak`. Story 12.0 tem auto-rollback se gateway não reinicia após merge. Git é o rollback geral para scripts.

## Definition of Done

- [ ] Todas as 12 stories completas com ACs atendidos
- [ ] VPS: `openclaw.json` tem `agents.list[]` com agente registrado
- [ ] VPS: `openclaw.json` tem `models.providers.llm-router` como custom provider
- [ ] VPS: `openclaw.json` tem `skills.load.extraDirs` apontando para skills do agente
- [ ] VPS: `gateway.tailscale.mode: "serve"` habilitado
- [ ] Local: `~/.openclaw/openclaw.json` tem `gateway.mode: "remote"` + WSS URL
- [ ] Workspace tem 8 bootstrap files (incluindo TOOLS.md e HEARTBEAT.md)
- [ ] Skills têm `SKILL.md` para discovery nativo do OpenClaw
- [ ] Session hooks verificam Tailscale + gateway WSS + bridge
- [ ] Scripts de validação e update funcionais
- [ ] Nenhuma regressão nas ferramentas VPS existentes (01-16)

---

## Verificação E2E

1. VPS: Rodar `14-gateway-config.sh` → `~/.openclaw/openclaw.json` tem `agents.list[0].id == "{agente}"`
2. VPS: `openclaw.json` tem `models.providers.llm-router.baseUrl == "http://localhost:55119"`
3. VPS: `openclaw.json` tem `skills.load.extraDirs` incluindo path de skills do agente
4. VPS: `openclaw.json` tem `gateway.tailscale.mode == "serve"`
5. VPS: `systemctl restart openclaw` → gateway usa LLM Router + reconhece agente + descobre skills via SKILL.md
6. Local: `curl | bash -s -- --local` numa máquina limpa
7. Local: `~/.openclaw/openclaw.json` tem `gateway.mode: "remote"` + WSS URL
8. Local: Abrir Claude Code → SessionStart hook mostra `Tailscale: OK | Gateway: OK`
9. Local: Rodar `deployer/scripts/validate.sh` → todos os checks passam

---

*— Morgan, planejando o futuro 📊*
