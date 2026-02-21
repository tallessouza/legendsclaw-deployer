# Epic 8 — Deployer Automation & E2E Testing

> **Autor:** Morgan (@pm) | **Data:** 2026-02-21
> **Origem:** Backlog Review do @po (Pax) + Plano tecnico aprovado
> **Referencia:** `deployer/` (15 ferramentas, pattern SetupOrion v2.8.0)
> **Status:** Draft

---

## Epic Goal

Adicionar modo automatizado ao deployer, permitindo executar todas as 15 ferramentas sem intervencao humana via arquivo de configuracao. Isso viabiliza testes E2E reproduziveis, validacao de regressao, e deploy automatizado em VMs novas.

## Epic Description

### Existing System Context

- **Deployer atual:** 15 ferramentas bash interativas, ~62 prompts `read -rp` distribuidos
- **Technology stack:** Bash 5+, Docker Swarm, Portainer API, BATS-core (23 test files)
- **Libs:** ui.sh, logger.sh, common.sh, deploy.sh, hints.sh (ja robustas)
- **Problema:** Cada execucao exige ~80 inputs manuais, impossibilitando testes automatizados e deploy repetivel

### Enhancement Details

- **O que muda:** Adicionar `lib/auto.sh` com funcao `input()` que substitui `read -rp`; criar runner `deployer-auto.sh` com logging master; criar template de config
- **Integracao:** Usa mesmas libs existentes (logger.sh, ui.sh), nao quebra modo interativo
- **Abordagem:** Funcao `input("key", "prompt", var)` — em AUTO_MODE busca do config, senao faz `read` normal
- **Success criteria:** `bash deployer-auto.sh --config auto-config.env` executa todas as ferramentas e produz relatorio OK/FAIL

### Por que `input()` Helper (e nao stdin piping)

| Criterio | stdin piping | input() helper |
|----------|-------------|----------------|
| Confiabilidade | Fragil (ordem-dependente) | Alta (lookup por chave) |
| Conditional prompts | Quebra | Funciona naturalmente |
| Manutenibilidade | Pesadelo | Padrao claro |
| Backwards-compatible | Sim | Sim |
| **Veredicto** | Eliminado | **Escolhido** |

---

## Stories

### Story 8.1: Criar lib/auto.sh e auto-config.example

**Descricao:** Criar a biblioteca core do modo automatizado com funcao `input()`, `auto_confirm()` e `auto_load_config()`, mais o template de configuracao com todas as chaves documentadas.

```yaml
executor: "@dev"
quality_gate: "@architect"
quality_gate_tools: [bash_validation, nameref_compatibility, config_parsing_test]
```

**Acceptance Criteria:**
- [ ] AC1: `deployer/lib/auto.sh` criado com 3 funcoes: `auto_load_config()`, `input()`, `auto_confirm()`
- [ ] AC2: `input "key" "prompt" var` usa Bash nameref (`local -n`) para atribuir ao caller
- [ ] AC3: Em `AUTO_MODE=true`, `input()` busca valor da chave no associative array `_AUTO_VALUES`
- [ ] AC4: Em modo normal (`AUTO_MODE=false`), `input()` chama `read -rp` (comportamento identico ao atual)
- [ ] AC5: Flag `--secret` usa `read -rsp` em modo interativo e redact no log em AUTO_MODE
- [ ] AC6: Flag `--required` faz `input()` retornar exit 1 se chave ausente em AUTO_MODE
- [ ] AC7: Flag `--default=X` preenche valor default se vazio
- [ ] AC8: `auto_confirm()` retorna "s" em AUTO_MODE, chama `read -rp` em modo normal
- [ ] AC9: `auto_load_config()` parseia config file (formato `key: value`, ignora `#` e linhas vazias)
- [ ] AC10: `deployer/auto-config.example` criado com todas as ~40 chaves organizadas por ferramenta
- [ ] AC11: Testes BATS em `tests/deployer/lib-auto.bats` cobrem: load config, input lookup, auto_confirm, --secret, --required, --default, chave ausente

