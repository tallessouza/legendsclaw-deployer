# Requirements

## Functional Requirements

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

## Non-Functional Requirements

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
