# Legendsclaw Product Requirements Document (PRD)

> **Versão:** 1.0 | **Data:** 2026-02-20 | **Autor:** @pm (Morgan)
> **Deadline:** 19/03/2026 (Imersão AIOS Squads, Florianópolis)
> **Contexto:** Railway descartada — VPS Hetzner como path único

---

## Goals

- Montar uma instância funcional de OpenClaw whitelabel com WhatsApp para uso na Imersão AIOS Squads (19-20/03/2026)
- Criar pipeline de onboarding replicável: bootstrap → deploy OpenClaw → conectar WhatsApp → skill de elicitation
- Generalizar o processo num deployer automatizado (script bash inspirado no SetupOrion) para replicar em máquinas de clientes
- Eliminar dependência da Railway (falhou) — VPS Hetzner como plataforma padrão
- Custo operacional reduzido via LLM Router (de US$228/dia para fração com routing inteligente)

## Background Context

O projeto nasceu da preparação técnica para a Imersão AIOS Squads (Florianópolis, ~40 participantes, ticket R$100k). Na reunião de 19/02/2026, o time definiu que cada cliente sairá com uma VPS própria rodando OpenClaw whitelabel conectado ao WhatsApp — "o Jarvis dele". A tentativa com Railway (PaaS) não funcionou como esperado, então o caminho é VPS real (Hetzner) com Docker Swarm, seguindo o padrão já documentado no guide.md e inspirado nos patterns comprovados do SetupOrion (44k linhas bash, 80+ apps). O LLM Router do Pedro já provou reduzir custos drasticamente, e o pipeline de onboarding (environment bootstrap → deploy → elicitation) precisa estar operacional antes da imersão.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-02-20 | 1.0 | Initial PRD | @pm (Morgan) |

---

## Requirements

### Functional Requirements

- **FR1:** O sistema deve instalar o Clawdbot Gateway (OpenClaw whitelabel) numa VPS Hetzner com Docker Swarm, Traefik e Portainer
- **FR2:** O sistema deve conectar desktop à VPS via Tailscale mesh VPN
- **FR3:** O Clawdbot Gateway deve incluir Channel Router que recebe webhooks de canais (WhatsApp, Telegram, Discord) e roteia para o Session Manager
- **FR4:** O Session Manager deve manter sessões por phone/user, gerenciando contexto e estado da conversa
- **FR5:** O Tool Orchestrator deve invocar skills registradas conforme o contexto da mensagem, usando o Event Bus para comunicação assíncrona
- **FR6:** O LLM Router deve operar em 4 tiers (budget → standard → quality → premium), roteando chamadas conforme complexidade e custo
- **FR7:** A skill `elicitation` deve implementar 4 tools:
  - `start_session` — inicia sessão de elicitação com template selecionado
  - `process_message` — processa resposta do usuário, extrai dados, decide próxima pergunta
  - `get_status` — retorna progresso da elicitação (% completo, campos preenchidos)
  - `export_results` — exporta dados coletados em formato estruturado
- **FR8:** A skill `elicitation` deve persistir templates, sessions e results no Supabase
- **FR9:** A skill `elicitation` deve manter session state próprio, permitindo pausar e retomar conversas
- **FR10:** O Memory Manager deve persistir contexto em File System (`~/.clawd/memory`) e interagir com Supabase para dados estruturados
- **FR11:** Skills existentes devem ser configuráveis por instância: `supabase-query`, `clickup-ops`, `n8n-trigger`, `group-modes`
- **FR12:** O sistema deve integrar com Claude Code via Bridge.js (auto-discovery) e Hooks
- **FR13:** O deployer deve automatizar o processo completo via script bash interativo (estilo SetupOrion)
- **FR14:** O deployer deve salvar estado e credenciais em plaintext (`~/dados_vps/dados_*`)
- **FR15:** O deployer deve exibir exemplos e dicas contextuais durante cada passo da coleta de inputs (ex: "Digite o domínio do Portainer. Exemplo: painel.seudominio.com")
- **FR16:** O deployer deve indicar onde buscar cada informação solicitada (ex: "Encontre sua API Key em: https://openrouter.ai/keys → Settings → API Keys")
- **FR17:** O deployer deve salvar logs de instalação em `~/legendsclaw-logs/` com um arquivo por execução (timestamp), permitindo debug pós-instalação
- **FR18:** O deployer deve exibir feedback visual por passo (N/M - [ OK ] ou [ FAIL ]) com mensagens de erro claras e sugestões de correção
- **FR19:** O desenvolvimento do deployer deve ser incremental, seguindo o guide.md fase a fase, garantindo cobertura completa dos patterns do SetupOrion (gate de recursos, loop confirmado, dependência cascata, deploy via Portainer API, wait com polling, retry em tudo)
- **FR20:** O deployer deve fornecer hints inteligentes e contextuais incluindo: tipo de registro DNS (A, CNAME), portas a liberar no firewall, configurações de provider, valores esperados de resposta, e pré-requisitos por passo

