# Epic 2: OpenClaw Gateway — Deploy + Tailscale + Systemd

**Goal:** OpenClaw buildado e rodando como serviço systemd no VPS, acessível via Tailscale. Gateway responde na porta 18789.

## Referência Obrigatória

> **ANTES de executar qualquer story deste epic**, o agente executor DEVE carregar o arquivo de referência abaixo para contexto de patterns, estrutura e convenções do deployer:
>
> **`docs/referencia/orion-scripts/SetupOrion.sh`** — Script original OrionDesign v2.8.0 (~44k linhas). Contém os patterns comprovados de: feedback visual (N/M - OK/FAIL/SKIP), gate de recursos, loop confirmado de inputs, deploy via Docker/Portainer API, wait com polling, retry em tudo, hints contextuais, e estado em plaintext (`~/dados_vps/`).
>
> **Como carregar:** Devido ao tamanho (1.4MB), carregar por seções relevantes usando offset/limit ou grep por funções específicas conforme a story sendo implementada.
>
> **Referência complementar:** `docs/referencia/orion-script-racional.md` — Análise dos patterns do SetupOrion e decisões de quais replicar vs. melhorar.

## Story 2.1: Ferramenta OpenClaw — Build e Deploy no VPS

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

## Story 2.2: Validação Gateway + Tailscale End-to-End

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
