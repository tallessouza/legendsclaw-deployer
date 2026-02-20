# Ferramenta Quality Gate

Checklist obrigatório para TODA ferramenta_xxx() gerada.
VETO se qualquer item CRITICAL falhar.

## 8-Step Lifecycle (CRITICAL — todos obrigatórios)

- [ ] **Step 1: Gate de Recursos** — `recursos vCPU RAM` presente
- [ ] **Step 2: Carregar Estado** — `dados` chamado
- [ ] **Step 3: Loop Confirmado** — `while true; read; conferindo_as_info; Y/N`
- [ ] **Step 4: Dependências** — cascade automático se app tem deps
- [ ] **Step 5: Gerar YAML** — heredoc com variáveis bash
- [ ] **Step 6: Deploy** — `STACK_NAME="xxx"; stack_editavel` (Portainer API)
- [ ] **Step 7: Verificar** — `pull` + `wait_stack` com serviços
- [ ] **Step 8: Finalizar** — `dados_*` + credenciais + mensagem

## YAML Quality (CRITICAL)

- [ ] Traefik labels presentes (routers, entrypoints, certresolver, port)
- [ ] Volumes com `external: true`
- [ ] Overlay network `$nome_rede_interna` com `external: true`
- [ ] Resource limits (`cpus` + `memory`) em todo serviço
- [ ] Redis embutido se app precisa de cache (não compartilhado)
- [ ] `placement.constraints: node.role == manager`

## Input Collection (CRITICAL)

- [ ] Inputs numerados (Passo 1/N, 2/N...)
- [ ] `conferindo_as_info` mostra TODOS os inputs antes de confirmar
- [ ] Loop confirmado: Y → break, N → restart
- [ ] Senhas passam por `validar_senha()` se coletadas

## Resilience (HIGH)

- [ ] Retry em operações de rede (auth, pull, API calls)
- [ ] `verificar_stack` antes de deploy (evita duplicata)
- [ ] `verificar_docker_e_portainer_traefik` como pré-condição
- [ ] Rate limit handling em `pull` (docker login)

## State Management (HIGH)

- [ ] Credenciais salvas em `~/dados_vps/dados_{app}`
- [ ] Formato plaintext: `Chave: valor`
- [ ] YAML gerado salvo em `~/{app}.yaml`
- [ ] Credenciais de deps lidas do YAML (fonte de verdade)

## Script Quality (MEDIUM)

- [ ] shellcheck sem errors
- [ ] bash -n sem errors
- [ ] Variáveis entre aspas (`"$var"` não `$var`)
- [ ] Nomes de stack únicos (sem conflito com outras apps)
- [ ] Portas únicas (sem conflito)

## Scoring

| Nível | Critério | Score |
|-------|----------|-------|
| PASS | Todos CRITICAL + HIGH OK | 10/10 |
| PASS com warnings | Todos CRITICAL OK, HIGH parcial | 7/10 |
| FAIL | Qualquer CRITICAL faltando | VETO |