**Quality Gates:**
- Pre-Commit: `bash -n deployer/lib/auto.sh` (syntax check)
- Pre-PR: `npx bats tests/deployer/lib-auto.bats` passa

**Scope IN:**
- `deployer/lib/auto.sh`
- `deployer/auto-config.example`
- `tests/deployer/lib-auto.bats`

**Scope OUT:**
- Nao modificar nenhuma ferramenta ainda
- Nao criar o runner (story 8.4)

**Estimativa:** M (Medio)

---

### Story 8.2: Migrar Ferramentas 01-07 para input()

**Descricao:** Substituir todos os `read -rp` / `read -rsp` das ferramentas 01 a 07 (e common.sh) pela funcao `input()` / `auto_confirm()`, mantendo comportamento interativo identico.

```yaml
executor: "@dev"
quality_gate: "@qa"
quality_gate_tools: [regression_test, interactive_verification, bats_test]
```

**Ferramentas e read counts:**

| Ferramenta | reads | Tipo |
|-----------|-------|------|
| 01-base.sh | 7 | 5 data + 1 password + 1 confirm |
| 02-tailscale.sh | 4 | 3 data + 1 confirm |
| 03-openclaw.sh | 5 | 4 data + 1 confirm |
| 05-whitelabel.sh | 7 | 5 data + 1 confirm + 1 icon |
| 06-workspace.sh | 6 | 4 data + 1 confirm + 1 default |
| 07-llm-router.sh | 6 | 4 data + 1 confirm + 1 optional |
| lib/common.sh | 2 | recursos() prompt + cleanup rollback |
| **Total** | **37** | |

**Acceptance Criteria:**
- [ ] AC1: Cada ferramenta adiciona `source "${SCRIPT_DIR}/lib/auto.sh"` e `auto_load_config` apos log_init
- [ ] AC2: Todos os `read -rp` substituidos por `input "ferramenta.key" "prompt" var`
- [ ] AC3: Todos os `read -rsp` substituidos por `input "ferramenta.key" "prompt" var --secret`
- [ ] AC4: Todas as confirmacoes substituidas por `auto_confirm "prompt" var`
- [ ] AC5: `common.sh` — `recursos()` auto-aceita em AUTO_MODE
- [ ] AC6: `common.sh` — `cleanup_on_fail()` skip rollback prompt em AUTO_MODE (apenas loga)
- [ ] AC7: Modo interativo (`AUTO_MODE=false`) produz output **identico** ao anterior
- [ ] AC8: `auto-config.example` atualizado com chaves reais para 01-07
- [ ] AC9: BATS existentes continuam passando (`npx bats tests/deployer/01-base.bats` etc)

**Quality Gates:**
- Pre-Commit: `bash -n` em todas as ferramentas modificadas
- Pre-PR: BATS regressao + teste manual interativo de 01-base.sh

**Scope IN:**
- Ferramentas 01, 02, 03, 05, 06, 07
- `lib/common.sh` (recursos + cleanup)
- 04-validacao-gw.sh nao tem reads — skip

**Scope OUT:**
- Ferramentas 08-15 (story 8.3)
- deployer.sh / deployer-auto.sh (story 8.4)

**Estimativa:** M (Medio) — 37 substituicoes mecanicas + 2 ajustes em common.sh

---

### Story 8.3: Migrar Ferramentas 08-15 para input()

**Descricao:** Completar a migracao substituindo `read -rp` das ferramentas 08 a 15. Inclui caso especial do menu interativo de `11-seguranca.sh`.

```yaml
executor: "@dev"
quality_gate: "@qa"
quality_gate_tools: [regression_test, interactive_verification, bats_test]
```

**Ferramentas e read counts:**

