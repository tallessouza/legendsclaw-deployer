# Legendsclaw — Documento de Arquitetura Completo

> **Versão:** 1.0 | **Data:** 2026-02-20 | **Autor:** @architect (Aria)
> **Tipo:** Greenfield (bootstrap completo, implementação pendente)
> **Objetivo:** OpenClaw Whitelabel + WhatsApp — instância + deployer reutilizável

---

## Índice

1. [Introdução](#1-introdução)
2. [Visão Geral do Sistema](#2-visão-geral-do-sistema)
3. [Escopo e Fases](#3-escopo-e-fases)
4. [Tech Stack](#4-tech-stack)
5. [Arquitetura de Infraestrutura](#5-arquitetura-de-infraestrutura)
6. [Arquitetura do Deployer (Script)](#6-arquitetura-do-deployer-script)
7. [Arquitetura da Instância Whitelabel](#7-arquitetura-da-instância-whitelabel)
8. [Estrutura do Projeto](#8-estrutura-do-projeto)
9. [Integrações Externas](#9-integrações-externas)
10. [Segurança (3 Layers)](#10-segurança-3-layers)
11. [Patterns de Referência (SetupOrion)](#11-patterns-de-referência-setuporion)
12. [Roadmap de Implementação](#12-roadmap-de-implementação)
13. [Variáveis de Ambiente](#13-variáveis-de-ambiente)
14. [Decisões Arquiteturais](#14-decisões-arquiteturais)
15. [Riscos e Mitigações](#15-riscos-e-mitigações)

---

## 1. Introdução

### Propósito

Legendsclaw é um projeto com dois objetivos progressivos:

1. **Fase A — Instância:** Montar uma instância funcional de OpenClaw whitelabel conectada ao WhatsApp, com skills AIOS, LLM Router, e integração com Claude Code
2. **Fase B — Deployer:** Generalizar o processo num script/ferramenta automatizada que replica a instalação para novos ambientes (inspirado no SetupOrion)

### Escopo do Documento

Documentação de arquitetura completa cobrindo:
- Infraestrutura (VPS, Docker Swarm, Tailscale)
- Aplicação (OpenClaw Gateway, Skills, LLM Router)
- Automação (Deployer script, patterns do SetupOrion)
- Integração (Claude Code Hooks, Bridge.js, WhatsApp)

### Change Log

| Data | Versão | Descrição | Autor |
|------|---------|-----------|--------|
| 2026-02-20 | 1.0 | Análise inicial e blueprint completo | @architect (Aria) |

---

## 2. Visão Geral do Sistema

### Diagrama de Alto Nível

```
┌──────────────────────────────────────────────────────────────────┐
│                        DESKTOP (LOCAL)                            │
│                                                                   │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────────┐    │
│  │ Claude Code  │◄──►│  Bridge.js   │◄──►│  AIOS Framework  │    │
│  │  (CLI)       │    │ (auto-disc.) │    │  (agents, tasks) │    │
│  └──────┬───────┘    └──────────────┘    └──────────────────┘    │
│         │ Hooks (SessionStart, PreToolUse, PostToolUse)          │
│         │                                                         │
│         │ Tailscale VPN (mesh privado)                           │
│         ▼                                                         │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    VPS HETZNER                            │    │
│  │                                                           │    │
│  │  ┌─────────┐  ┌───────────┐  ┌────────────────────┐     │    │
│  │  │ Traefik  │  │ Portainer │  │ OpenClaw Gateway   │     │    │
│  │  │ (proxy)  │  │ (mgmt)    │  │ :18789             │     │    │
│  │  └─────────┘  └───────────┘  └────────┬───────────┘     │    │
│  │                                         │                 │    │
│  │       ┌─────────────────────────────────┤                 │    │
│  │       ▼                ▼                ▼                 │    │
│  │  ┌──────────┐  ┌────────────┐  ┌──────────────┐         │    │
│  │  │ LLM      │  │ Skills     │  │ Evolution    │         │    │
│  │  │ Router   │  │ (AIOS)     │  │ API (WA)     │         │    │
│  │  └──────────┘  └────────────┘  └──────────────┘         │    │
│  │                                                           │    │
│  │  ┌──────────────────────────────────────────────┐        │    │
│  │  │ Docker Swarm (overlay network)               │        │    │
│  │  │ ├── N8N (editor + workers + webhooks)        │        │    │
│  │  │ ├── PostgreSQL / PgVector                    │        │    │
│  │  │ ├── Redis                                    │        │    │
│  │  │ └── Sandbox container (segurança)            │        │    │
│  │  └──────────────────────────────────────────────┘        │    │
│  └───────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────┐
              │  Serviços Cloud  │
              │  ├── Supabase    │
              │  ├── OpenRouter  │
              │  ├── Anthropic   │
              │  ├── DeepSeek    │
              │  └── ClickUp     │
              └──────────────────┘
```

### Fluxo de Dados Principal

```
WhatsApp User → Evolution API → OpenClaw Gateway → LLM Router → LLM Provider
                                      │
                                      ├── Skills AIOS (ClickUp, Supabase, N8N)
                                      ├── Command Safety (blocklist)
                                      └── Response → Evolution API → WhatsApp User
```

---

## 3. Escopo e Fases

### Fase A — Instância Whitelabel (10 fases do guide.md)

| # | Fase | Agente AIOS | Entregável |
|---|------|-------------|------------|
| 1 | Instalar OpenClaw Gateway | @devops | Gateway local funcional |
| 2 | VPS Hetzner + Tailscale | @devops | VPS com Tailscale mesh |
| 3 | Identidade Whitelabel | @aios-master | `apps/{agent}/` com persona |
| 4 | LLM Router | @architect + @dev | Config de tiers e routing |
| 5 | Skills AIOS | @dev | Skills customizadas ativas |
| 6 | Segurança (3 Layers) | @devops + @qa | Blocklist, sandbox, audit |
| 7 | Claude Code Integration | @dev | Hooks + Bridge funcionais |
| 8 | N8N + Portainer | @devops | Stack N8N completa (opcional) |
| 9 | Canais (WhatsApp) | @devops | Evolution API + WhatsApp |
| 10 | Validação Final | @qa | Checklist completo passando |

### Fase B — Deployer Automatizado (futuro)

| # | Fase | Descrição |
|---|------|-----------|
| B1 | Extrair patterns | Generalizar scripts da Fase A em funções reutilizáveis |
| B2 | Bootstrap script | `bash <(curl -sSL ...)` — prepara VPS do zero |
| B3 | Menu interativo | Estilo SetupOrion — opções numeradas |
| B4 | Multi-instância | Suporte `${1:+_$1}` para múltiplos gateways |
| B5 | Telemetria | Tracking de instalações |

---

## 4. Tech Stack

### Stack Base Obrigatória

| Componente | Tecnologia | Versão | Função |
|------------|------------|--------|--------|
| Runtime | Node.js | ≥ 22 | Exigido pelo OpenClaw |
| Package Manager | pnpm | latest | Package manager do OpenClaw |
| Orquestração | Docker Swarm | latest | Containers + overlay network |
| Reverse Proxy | Traefik | v3.5.3 | HTTPS automático (Let's Encrypt) |
| Container Mgmt | Portainer CE | latest | Dashboard + API de deploy |
| VPN | Tailscale | latest | Mesh privado desktop ↔ VPS |
| VPS | Hetzner | CX21+ | 2 vCPU, 4GB RAM mínimo |
| OS | Ubuntu | 22.04 | Servidor |

### Stack de Aplicação

| Componente | Tecnologia | Função |
|------------|------------|--------|
| Gateway AI | OpenClaw | Proxy LLM + agent framework |
| WhatsApp | Evolution API | Conector WhatsApp Business |
| Workflow | N8N | Automação de processos |
| Database | PostgreSQL/PgVector | Dados + vector search |
| Cache | Redis | Sessões + filas |
| AI Framework | Synkra AIOS | Orquestração de agentes |

### Stack LLM (via Router)

| Tier | Provider | Modelo | Uso |
|------|----------|--------|-----|
| budget | OpenRouter | DeepSeek Chat | Status, queries simples |
| standard | OpenRouter | Mixed | Operações gerais |
| premium | Anthropic | Claude | Decisões complexas |

---

## 5. Arquitetura de Infraestrutura

### Topologia de Rede

```
Internet
    │
    ▼
┌──────────────┐
│   Cloudflare  │  DNS + SSL (opcional)
│   (CDN/DNS)   │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────┐
│           VPS Hetzner (Helsinki)          │
│                                           │
│  ┌─────────────────────────────────────┐ │
│  │         Docker Swarm (manager)       │ │
│  │                                      │ │
│  │  Traefik (:80, :443)                │ │
│  │    ├── app.dominio.com → OpenClaw   │ │
│  │    ├── portainer.dominio.com → :9443│ │
│  │    ├── n8n.dominio.com → N8N Editor │ │
│  │    ├── webhook.dominio.com → N8N WH │ │
│  │    └── evo.dominio.com → Evolution  │ │
│  │                                      │ │
│  │  Overlay Network: legendsclaw_net    │ │
│  │    (todos os containers conectados)  │ │
│  └─────────────────────────────────────┘ │
│                                           │
│  Tailscale (:41641/udp)                  │
│    hostname: legendsclaw-gw              │
│    funnel: :18789 (HTTPS público)        │
└──────────────────────────────────────────┘
       ▲
       │ Tailscale mesh (WireGuard)
       ▼
┌──────────────────┐
│  Desktop (WSL2)   │
│  Claude Code      │
│  Bridge.js        │
│  AIOS Framework   │
└──────────────────┘
```

### Docker Swarm — Stacks Planejadas

| Stack | Serviços | YAML |
|-------|----------|------|
| traefik | traefik | `~/traefik.yaml` |
| portainer | portainer_agent, portainer | `~/portainer.yaml` |
| openclaw | openclaw_gateway | `~/openclaw.yaml` |
| evolution | evolution_api, evolution_redis | `~/evolution.yaml` |
| n8n | n8n_editor, n8n_worker, n8n_webhook, n8n_redis | `~/n8n.yaml` |
| postgres | postgres | `~/postgres.yaml` |
| sandbox | openclaw-sandbox | Gerenciado pelo OpenClaw |

### Estado no Filesystem (Pattern Orion)

```
~/dados_vps/
├── dados_vps              # Nome do servidor, rede interna
├── dados_portainer        # URL, user, senha, JWT token
├── dados_openclaw         # URL gateway, porta, API key
├── dados_evolution        # URL, API key global
├── dados_n8n              # URL editor, URL webhook
└── dados_postgres         # Senha root
```

---

## 6. Arquitetura do Deployer (Script)

### Inspiração: SetupOrion v2.8.0

O deployer segue os patterns comprovados do SetupOrion (44.726 linhas bash), adaptados para OpenClaw:

### Ciclo de Vida de Uma "Ferramenta" (adaptado)

```
┌─────────────────────────────────────────────────┐
│ 1. GATE DE RECURSOS                              │
│    recursos <vCPU> <RAM>                         │
│    → Verifica se VPS aguenta                     │
├─────────────────────────────────────────────────┤
│ 2. CARREGAR ESTADO                               │
│    dados()                                       │
│    → Lê ~/dados_vps/ (nome_servidor, rede)       │
├─────────────────────────────────────────────────┤
│ 3. COLETA DE INPUTS (loop confirmado)            │
│    while true; do                                │
│      read → domínio, email, senha, api_key       │
│      conferindo_as_info (mostra tudo)            │
│      confirmação → Y: break / N: restart         │
│    done                                          │
├─────────────────────────────────────────────────┤
│ 4. RESOLVER DEPENDÊNCIAS                         │
│    verificar_container_X()                       │
│    → Se não existe: instala automaticamente      │
├─────────────────────────────────────────────────┤
│ 5. GERAR YAML                                    │
│    cat > app.yaml << EOL (heredoc interpolado)   │
├─────────────────────────────────────────────────┤
│ 6. DEPLOY                                        │
│    stack_editavel() → via Portainer API          │
├─────────────────────────────────────────────────┤
│ 7. VERIFICAR                                     │
│    pull + wait_stack (polling 30s)               │
├─────────────────────────────────────────────────┤
│ 8. FINALIZAR                                     │
│    Salvar credenciais + exibir + créditos        │
└─────────────────────────────────────────────────┘
```

### Funções Utilitárias do Deployer

| Função | Origem | Adaptação |
|--------|--------|-----------|
| `recursos()` | Orion | Checar Node.js ≥22, pnpm, Git, Docker |
| `dados()` | Orion | Ler de `~/dados_vps/` |
| `verificar_stack()` | Orion | Mesmo pattern |
| `verificar_docker_e_portainer_traefik()` | Orion | Mesmo pattern |
| `stack_editavel()` | Orion | Deploy via Portainer API (JWT + retry 6x) |
| `wait_stack()` | Orion | Polling com feedback (aceita N serviços) |
| `pull()` | Orion | Retry infinito + rate limit handling |
| `validar_senha()` | Orion | Checar comprimento, complexidade |
| `criar_banco_postgres_da_stack()` | Orion | Criar DB dentro do container |

### Menu do Deployer (futuro)

```
╔══════════════════════════════════════════════╗
║         LEGENDSCLAW DEPLOYER v1.0            ║
╠══════════════════════════════════════════════╣
║                                              ║
║  [01] Traefik + Portainer (base)             ║
║  [02] OpenClaw Gateway                       ║
║  [03] Evolution API (WhatsApp)               ║
║  [04] N8N (Workflows)                        ║
║  [05] PostgreSQL / PgVector                  ║
║  [06] Skills AIOS                            ║
║  [07] Segurança (3 Layers)                   ║
║  [08] Validação Completa                     ║
║                                              ║
║  [P1] Página 1   [COMANDOS] Utilitários     ║
╚══════════════════════════════════════════════╝
```

---

## 7. Arquitetura da Instância Whitelabel

### Estrutura de Diretórios (apps/)

```
apps/{agent-name}/
├── config/
│   └── llm-router-config.yaml    # Tiers: budget, standard, premium
├── hooks/
│   └── session-digest/            # Memory hooks (7 arquivos)
│       ├── handler.js
│       ├── hook.yml
│       ├── index.js
│       ├── ingester.js
│       ├── scorer.js
│       ├── templates.js
│       └── types.js
├── lib/
│   ├── llm-router.js             # Core do routing LLM
│   ├── metrics-alerts.js          # Alertas de threshold
│   ├── metrics-collector.js       # Coleta de métricas
│   └── metrics-queries.js         # Queries de métricas
└── skills/
    ├── index.js                   # Registry de skills ativas
    ├── config.js                  # ⚠️ CUSTOMIZAR: URLs, IDs, keys
    ├── package.json
    ├── clickup-ops/               # Integração ClickUp
    ├── n8n-trigger/               # Trigger de workflows N8N
    ├── supabase-query/            # Queries Supabase
    ├── allos-status/              # Health check de serviços
    ├── alerts/                    # Slack/webhook alerts
    ├── memory/                    # Persistência de contexto
    └── lib/
        ├── blocklist.yaml         # Layer 1 segurança
        ├── command-safety.js      # Validação de comandos
        ├── errors.js              # Error handling
        └── logger.js              # Logging
```

### LLM Router — Tiers

```yaml
defaults:
  tier: standard
  max_retries: 3
  timeout_ms: 30000

tiers:
  budget:
    models:
      - id: deepseek/deepseek-chat
        provider: openrouter
    max_cost_per_request: 0.01
    use_for: status, health checks, queries simples

  standard:
    models:
      - id: anthropic/claude-3.5-haiku
        provider: openrouter
    max_cost_per_request: 0.05
    use_for: operações ClickUp, N8N triggers, análises

  premium:
    models:
      - id: claude-sonnet-4-6
        provider: anthropic
    max_cost_per_request: 0.20
    use_for: decisões complexas, análise de dados

skill_mapping:
  allos-status: budget
  clickup-ops: standard
  n8n-trigger: standard
  supabase-query: standard
  memory: budget
  alerts: budget
```

### Bridge.js — Auto-Discovery

```
.aios-core/infrastructure/services/
├── bridge.js                    # Core (escaneia subdiretórios)
└── {agent-name}/
    └── index.js                 # Health check do gateway
        exports: { name, description, health() }
```

### Claude Code Hooks

| Hook | Trigger | Ação |
|------|---------|------|
| SessionStart | Nova sessão | `bridge.js status` — mostra saúde dos serviços |
| PreToolUse (Bash) | Antes de Bash | `bridge.js validate-call` — valida segurança |
| PostToolUse (Bash) | Após Bash | `bridge.js log-execution` — audit trail |

---

## 8. Estrutura do Projeto

### Estado Atual (2026-02-20)

```
legendsclaw/                         STATUS
├── .aios/config.yaml                ✅ Bootstrap completo (phase 0)
├── .aios-core/                      ✅ Framework AIOS instalado
│   ├── development/agents/          ✅ 12+ agentes definidos
│   ├── development/tasks/           ✅ Tasks executáveis
│   └── infrastructure/              ✅ Scripts, schemas, tools
├── .claude/                         ✅ Rules + CLAUDE.md
├── .codex/agents/                   ✅ 15 agentes Codex
├── apps/                            ❌ VAZIO — nenhuma app criada
├── docs/
│   ├── architecture/                ✅ Este documento
│   ├── guides/                      ❌ VAZIO
│   ├── objetivo/guide.md            ✅ Guia de instalação (27KB)
│   ├── referencia/                  ✅ Orion scripts + racional
│   └── stories/                     ❌ VAZIO — nenhuma story
├── squads/squad-creator-pro/        ✅ Squad system ativo
├── src/                             ❌ VAZIO
├── tests/                           ❌ VAZIO
├── .env.example                     ✅ Template de variáveis
├── package.json                     ✅ Minimal (só @aios-fullstack/pro)
└── README.md                        ⚠️ Stub mínimo
```

### Estrutura Alvo (pós-implementação)

```
legendsclaw/
├── apps/{agent-name}/               # Instância whitelabel
│   ├── config/
│   ├── hooks/
│   ├── lib/
│   └── skills/
├── deployer/                        # Script deployer (Fase B)
│   ├── setup.sh                     # Bootstrap (curl | bash)
│   ├── deployer.sh                  # Script principal
│   ├── templates/                   # YAMLs template
│   └── lib/                         # Funções utilitárias
├── docs/
│   ├── architecture/                # Este documento
│   ├── stories/                     # Stories de desenvolvimento
│   └── referencia/                  # Referências Orion
├── infrastructure/                  # Docker configs
│   ├── docker/
│   │   ├── traefik.yaml
│   │   ├── portainer.yaml
│   │   ├── openclaw.yaml
│   │   ├── evolution.yaml
│   │   └── n8n.yaml
│   └── systemd/
│       └── openclaw.service
└── src/                             # Código customizado (se necessário)
```

---

## 9. Integrações Externas

### Mapa de Integrações

| Serviço | Tipo | Protocolo | Arquivos Chave |
|---------|------|-----------|----------------|
| OpenClaw | Gateway AI | HTTP :18789 | `openclaw.yaml`, systemd unit |
| Evolution API | WhatsApp | REST :8080 | `evolution.yaml` |
| N8N | Workflows | REST + Webhook | `n8n.yaml` |
| Supabase | Database | REST + SQL | `skills/supabase-query/` |
| ClickUp | Project Mgmt | REST | `skills/clickup-ops/` |
| OpenRouter | LLM Routing | REST | `config/llm-router-config.yaml` |
| Anthropic | LLM Fallback | REST | `.env` |
| DeepSeek | LLM Budget | REST (via OpenRouter) | `.env` |
| Tailscale | VPN Mesh | WireGuard | systemd unit |
| Portainer | Container Mgmt | REST API | `portainer.yaml` |
| Traefik | Reverse Proxy | HTTP/HTTPS | `traefik.yaml` |
| Slack | Alertas | Webhook | `skills/alerts/` |

### Dependências entre Serviços

```
Traefik + Portainer (base)
    │
    ├── PostgreSQL/PgVector
    │   ├── Chatwoot (se usado)
    │   └── N8N (queue DB)
    │
    ├── OpenClaw Gateway
    │   ├── LLM Router → OpenRouter/Anthropic/DeepSeek
    │   ├── Skills → Supabase, ClickUp, N8N
    │   └── Command Safety → Blocklist
    │
    ├── Evolution API
    │   ├── Redis (embutido)
    │   └── → OpenClaw Gateway (webhook)
    │
    └── N8N
        ├── Redis (embutido)
        ├── Workers (background jobs)
        └── Webhooks (triggers externos)
```

---

## 10. Segurança (3 Layers)

### Layer 1: Command Safety (Application Level)

```yaml
# skills/lib/blocklist.yaml
blocked_commands:
  - rm -rf
  - sudo su
  - dd if=
  - mkfs
  - iptables -F
  # + regras customizadas

validation:
  - Regex matching antes de executar qualquer comando
  - Whitelist de comandos permitidos por skill
  - Logging de tentativas bloqueadas
```

### Layer 2: Docker Sandbox (Container Level)

```dockerfile
# Dockerfile.sandbox
FROM alpine:3.19
RUN apk add --no-cache nodejs npm python3 py3-pip
RUN adduser -D sandbox
USER sandbox           # Não-root
WORKDIR /home/sandbox
```

```yaml
sandbox:
  enabled: true
  image: openclaw-sandbox
  network: none        # Sem acesso à rede
  read_only: true      # Filesystem read-only
  memory: 256m         # Limite de memória
  cpu: 0.5             # Limite de CPU
```

### Layer 3: Logging/Audit (System Level)

| Componente | Ferramenta | Retenção |
|------------|------------|----------|
| System logs | journald | 6 meses |
| App logs | logrotate | 180 dias, comprimido |
| Bridge.js | PostToolUse hook | Cada execução Bash |
| Portainer | Built-in | Histórico de deploys |

---

## 11. Patterns de Referência (SetupOrion)

### Patterns a Reutilizar no Deployer

| # | Pattern | Fonte Orion | Adaptação Legendsclaw |
|---|---------|-------------|----------------------|
| 1 | Gate de recursos | `recursos()` | Checar Node.js ≥22, pnpm, Docker |
| 2 | Estado em plaintext | `~/dados_vps/dados_*` | Mesmo pattern |
| 3 | Loop de confirmação | `while read; conferindo` | Obrigatório para coleta de dados |
| 4 | Deploy via Portainer API | `stack_editavel()` | JWT + retry 6x |
| 5 | Wait com polling | `wait_stack()` | 30s interval, feedback por serviço |
| 6 | Pull com retry | `pull()` | Rate limit handling |
| 7 | Dependência cascata | `verificar_container_X` | Se falta, instala automaticamente |
| 8 | Feedback N/M | `echo "N/15 - [ OK ]"` | Progresso visual constante |
| 9 | YAML via heredoc | `cat > app.yaml << EOL` | Variáveis interpoladas |
| 10 | Multi-instância | `${1:+_$1}` | Futuro: múltiplos gateways |

### Patterns a NÃO Replicar

| Pattern Orion | Motivo | Alternativa |
|---------------|--------|-------------|
| Script monolítico (44k linhas) | Manutenibilidade | Modular: funções em arquivos separados |
| `sudo su` sem validação | Segurança | Checar root explicitamente |
| Telemetria sem opt-out | Privacidade | Opt-in com flag `--telemetry` |
| `> /dev/null 2>&1` em tudo | Debug difícil | Log para arquivo + verbose mode |

---

## 12. Roadmap de Implementação

### Fase A — Instância Whitelabel

```
Sprint 1: Infraestrutura Base (Fases 1-2)
├── Story A.1: Instalar OpenClaw local
├── Story A.2: Provisionar VPS Hetzner
├── Story A.3: Configurar Tailscale mesh
└── Story A.4: Deploy OpenClaw no VPS + systemd

Sprint 2: Identidade + LLM (Fases 3-4)
├── Story A.5: Criar identidade whitelabel
├── Story A.6: Estrutura apps/{agent}/
├── Story A.7: Configurar LLM Router + tiers
└── Story A.8: Testar routing end-to-end

Sprint 3: Skills + Segurança (Fases 5-6)
├── Story A.9: Copiar e customizar skills
├── Story A.10: config.js com credenciais
├── Story A.11: Blocklist + command safety
├── Story A.12: Docker sandbox + logging

Sprint 4: Integração + Canais (Fases 7-9)
├── Story A.13: Bridge.js + service index
├── Story A.14: Claude Code hooks
├── Story A.15: Deploy N8N stack (opcional)
├── Story A.16: Evolution API + WhatsApp
└── Story A.17: Conectar canais

Sprint 5: Validação (Fase 10)
├── Story A.18: Checklist de verificação completa
├── Story A.19: Teste end-to-end
└── Story A.20: Documentação final
```

### Fase B — Deployer Automatizado

```
Sprint 6: Core do Deployer
├── Story B.1: Bootstrap script (setup.sh)
├── Story B.2: Funções utilitárias (lib/)
├── Story B.3: Ferramenta Traefik + Portainer
└── Story B.4: Ferramenta OpenClaw

Sprint 7: Ferramentas Restantes
├── Story B.5: Ferramenta Evolution API
├── Story B.6: Ferramenta N8N
├── Story B.7: Ferramenta Skills AIOS
└── Story B.8: Menu interativo

Sprint 8: Polimento
├── Story B.9: Validação + teste automatizado
├── Story B.10: Multi-instância
└── Story B.11: Documentação do deployer
```

---

## 13. Variáveis de Ambiente

### Obrigatórias (Fase A)

```env
# LLM Providers
OPENROUTER_API_KEY=sk-or-v1-xxx     # LLM routing principal
ANTHROPIC_API_KEY=sk-ant-xxx         # Fallback premium
DEEPSEEK_API_KEY=sk-xxx              # Tier budget

# Database
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# LLM Router
LLM_ROUTER_ENABLED=true
LLM_ROUTER_CONFIG_PATH=apps/{agent}/config/llm-router-config.yaml
LLM_ROUTER_DEFAULT_TIER=standard
```

### Opcionais

```env
# Project Management
CLICKUP_API_KEY=pk_xxx
CLICKUP_TEAM_ID=xxx

# Workflows
N8N_API_KEY=xxx
N8N_WEBHOOK_URL=https://webhook.dominio.com

# Alertas
SLACK_ALERTS_WEBHOOK_URL=https://hooks.slack.com/services/xxx

# WhatsApp
WHATSAPP_JID=5511999999999@s.whatsapp.net

# Infra
AGENT_GATEWAY_URL=http://legendsclaw-gw.tail<ID>.ts.net:18789
```

---

## 14. Decisões Arquiteturais

### ADR-001: Docker Swarm sobre Docker Compose

**Contexto:** Precisa orquestrar múltiplos containers com networking.
**Decisão:** Docker Swarm (igual ao SetupOrion).
**Motivo:**
- Overlay network para comunicação entre containers por nome
- Integração nativa com Portainer API
- `docker stack deploy` idempotente
- Scaling nativo com `replicas: N`
- Pattern comprovado pelo SetupOrion (80+ apps)

### ADR-002: Portainer API sobre CLI direto

**Contexto:** Precisa de forma de deploy que permita edição posterior.
**Decisão:** Deploy via API REST do Portainer.
**Motivo:**
- User pode editar stacks pelo GUI depois
- Versionamento de deploys automático
- Centralização de gerenciamento
- Pattern comprovado pelo SetupOrion

### ADR-003: Estado em plaintext sobre JSON/DB

**Contexto:** Deployer precisa armazenar configuração e credenciais.
**Decisão:** Arquivos plaintext em `~/dados_vps/`.
**Motivo:**
- `grep + awk` sem dependências externas
- Legível e editável com `cat`/`nano`
- Robusto (sem parsing errors)
- Pattern comprovado pelo SetupOrion

### ADR-004: Tailscale sobre VPN tradicional

**Contexto:** Desktop precisa acessar VPS de forma segura.
**Decisão:** Tailscale mesh network.
**Motivo:**
- Zero config de firewall/NAT
- WireGuard nativo (criptografia moderna)
- Funnel para HTTPS público sem Cloudflare
- Setup em 2 comandos

### ADR-005: Deployer modular sobre monolítico

**Contexto:** SetupOrion é 44k linhas num único arquivo.
**Decisão:** Deployer modular com funções em arquivos separados.
**Motivo:**
- Manutenibilidade (diff/blame por função)
- Testabilidade (testar funções individualmente)
- Reutilização (importar funções específicas)
- Legibilidade

---

## 15. Riscos e Mitigações

| # | Risco | Impacto | Probabilidade | Mitigação |
|---|-------|---------|---------------|-----------|
| 1 | OpenClaw não suporta WhatsApp nativamente | Alto | Média | Evolution API como bridge; webhook relay |
| 2 | Rate limit do Docker Hub no pull | Médio | Alta | `docker login` + retry com backoff |
| 3 | Tailscale free tier limitado | Baixo | Baixa | 100 devices grátis; upgrade se necessário |
| 4 | VPS sem recursos suficientes | Alto | Média | Gate de recursos antes de cada deploy |
| 5 | API keys expiram/invalidam | Médio | Média | Health check periódico + alertas |
| 6 | Bridge.js não detecta serviço | Médio | Baixa | Auto-discovery + fallback manual |
| 7 | Deployer script quebra mid-install | Alto | Média | Estado salvo por passo; resume capability |

---

## Apêndice A — Referências

| Documento | Localização | Descrição |
|-----------|-------------|-----------|
| Guia de Instalação | `docs/objetivo/guide.md` | 10 fases detalhadas |
| Racional Orion | `docs/referencia/orion-script-racional.md` | Análise do SetupOrion |
| SetupOrion Scripts | `docs/referencia/orion-scripts/` | Scripts originais de referência |
| AIOS Config | `.aios/config.yaml` | Config do projeto |
| Env Template | `.env.example` | Template de variáveis |

## Apêndice B — Comandos AIOS por Fase

| Fase | Agente | Comando |
|------|--------|---------|
| 1-2 | `@devops` | `*task deploy-openclaw-vps` |
| 3 | `@aios-master` | `*create agent` |
| 4 | `@architect` | `*create-backend-architecture` |
| 5 | `@dev` | `*develop` → implementar skills |
| 6 | `@devops` | `*task setup-security-layers` |
| 6 | `@qa` | `*task validate-security` |
| 7 | `@dev` | `*develop` → bridge integration |
| 8-9 | `@devops` | `*task deploy-n8n-stack` |
| 10 | `@qa` | `*execute-checklist architect-checklist` |

---

*Documento gerado por @architect (Aria) — Arquitetando o futuro 🏗️*