### Non-Functional Requirements

- **NFR1:** VPS mínima: 2 vCPU, 4GB RAM (Hetzner CX21). Gate de recursos deve verificar antes de cada deploy
- **NFR2:** HTTPS automático em todos os serviços via Traefik + Let's Encrypt
- **NFR3:** Tempo de setup completo por cliente ≤ 2 horas
- **NFR4:** Custo mensal por instância ≤ US$20 (VPS + LLM routing otimizado)
- **NFR5:** Segurança em 3 layers: command blocklist (app), Docker sandbox (container), logging/audit (sistema)
- **NFR6:** Compatibilidade: Windows (WSL2), Mac, Linux (desktop); Ubuntu 22.04 (VPS)
- **NFR7:** Deployer executável via `curl | bash` sem dependências prévias além de acesso root
- **NFR8:** Operacional antes de 19/03/2026 (Imersão AIOS Squads)
- **NFR9:** Cada fase do deployer deve ser testável isoladamente antes de avançar

---

## Technical Assumptions

### Repository Structure: Monorepo

O projeto Legendsclaw é um monorepo único contendo: instância whitelabel (`apps/`), deployer (`deployer/`), infraestrutura (`infrastructure/`), e documentação (`docs/`). Já bootstrapped com AIOS-Core.

### Service Architecture: Docker Swarm Single-Node

Seguindo o pattern do SetupOrion — todos os serviços rodam como stacks no Docker Swarm em um único nó manager. Deploy via Portainer API (não CLI direto) para permitir edição posterior pelo GUI. Overlay network compartilhada entre todos os containers.

### Stack Técnica

| Camada | Tecnologia | Justificativa |
|--------|------------|---------------|
| VPS | Hetzner CX21+ (Ubuntu 22.04) | Custo-benefício, API para provisionamento |
| Orquestração | Docker Swarm | Pattern Orion, overlay network, Portainer nativo |
| Reverse Proxy | Traefik v3.5.3 | HTTPS automático, routing por domínio |
| Container Mgmt | Portainer CE | GUI + API de deploy (stack_editavel) |
| Gateway AI | OpenClaw (Clawdbot) | Channel Router, Session Manager, Tool Orchestrator |
| WhatsApp | Evolution API | Conector WhatsApp + Redis embutido |
| LLM Routing | LLM Router (4-tier) | budget→standard→quality→premium |
| Database | Supabase (cloud) | Templates, sessions, results da elicitation |
| Memory | File System (`~/.clawd/memory`) | Contexto persistente do agente |
| VPN | Tailscale | Mesh privado desktop↔VPS |
| Runtime | Node.js ≥ 22 + pnpm | Exigido pelo OpenClaw |
| Deployer | Bash script modular | Inspirado no SetupOrion, mas em arquivos separados |

### Testing Requirements

- Cada fase do deployer valida com health check automatizado
- Teste end-to-end manual (enviar mensagem WhatsApp → receber resposta)
- Gate de verificação por passo (pattern Orion: N/M - [ OK ])
- Logs de instalação para debug

### Additional Technical Assumptions

