# Technical Assumptions

## Repository Structure: Monorepo

O projeto Legendsclaw é um monorepo único contendo: instância whitelabel (`apps/`), deployer (`deployer/`), infraestrutura (`infrastructure/`), e documentação (`docs/`). Já bootstrapped com AIOS-Core.

## Service Architecture: Docker Swarm Single-Node

Seguindo o pattern do SetupOrion — todos os serviços rodam como stacks no Docker Swarm em um único nó manager. Deploy via Portainer API (não CLI direto) para permitir edição posterior pelo GUI. Overlay network compartilhada entre todos os containers.

## Stack Técnica

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

## Testing Requirements

- Cada fase do deployer valida com health check automatizado
- Teste end-to-end manual (enviar mensagem WhatsApp → receber resposta)
- Gate de verificação por passo (pattern Orion: N/M - [ OK ])
- Logs de instalação para debug

## Additional Technical Assumptions

- Railway descartada — VPS Hetzner é o único path suportado
- Docker Hub rate limits: deployer inclui retry + `docker login` prompt (pattern Orion)
- Portainer como fonte de verdade para stacks (não CLI)
- Estado em plaintext (não JSON/YAML estruturado) para simplicidade em bash
- O guide.md (`docs/objetivo/guide.md`) é a referência autoritativa
- O racional do Orion (`docs/referencia/orion-script-racional.md`) é o catálogo de patterns
- Desenvolvimento incremental: Fase 1 funciona antes de começar Fase 2

---