| Ferramenta | reads | Notas |
|-----------|-------|-------|
| 08-skills.sh | 11 | Condicional por skill selecionada |
| 09-elicitation.sh | 1-2 | Dependencia em dados_whitelabel |
| 10-elicitation-schema.sh | 3 | Supabase URL + key + confirm |
| 11-seguranca.sh | 4+ | Menu interativo — skip em AUTO_MODE |
| 12-bridge.sh | 1 | Apenas confirmacao |
| 13-evolution.sh | 6 | Branching (VPS/local), password cascade |
| 14-gateway-config.sh | 2 | WhatsApp phone + confirm |
| 15-validacao-final.sh | 3 | WhatsApp test (optional) |
| **Total** | **~31** | |

**Acceptance Criteria:**
- [ ] AC1: Todas as ferramentas 08-15 migradas para `input()` / `auto_confirm()`
- [ ] AC2: `11-seguranca.sh` — menu interativo de customizacao (add/remove regras) skipado em AUTO_MODE com log
- [ ] AC3: `08-skills.sh` — selecao de skills via `input "skills.selecao"` (valor "all" ou lista separada por virgula)
- [ ] AC4: `13-evolution.sh` — branching condicional funciona (config fornece valores para o branch que executa)
- [ ] AC5: `15-validacao-final.sh` — teste WhatsApp skipado em AUTO_MODE quando `validacao.whatsapp_confirm: n`
- [ ] AC6: Modo interativo produz output identico ao anterior
- [ ] AC7: BATS existentes continuam passando
- [ ] AC8: `auto-config.example` completo com TODAS as chaves de todas as 15 ferramentas

**Quality Gates:**
- Pre-Commit: `bash -n` + grep para `read -rp` residual em ferramentas (deve ser zero)
- Pre-PR: BATS regressao completa + teste manual de 11-seguranca.sh e 13-evolution.sh

**Scope IN:**
- Ferramentas 08, 09, 10, 11, 12, 13, 14, 15
- Atualizar `auto-config.example`

**Scope OUT:**
- Nao alterar logica de negocio das ferramentas
- Nao criar o runner (story 8.4)

**Estimativa:** M (Medio) — 31 substituicoes + caso especial 11-seguranca

---

### Story 8.4: Criar deployer-auto.sh (Runner + Logging Master)

**Descricao:** Criar o script runner que executa ferramentas sequencialmente em AUTO_MODE, com timing, master log, relatorio final, e flags `--from`, `--to`, `--only`, `--dry-run`. Atualizar `deployer.sh` para skip ENTER em AUTO_MODE.

```yaml
executor: "@dev"
quality_gate: "@architect"
quality_gate_tools: [script_validation, flag_parsing_test, logging_verification]
```

**Acceptance Criteria:**
- [ ] AC1: `deployer/deployer-auto.sh` criado com flags: `--config PATH`, `--from NN`, `--to NN`, `--only NN,NN`, `--dry-run`
- [ ] AC2: Valida existencia do config file antes de executar
- [ ] AC3: Executa ferramentas na ordem sequencial (01→15)
- [ ] AC4: Mede tempo de execucao (segundos) de cada ferramenta
- [ ] AC5: Para na primeira falha com mensagem `--from NN` para retomar
- [ ] AC6: `--dry-run` valida config e lista ferramentas sem executar
- [ ] AC7: Master log em `~/legendsclaw-logs/auto-runner-{timestamp}.log`
- [ ] AC8: Relatorio final com tabela OK/FAIL por ferramenta + totais
- [ ] AC9: `deployer.sh` — `run_ferramenta()` skip "Pressione ENTER" em AUTO_MODE
- [ ] AC10: Exit code 0 se todos OK, 1 se algum FAIL

**Uso:**
```bash
# Run completo
bash deployer-auto.sh --config auto-config.env

# Retomar apos falha
bash deployer-auto.sh --config auto-config.env --from 07

# Apenas infra base
bash deployer-auto.sh --config auto-config.env --only 01,02,03,04

# Validar config
bash deployer-auto.sh --config auto-config.env --dry-run
```

