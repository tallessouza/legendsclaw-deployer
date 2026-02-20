# Epic 1: Base Infrastructure — Traefik + Portainer + Docker Swarm

**Goal:** Provisionar VPS Hetzner com Docker Swarm, Traefik (reverse proxy + HTTPS) e Portainer (gerenciamento). Criar o bootstrap do deployer com feedback visual, hints inteligentes, e a primeira ferramenta funcional.

## Referência Obrigatória

> **ANTES de executar qualquer story deste epic**, o agente executor DEVE carregar o arquivo de referência abaixo para contexto de patterns, estrutura e convenções do deployer:
>
> **`docs/referencia/orion-scripts/SetupOrion.sh`** — Script original OrionDesign v2.8.0 (~44k linhas). Contém os patterns comprovados de: feedback visual (N/M - OK/FAIL/SKIP), gate de recursos, loop confirmado de inputs, deploy via Docker/Portainer API, wait com polling, retry em tudo, hints contextuais, e estado em plaintext (`~/dados_vps/`).
>
> **Como carregar:** Devido ao tamanho (1.4MB), carregar por seções relevantes usando offset/limit ou grep por funções específicas conforme a story sendo implementada.
>
> **Referência complementar:** `docs/referencia/orion-script-racional.md` — Análise dos patterns do SetupOrion e decisões de quais replicar vs. melhorar.

## Story 1.1: Bootstrap do Deployer — Preparação de Ambiente

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

## Story 1.2: Ferramenta Traefik + Portainer + Docker Swarm

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

## Story 1.3: Ferramenta Tailscale — VPN Mesh

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
