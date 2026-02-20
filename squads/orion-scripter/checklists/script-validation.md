# Script Validation Checklist

Checklist para o script FINAL montado (todas as partes juntas).

## Estrutura do Script

- [ ] Shebang `#!/bin/bash` presente
- [ ] Header com nome, versão, créditos
- [ ] Cores definidas (amarelo, verde, branco, etc.)
- [ ] UI functions presentes (nome_xxx, instalando_msg, etc.)
- [ ] Utilitários copiados do Orion (sem modificação de lógica)
- [ ] Stack base (Traefik + Portainer) funcional
- [ ] Ferramentas novas seguem 8-step lifecycle
- [ ] Menu com while true + case

## Teste Automatizado

- [ ] `shellcheck --severity=warning` → 0 errors
- [ ] `bash -n script.sh` → exit 0
- [ ] Todas as funções declaradas são chamáveis
- [ ] Nenhuma função duplicada
- [ ] Nenhuma variável usada sem declarar

## Dry Run

- [ ] Heredocs geram YAML válido (yamllint)
- [ ] Stack names únicos entre todas as ferramentas
- [ ] Volumes não conflitam
- [ ] Portas não conflitam
- [ ] Rede overlay referenciada corretamente

## Orion Compliance

- [ ] Bootstrap segue o pattern de 15 passos
- [ ] Utilitários IDÊNTICOS ao Orion (sem otimizações)
- [ ] Deploy SEMPRE via Portainer API
- [ ] Estado SEMPRE em plaintext
- [ ] Retry em TODA operação de rede
- [ ] Loop confirmado em TODA coleta de input
