# Orion Scripter

Gera scripts bash determinísticos seguindo a metodologia SetupOrion v2.8.0.

## O que faz

Transforma requisitos de instalação em scripts bash standalone que:
- Seguem o **8-step lifecycle** do SetupOrion (Gate → Estado → Inputs → Deps → YAML → Deploy → Verify → Finalizar)
- Deployam via **Portainer API** (não CLI direto)
- Resolvem **dependências em cascade** automaticamente
- Coletam inputs com **loop confirmado** (user vê e confirma tudo)
- Mantêm estado em **plaintext** (`~/dados_vps/dados_*`)

## Filosofia

**Copiar infra base do Orion, só gerar o que é novo.**

O bootstrap, utilitários, Traefik + Portainer são COPIADOS do SetupOrion. O squad só GERA as ferramentas novas (openclaw, evolution, whatsapp).

## Comandos

| Comando | Descrição |
|---------|-----------|
| `*generate` | Gerar installer standalone completo |
| `*ferramenta {app}` | Gerar função ferramenta_xxx() |
| `*stack {app}` | Gerar YAML Docker Swarm |
| `*test` | Testar script (shellcheck + dry-run) |
| `*troubleshoot` | Diagnosticar problemas |
| `*patterns` | Mostrar patterns do Orion |
| `*help` | Mostrar comandos |

## Agents

| Agent | Papel |
|-------|-------|
| `orion-chief` | Orchestrador, valida, decide abordagem |
| `script-generator` | Gera ferramenta_xxx() seguindo 8-step lifecycle |
| `stack-architect` | Gera YAML Docker Swarm com Traefik labels |
| `troubleshooter` | Testa, debugga, valida scripts gerados |

## Primeira Missão

Gerar `SetupOpenClaw.sh` — installer standalone para:
1. **Traefik + Portainer** (base — copiado do Orion)
2. **OpenClaw Gateway** (gerado)
3. **Evolution API** (gerado/adaptado)
4. **Conectar WhatsApp** (orchestration — conecta Evolution + OpenClaw)

## Referências

- `data/orion-patterns.yaml` — Patterns extraídos do SetupOrion
- `squads/openclaw-deployer/data/orion-script-racional.md` — Racional completo (878 linhas)
- `squads/openclaw-deployer/data/orion-scripts/` — Scripts originais do Orion