- Railway descartada — VPS Hetzner é o único path suportado
- Docker Hub rate limits: deployer inclui retry + `docker login` prompt (pattern Orion)
- Portainer como fonte de verdade para stacks (não CLI)
- Estado em plaintext (não JSON/YAML estruturado) para simplicidade em bash
- O guide.md (`docs/objetivo/guide.md`) é a referência autoritativa
- O racional do Orion (`docs/referencia/orion-script-racional.md`) é o catálogo de patterns
- Desenvolvimento incremental: Fase 1 funciona antes de começar Fase 2

---

## Epic List

| Epic | Título | Goal |
|------|--------|------|
| 1 | Base Infrastructure | Traefik + Portainer + Docker Swarm + Tailscale |
| 2 | OpenClaw Gateway | Deploy + systemd + validação Tailscale |
| 3 | Whitelabel Identity + LLM Router | Persona + 4-tier routing |
| 4 | Skills Layer + Elicitation | Skills existentes + skill elicitation completa |
| 5 | WhatsApp + Security + Validation | Evolution API + 3 layers segurança + teste E2E |

### Mapeamento guide.md → Epics

| Fase Guide | Epic |
|------------|------|
| Fase 1-2 (OpenClaw + VPS + Tailscale) | Epic 1 + 2 |
| Fase 3 (Identidade whitelabel) | Epic 3 |
| Fase 4 (LLM Router) | Epic 3 |
| Fase 5 (Skills AIOS) | Epic 4 |
| Fase 6 (Segurança) | Epic 5 |
| Fase 7 (Claude Code integration) | Epic 5 |
| Fase 8 (N8N — opcional) | Eliminado (desnecessário para MVP) |
| Fase 9 (WhatsApp) | Epic 5 |
| Fase 10 (Validação) | Epic 5 |

---

## Epic 1: Base Infrastructure — Traefik + Portainer + Docker Swarm

**Goal:** Provisionar VPS Hetzner com Docker Swarm, Traefik (reverse proxy + HTTPS) e Portainer (gerenciamento). Criar o bootstrap do deployer com feedback visual, hints inteligentes, e a primeira ferramenta funcional.

### Story 1.1: Bootstrap do Deployer — Preparação de Ambiente

> Como operador,
> quero executar um script que prepara a VPS do zero,
> para que todas as dependências estejam instaladas antes de qualquer deploy.

**Acceptance Criteria:**
1. Script executável via `bash <(curl -sSL ...)` em Ubuntu 22.04
2. Verifica e instala: Docker, jq, apache2-utils, git, python3, Node.js ≥22, pnpm
3. Cada passo exibe feedback `N/15 - [ OK ] - Descrição` ou `[ FAIL ] - Mensagem de erro`
4. Logs salvos em `~/legendsclaw-logs/bootstrap-{timestamp}.log`
5. Verifica se é root, se OS é compatível (soft gate — avisa mas não bloqueia)
6. Cria estrutura `~/dados_vps/` para estado futuro
7. Se dependência já instalada, pula com `[ SKIP ]`

### Story 1.2: Ferramenta Traefik + Portainer + Docker Swarm

> Como operador,
> quero instalar a base (Swarm + Traefik + Portainer) via deployer interativo,
> para ter a fundação de infraestrutura funcionando com HTTPS automático.

