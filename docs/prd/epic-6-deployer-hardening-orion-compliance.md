# Epic 6: Deployer Hardening — Orion Compliance

**Goal:** Elevar todos os scripts do deployer ao nível de robustez e boas práticas do Orion (SetupOrion v2.8.0), corrigindo 36 issues identificadas na auditoria arquitetural.

## Referência Obrigatória

> **Relatório base:** Análise comparativa Deployer vs Orion realizada por @architect (Aria).
> Identificou 36 issues: 4 CRITICAL, 4 HIGH, 14 MEDIUM, 14 LOW.
>
> **`docs/referencia/orion-scripts/SetupOrion.sh`** — Script original OrionDesign v2.8.0 (~44k linhas). Patterns de referência.
> **`docs/referencia/orion-script-racional.md`** — Análise dos patterns e decisões.
> **`squads/orion-scripter/data/orion-patterns.yaml`** — Patterns formalizados.

## Story 6.1: Error Handling & Trap Handlers — Robustez em Todos os Scripts

> Como operador,
> quero que qualquer falha durante a instalação seja capturada com cleanup apropriado,
> para que o sistema nunca fique em estado parcial/inconsistente.

**Acceptance Criteria:**
1. Trap handler (`trap 'cleanup' EXIT INT TERM`) em TODOS os ferramentas (01-14) e setup.sh
2. Cada ferramentas deve ter função `cleanup_on_fail()` que:
   - Exibe mensagem de erro com referência ao log
   - Chama `resumo_final` mostrando steps OK/FAIL/SKIP
   - Oferece opção de rollback quando aplicável (ex: docker swarm leave)
3. deployer.sh verifica exit code de cada ferramentas e mostra feedback adequado (não silencia falhas)
4. `set -euo pipefail` no topo de TODOS os scripts que ainda não têm
5. Testes BATS atualizados: simular falha em cada ferramentas e verificar que trap é acionado
6. Logs salvos em `~/legendsclaw-logs/` com indicação clara de FAIL no nome quando aplicável

**Scripts afetados:**
- `deployer/deployer.sh` (issue #1)
- `deployer/setup.sh` (issue #3)
- `deployer/ferramentas/01-base.sh` (issue #21)
- `deployer/ferramentas/02-postgres.sh` a `14-validacao-final.sh` (issue #32 cross-cutting)

## Story 6.2: Secrets Management & Security Hardening

> Como operador,
> quero que minhas credenciais sejam protegidas adequadamente,
> para que senhas não fiquem expostas em plaintext, process list ou bash_history.

**Acceptance Criteria:**
1. `HISTFILE=/dev/null` no início de scripts que leem senhas via `read -rsp`
2. Credenciais passadas ao curl via stdin (`-d @-` ou `--data-binary @-`) em vez de argumentos CLI
3. `conferindo_as_info()` mascara campos que contêm "senha", "pass", "key", "secret" com `****`
4. `pegar_senha_postgres()` valida que a senha funciona (testa conexão) além de ler do arquivo
5. Arquivos de estado com senhas (`~/dados_vps/dados_*`) têm `chmod 400` (read-only owner)
6. Testes BATS: verificar que `ps aux` durante curl não expõe credenciais
7. Logs salvos em `~/legendsclaw-logs/` não contêm senhas em plaintext

**Scripts afetados:**
- `deployer/lib/common.sh` (issues #7, #8)
- `deployer/lib/deploy.sh` (issue #14)
- `deployer/ferramentas/02-postgres.sh` (issue #25)
- Todos os ferramentas que usam `read -rsp` (issue #34)

## Story 6.3: Health Checks, Validation & Proactive Hints

> Como operador,
> quero que cada deploy seja verificado com health check real e que falhas mostrem hints de troubleshooting,
> para que eu saiba exatamente o que corrigir quando algo falha.

**Acceptance Criteria:**
1. Health check após CADA deploy: endpoint HTTP retorna 2xx antes de reportar sucesso
2. `wait_stack()` / `wait_stack_local()` inclui health check além de verificar container running
3. YAML gerado por heredoc é validado antes de deploy (docker compose config ou yamllint)
4. `curl` calls têm `--max-time` configurado (não podem travar indefinidamente)
5. Hints chamados proativamente em TODOS os `step_fail` — cada falha mostra hint relevante
6. Validação de inputs: email (regex), domínio (formato), porta (range 1-65535)
7. `14-validacao-final.sh` persiste relatório em `~/dados_vps/relatorio_instalacao.txt`
8. Testes BATS: simular deploy com health check falhando e verificar hint é exibido

**Scripts afetados:**
- `deployer/lib/deploy.sh` (issues #15, #16)
- `deployer/lib/env-detect.sh` (issue #17)
- `deployer/lib/evolution-api.sh` (issue #19)
- `deployer/lib/hints.sh` (issue #20)
- `deployer/ferramentas/01-base.sh` (issues #22, #23)
- `deployer/ferramentas/02-postgres.sh` (issue #26)
- `deployer/ferramentas/05-openclaw.sh` (issues #28, #29)
- `deployer/ferramentas/14-validacao-final.sh` (issue #31)

---
