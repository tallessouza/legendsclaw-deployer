# Epic 5: WhatsApp + Security + Validation

**Goal:** Evolution API conectada ao WhatsApp, segurança 3-layer ativa, Claude Code hooks funcionais, teste end-to-end completo.

## Referência Obrigatória

> **ANTES de executar qualquer story deste epic**, o agente executor DEVE carregar o arquivo de referência abaixo para contexto de patterns, estrutura e convenções do deployer:
>
> **`docs/referencia/orion-scripts/SetupOrion.sh`** — Script original OrionDesign v2.8.0 (~44k linhas). Contém os patterns comprovados de: feedback visual (N/M - OK/FAIL/SKIP), gate de recursos, loop confirmado de inputs, deploy via Docker/Portainer API, wait com polling, retry em tudo, hints contextuais, e estado em plaintext (`~/dados_vps/`).
>
> **Como carregar:** Devido ao tamanho (1.4MB), carregar por seções relevantes usando offset/limit ou grep por funções específicas conforme a story sendo implementada.
>
> **Referência complementar:** `docs/referencia/orion-script-racional.md` — Análise dos patterns do SetupOrion e decisões de quais replicar vs. melhorar.

## Story 5.1: Ferramenta Evolution API — Deploy + WhatsApp

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

## Story 5.2: Ferramenta Segurança — 3 Layers

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

## Story 5.3: Ferramenta Bridge — Claude Code Integration

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

## Story 5.4: Validação Final — Teste End-to-End Completo

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