**Acceptance Criteria:**
1. Gate de recursos: verifica 1 vCPU, 1GB RAM mínimo
2. Coleta de inputs com loop confirmado: domínio Portainer, email SSL, user/senha Portainer, nome servidor, nome rede overlay
3. Hints de firewall com tabela de portas (22/TCP SSH, 80/TCP HTTP, 443/TCP HTTPS, 9443/TCP Portainer, 2377/TCP Swarm, 7946/TCP+UDP Swarm nodes, 4789/UDP overlay, 41641/UDP Tailscale)
4. Hints de DNS com tabela de registros tipo A
5. Inicializa Docker Swarm (retry 3x)
6. Cria overlay network
7. Gera `~/traefik.yaml` (Traefik v3.5.3 + Let's Encrypt)
8. Gera `~/portainer.yaml` (Agent + CE + Traefik labels)
9. Deploy via `docker stack deploy` (primeiro deploy, Portainer ainda não existe)
10. Wait com polling: Traefik → Portainer
11. Cria conta admin no Portainer via API (retry 4x)
12. Salva credenciais em `~/dados_vps/dados_portainer`
13. Logs salvos em `~/legendsclaw-logs/base-{timestamp}.log`

### Story 1.3: Ferramenta Tailscale — VPN Mesh

> Como operador,
> quero conectar minha VPS ao Tailscale mesh,
> para acessar o gateway de forma segura sem expor portas.

**Acceptance Criteria:**
1. Instala Tailscale via script oficial
2. Coleta hostname Tailscale
3. Autentica e exibe link de auth
4. Hints de setup local (Windows/Mac/WSL2)
5. Opcionalmente habilita Tailscale Funnel
6. Salva em `~/dados_vps/dados_tailscale`
7. Verifica conectividade
8. Logs salvos em `~/legendsclaw-logs/tailscale-{timestamp}.log`

---

## Epic 2: OpenClaw Gateway — Deploy + Tailscale + Systemd

**Goal:** OpenClaw buildado e rodando como serviço systemd no VPS, acessível via Tailscale. Gateway responde na porta 18789.

### Story 2.1: Ferramenta OpenClaw — Build e Deploy no VPS

> Como operador,
> quero instalar o OpenClaw Gateway no VPS via deployer,
> para ter o gateway AI rodando como serviço persistente.

**Acceptance Criteria:**
1. Gate de recursos: 2 vCPU, 4GB RAM
2. Verifica dependência: Traefik + Portainer
3. Coleta: domínio gateway, porta, repositório OpenClaw
4. Hints de DNS (registro A)
5. Clona repo em `/opt/openclaw`
6. Build: `pnpm install` → `pnpm ui:build` → `pnpm build` com feedback por passo
7. Onboard: `pnpm openclaw onboard --install-daemon`
8. Gera systemd unit (`/etc/systemd/system/openclaw.service`)
9. Enable + start serviço
10. Health check com retry 5x
11. Salva em `~/dados_vps/dados_openclaw`
12. Hints de troubleshooting (systemctl, journalctl, ss)
13. Logs salvos em `~/legendsclaw-logs/openclaw-{timestamp}.log`

### Story 2.2: Validação Gateway + Tailscale End-to-End

> Como operador,
> quero verificar que o gateway é acessível via Tailscale,
> para confirmar que a comunicação segura está funcional.

**Acceptance Criteria:**
1. Verifica Tailscale ativo
2. Exibe comandos de teste para desktop (ping, curl health, openclaw agent)
3. Executa `openclaw doctor`
4. Testa envio de mensagem local
5. Registra PASS/FAIL em `~/dados_vps/dados_openclaw`
6. Hints por tipo de erro
7. Logs salvos em `~/legendsclaw-logs/validation-gw-{timestamp}.log`

---

## Epic 3: Whitelabel Identity + LLM Router

**Goal:** Identidade customizada, persona configurada, LLM Router 4-tier operacional. Agente responde com identidade própria e custo otimizado.

### Story 3.1: Ferramenta Whitelabel — Criar Identidade do Agente

> Como operador,
> quero definir a identidade do meu agente via deployer,
> para que ele tenha nome, persona e estrutura de arquivos próprios.

**Acceptance Criteria:**
1. Coleta: nome agente, display name, ícone, persona/estilo, idioma
2. Cria estrutura `apps/{agent}/` completa (config, hooks, lib, skills)
3. Gera `config.js` com placeholders preenchidos
4. Gera definição AIOS em `.aios-core/development/agents/{agent}.md`
5. Exibe resumo para confirmação
6. Salva em `~/dados_vps/dados_whitelabel`
7. Hints de próximos passos
8. Logs salvos em `~/legendsclaw-logs/whitelabel-{timestamp}.log`

### Story 3.2: Ferramenta LLM Router — Configurar Tiers e API Keys

> Como operador,
> quero configurar o roteamento de LLMs com tiers de custo,
> para otimizar gastos mantendo qualidade.

**Acceptance Criteria:**
1. Verifica dependência: whitelabel existe
2. Coleta: OpenRouter Key, Anthropic Key, DeepSeek Key, tier padrão
3. Hints com tabela de custos por tier (budget ~$0.14/M, standard ~$0.80/M, quality ~$3/M, premium ~$15/M)
4. Gera `llm-router-config.yaml`
5. Popula `.env` no VPS
6. Testa routing com mensagem tier budget
7. Exibe resultado + custo estimado
8. Hints de debug (verificar keys, config, curl direto)
9. Salva em `~/dados_vps/dados_llm_router`
10. Logs salvos em `~/legendsclaw-logs/llm-router-{timestamp}.log`

---

## Epic 4: Skills Layer + Elicitation

**Goal:** Skills existentes configuradas, skill `elicitation` implementada com 4 tools, session state, persistência Supabase. Agente conduz entrevistas estruturadas.

### Story 4.1: Ferramenta Skills Base — Configurar Skills Existentes

> Como operador,
> quero configurar as skills existentes para minha instância,
> para que o agente tenha capacidades operacionais básicas.

**Acceptance Criteria:**
1. Exibe tabela de skills disponíveis com descrição e dependências
2. Operador seleciona skills por número
3. Para cada skill selecionada, coleta inputs com hints (URLs exatas de onde obter keys)
4. Atualiza `config.js` e `index.js`
5. Executa `npm install`
6. Testa health check por skill
7. Hints de debug por skill (curl endpoints)
8. Salva em `~/dados_vps/dados_skills`
9. Logs salvos em `~/legendsclaw-logs/skills-{timestamp}.log`

### Story 4.2: Skill Elicitation — Estrutura e Tools

> Como desenvolvedor,
> quero implementar a skill `elicitation` com 4 tools,
> para que o agente conduza entrevistas estruturadas.

**Acceptance Criteria:**
1. Cria `apps/{agent}/skills/elicitation/` com SKILL.md, index.js, tools/
2. `start_session`: recebe template_id, cria sessão no Supabase, retorna primeira pergunta
3. `process_message`: processa resposta, extrai dados via LLM, retorna próxima pergunta
4. `get_status`: retorna % completo, campos preenchidos/pendentes
5. `export_results`: exporta JSON estruturado
6. Session state persiste entre mensagens (pausar/retomar)
7. Registra em `skills/index.js`
8. Testes manuais: start → process 3 mensagens → get_status → export

### Story 4.3: Skill Elicitation — Templates e Schema Supabase

> Como operador,
> quero ter templates de entrevista no Supabase,
> para que o agente saiba quais perguntas fazer.

**Acceptance Criteria:**
1. Cria 3 tabelas: `elicitation_templates`, `elicitation_sessions`, `elicitation_results`
2. Hints de setup Supabase (SQL Editor, RLS, Service Role Key)
3. Insere template seed "onboarding-founder" (2 seções: Founder & Story + Empresa & Técnico)
4. Cada pergunta tem: text, type, required, hints
5. Migration SQL salvo em `deployer/migrations/001-elicitation-tables.sql`
6. Seed SQL salvo em `deployer/seeds/001-onboarding-founder.sql`
7. Hints de verificação no Table Editor
8. Logs salvos em `~/legendsclaw-logs/elicitation-setup-{timestamp}.log`

### Story 4.4: Skill Elicitation — Integração LLM Router e Memory

> Como agente,
> quero usar o LLM Router para extrair dados e persistir no Memory Manager,
> para interpretar respostas inteligentemente.

**Acceptance Criteria:**
1. `process_message` faz extraction call ao LLM Router tier standard
2. Se confiança < 0.7, faz follow-up de clarificação
3. Se confiança >= 0.7, salva e avança
4. `export_results` gera User.md, Company.md, TechStack.md
5. Resultados salvos no Memory Manager (`~/.clawd/memory/elicitation/`)
6. Emite evento `elicitation.session.completed` no Event Bus
7. Teste E2E: conversa completa (10-15 msgs) → verificar export

---

## Epic 5: WhatsApp + Security + Validation

**Goal:** Evolution API conectada ao WhatsApp, segurança 3-layer ativa, Claude Code hooks funcionais, teste end-to-end completo.

### Story 5.1: Ferramenta Evolution API — Deploy + WhatsApp

> Como operador,
> quero conectar um número WhatsApp ao meu agente via deployer,
> para que clientes conversem pelo WhatsApp.

**Acceptance Criteria:**
1. Gate de recursos: 1 vCPU, 1GB RAM adicional
2. Verifica dependência: OpenClaw Gateway rodando
3. Coleta: domínio Evolution, API Key, número WhatsApp
4. Hints: DNS (registro A), preparação chip eSIM, recargas periódicas
5. Gera `~/evolution.yaml` (Docker Swarm: Evolution API + Redis + Traefik labels)
6. Deploy via `stack_editavel()` (Portainer API)
7. Wait com polling
8. Hints detalhados de pareamento WhatsApp (QR Code step-by-step)
9. Configura webhook Evolution → OpenClaw Gateway
10. Salva em `~/dados_vps/dados_evolution`
11. Hints de debug (Manager URL, curl instâncias, logs Docker)
12. Logs salvos em `~/legendsclaw-logs/evolution-{timestamp}.log`

### Story 5.2: Ferramenta Segurança — 3 Layers

> Como operador,
> quero ativar as 3 camadas de segurança,
> para proteger o agente e manter audit trail.

**Acceptance Criteria:**
1. Layer 1 — Blocklist: configura `blocklist.yaml`, exibe regras, permite customização
2. Layer 2 — Sandbox: builda imagem Alpine, configura network:none, read_only, memory limit
3. Layer 3 — Logging: configura journald (6 meses) + logrotate (180 dias)
4. Hints de verificação por layer (testar bloqueio, testar isolamento, ver logs)
5. Salva em `~/dados_vps/dados_seguranca`
6. Logs salvos em `~/legendsclaw-logs/security-{timestamp}.log`

### Story 5.3: Ferramenta Bridge — Claude Code Integration

> Como operador,
> quero integrar o agente com Claude Code via Bridge.js e Hooks,
> para que o IDE detecte automaticamente o gateway.

**Acceptance Criteria:**
1. Cria `.aios-core/infrastructure/services/{agent}/index.js` com health()
2. Configura hooks em `.claude/settings.json` (SessionStart, PreToolUse, PostToolUse)
3. Testa `bridge.js status` e `bridge.js list`
4. Hints de verificação (output esperado no SessionStart)
5. Salva em `~/dados_vps/dados_bridge`
6. Logs salvos em `~/legendsclaw-logs/bridge-{timestamp}.log`

### Story 5.4: Validação Final — Teste End-to-End Completo

> Como operador,
> quero executar validação completa de todos os componentes,
> para confirmar que o sistema está pronto para a imersão.

**Acceptance Criteria:**
1. Checklist automatizado de 12 pontos (Swarm, Traefik, Portainer, OpenClaw, Tailscale, LLM Router, Skills, Evolution, WhatsApp, Security L1/L2, Hooks)
2. Cada check: [ OK ], [ FAIL ] (com causa + diagnóstico), ou [ SKIP ]
3. Teste de conversa real WhatsApp (enviar mensagem → elicitation inicia)
4. Gera relatório final com resumo de todos os componentes, URLs, credenciais
5. Salva relatório em `~/dados_vps/relatorio_instalacao.txt`
6. Logs salvos em `~/legendsclaw-logs/validation-final-{timestamp}.log`

---

## Next Steps

### Architect Prompt

> @architect — Use `docs/prd.md` para criar a arquitetura de implementação do deployer Legendsclaw. Foco em: estrutura modular do script bash (funções em arquivos separados), mapeamento 1:1 com patterns do SetupOrion, e integração com a skill elicitation. Referência: `docs/referencia/orion-script-racional.md` para patterns, `docs/architecture/legendsclaw-architecture.md` para visão geral.

---

*PRD gerado por @pm (Morgan) — Planejando o futuro 📊*
