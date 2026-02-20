# Epic 4: Skills Layer + Elicitation

**Goal:** Skills existentes configuradas, skill `elicitation` implementada com 4 tools, session state, persistência Supabase. Agente conduz entrevistas estruturadas.

## Referência Obrigatória

> **ANTES de executar qualquer story deste epic**, o agente executor DEVE carregar o arquivo de referência abaixo para contexto de patterns, estrutura e convenções do deployer:
>
> **`docs/referencia/orion-scripts/SetupOrion.sh`** — Script original OrionDesign v2.8.0 (~44k linhas). Contém os patterns comprovados de: feedback visual (N/M - OK/FAIL/SKIP), gate de recursos, loop confirmado de inputs, deploy via Docker/Portainer API, wait com polling, retry em tudo, hints contextuais, e estado em plaintext (`~/dados_vps/`).
>
> **Como carregar:** Devido ao tamanho (1.4MB), carregar por seções relevantes usando offset/limit ou grep por funções específicas conforme a story sendo implementada.
>
> **Referência complementar:** `docs/referencia/orion-script-racional.md` — Análise dos patterns do SetupOrion e decisões de quais replicar vs. melhorar.

## Story 4.1: Ferramenta Skills Base — Configurar Skills Existentes

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

## Story 4.2: Skill Elicitation — Estrutura e Tools

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

## Story 4.3: Skill Elicitation — Templates e Schema Supabase

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

## Story 4.4: Skill Elicitation — Integração LLM Router e Memory

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
