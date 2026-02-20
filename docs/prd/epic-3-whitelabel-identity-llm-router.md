# Epic 3: Whitelabel Identity + LLM Router

**Goal:** Identidade customizada, persona configurada, LLM Router 4-tier operacional. Agente responde com identidade própria e custo otimizado.

## Referência Obrigatória

> **ANTES de executar qualquer story deste epic**, o agente executor DEVE carregar o arquivo de referência abaixo para contexto de patterns, estrutura e convenções do deployer:
>
> **`docs/referencia/orion-scripts/SetupOrion.sh`** — Script original OrionDesign v2.8.0 (~44k linhas). Contém os patterns comprovados de: feedback visual (N/M - OK/FAIL/SKIP), gate de recursos, loop confirmado de inputs, deploy via Docker/Portainer API, wait com polling, retry em tudo, hints contextuais, e estado em plaintext (`~/dados_vps/`).
>
> **Como carregar:** Devido ao tamanho (1.4MB), carregar por seções relevantes usando offset/limit ou grep por funções específicas conforme a story sendo implementada.
>
> **Referência complementar:** `docs/referencia/orion-script-racional.md` — Análise dos patterns do SetupOrion e decisões de quais replicar vs. melhorar.

## Story 3.1: Ferramenta Whitelabel — Criar Identidade do Agente

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

## Story 3.2: Ferramenta LLM Router — Configurar Tiers e API Keys

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