**Quality Gates:**
- Pre-Commit: `bash -n deployer-auto.sh`
- Pre-PR: Dry-run com config de exemplo

**Scope IN:**
- `deployer/deployer-auto.sh` (novo)
- `deployer/deployer.sh` (edit: skip ENTER)

**Scope OUT:**
- Nao alterar ferramentas (ja migradas em 8.2/8.3)
- Nao implementar paralelismo (sequencial apenas)

**Estimativa:** M (Medio) — Script runner + flag parsing + logging

---

## Compatibilidade e Riscos

### Compatibilidade

- [ ] Modo interativo (`bash deployer.sh`) **inalterado** — `input()` chama `read` normalmente quando `AUTO_MODE=false`
- [ ] BATS existentes (23 files) continuam passando sem alteracao
- [ ] State files (`~/dados_vps/dados_*`) formato inalterado
- [ ] Libs compartilhadas nao mudam interface (apenas auto-check em 2 funcoes)
- [ ] Requer Bash 4.3+ (nameref) — Ubuntu 20.04+ tem Bash 5.0+

### Riscos

| Risco | Probabilidade | Impacto | Mitigacao |
|-------|--------------|---------|-----------|
| Nameref collision em `input()` | Baixa | Media | Usar `_var_ref` com underscore prefix |
| Confirmacao loops infinitos em AUTO_MODE | Baixa | Alta | `auto_confirm` sempre retorna "s", break na 1a iteracao |
| Config incompleto causa falha silenciosa | Media | Media | Flag `--required` + dry-run validation |
| Ferramentas com branching condicional | Media | Media | Config fornece valores para todos os branches possiveis |
| BATS break por nova source line | Baixa | Baixa | auto.sh verifica `AUTO_MODE` antes de qualquer acao |

### Rollback Plan

- Cada ferramenta pode reverter com `git checkout` individual
- `lib/auto.sh` pode ser removido — ferramentas voltam a usar `read` diretamente
- `deployer-auto.sh` e standalone — remover nao afeta nada

---

## Ordem de Execucao

```
Story 8.1 (lib/auto.sh) ──────────> base, pode comecar imediatamente
Story 8.2 (ferramentas 01-07) ────> depende de 8.1
Story 8.3 (ferramentas 08-15) ────> depende de 8.1 (paralelo com 8.2)
Story 8.4 (runner + logging) ─────> depende de 8.2 + 8.3
```

Wave 1: Story 8.1
Wave 2: Story 8.2 + 8.3 (paralelo)
Wave 3: Story 8.4

---

## Definition of Done

- [ ] `bash deployer-auto.sh --config auto-config.env --dry-run` executa sem erro
- [ ] `bash deployer-auto.sh --config auto-config.env` executa todas as 15 ferramentas
- [ ] Master log registra start/stop/resultado de cada ferramenta
- [ ] `bash deployer.sh` (modo interativo) funciona identico ao anterior
- [ ] BATS existentes (23 files) passam sem alteracao
- [ ] Nenhum `read -rp` residual nas ferramentas (exceto pipe reads)
- [ ] `auto-config.example` documentado com todas as chaves

---

## Handoff to Story Manager

"Por favor desenvolva stories detalhadas para este epic. Consideracoes:

- Sistema existente: Deployer bash com 15 ferramentas interativas seguindo SetupOrion v2.8.0
- Pattern de migracao: `read -rp "Prompt: " var` → `input "key" "Prompt: " var`
- Padroes a seguir: source libs, setup_trap(), step_init(), log_init(), step_ok/fail/skip
- Teste: BATS-core existente deve continuar passando
- O epic nao pode quebrar o modo interativo — backwards compatibility e mandatoria

O epic transforma o deployer de 'ferramenta interativa manual' para 'ferramenta com duplo modo (interativo + automatizado)'."

---

*— Morgan, planejando o futuro 📊*
