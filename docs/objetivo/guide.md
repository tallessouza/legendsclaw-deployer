# Guia de Instalação Whitelabel — OpenClaw + AIOS

> **Versão:** 1.0 | **Data:** 2026-02-14 | **Autor:** @architect (Aria)
> **Pré-requisito:** AIOS-Core instalado | **Tempo estimado:** 2-4h
> **Referência:** [OPENCLAW-ARCHITECTURE-ANALYSIS.md](./OPENCLAW-ARCHITECTURE-ANALYSIS.md)

---

## Índice

1. [Pré-Requisitos](#1-pré-requisitos)
2. [Fase 1 — Instalar OpenClaw Gateway](#2-fase-1--instalar-openclaw-gateway)
3. [Fase 2 — Configurar VPS Hetzner + Tailscale](#3-fase-2--configurar-vps-hetzner--tailscale)
4. [Fase 3 — Customizar Identidade Whitelabel](#4-fase-3--customizar-identidade-whitelabel)
5. [Fase 4 — Configurar LLM Router](#5-fase-4--configurar-llm-router)
6. [Fase 5 — Instalar Skills AIOS](#6-fase-5--instalar-skills-aios)
7. [Fase 6 — Segurança (3 Layers)](#7-fase-6--segurança-3-layers)
8. [Fase 7 — Integrar com Claude Code (Hooks + Bridge)](#8-fase-7--integrar-com-claude-code-hooks--bridge)
9. [Fase 8 — Configurar N8N + Portainer](#9-fase-8--configurar-n8n--portainer)
10. [Fase 9 — Conectar Canais](#10-fase-9--conectar-canais)
11. [Fase 10 — Validação Final](#11-fase-10--validação-final)
12. [Workflow de Agentes AIOS](#12-workflow-de-agentes-aios)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Pré-Requisitos

### Software Local
- **Node.js** ≥ 22 (exigido pelo OpenClaw)
- **pnpm** (package manager do OpenClaw)
- **Git**
- **Claude Code** CLI instalado e autenticado
- **Tailscale** client instalado no desktop
- **AIOS-Core** clonado e configurado

### Contas Necessárias
- [Hetzner Cloud](https://console.hetzner.cloud/) — VPS
- [Tailscale](https://tailscale.com/) — VPN mesh
- [OpenRouter](https://openrouter.ai/) — LLM routing
- [Anthropic](https://console.anthropic.com/) — API fallback
- [Supabase](https://supabase.com/) — Database
- [ClickUp](https://clickup.com/) — Project management (opcional)
- [Cloudflare](https://dash.cloudflare.com/) — DNS + SSL (opcional)

### API Keys para preparar
```env
# Obter ANTES de iniciar
OPENROUTER_API_KEY=
ANTHROPIC_API_KEY=
DEEPSEEK_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
CLICKUP_API_KEY=           # Se usar ClickUp
SLACK_ALERTS_WEBHOOK_URL=  # Se usar Slack alerts
```

---

## 2. Fase 1 — Instalar OpenClaw Gateway

### 2.1 Clonar e Buildar

```bash
# Clonar repositório oficial
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# Instalar dependências
pnpm install

# Buildar UI e core
pnpm ui:build
pnpm build

# Testar localmente
pnpm openclaw onboard --install-daemon
pnpm openclaw gateway --port 18789 --verbose
```

### 2.2 Verificar Instalação Local

```bash
# Verificar que o gateway está rodando
openclaw doctor

# Enviar mensagem de teste
openclaw agent --message "Olá! Teste de instalação." --thinking high
```

> **Checkpoint:** O gateway deve responder na porta 18789 localmente.

---

## 3. Fase 2 — Configurar VPS Hetzner + Tailscale

### 3.1 Criar VPS no Hetzner

1. Acessar [Hetzner Console](https://console.hetzner.cloud/)
2. Criar servidor:
   - **Localização:** Helsinki (ou mais próximo do seu público)
   - **Imagem:** Ubuntu 22.04
   - **Tipo:** CX21 ou superior (2 vCPU, 4GB RAM)
   - **SSH Key:** Adicionar sua chave pública

```bash
# Conectar via SSH
ssh root@<IP_DO_SERVIDOR>

# Atualizar sistema
apt update && apt upgrade -y

# Instalar Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Instalar pnpm
npm install -g pnpm

# Instalar ferramentas essenciais
apt install -y git docker.io docker-compose-plugin
```

### 3.2 Instalar Tailscale no VPS

```bash
# Instalar Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Autenticar (abre link no browser)
tailscale up --hostname=meu-gateway

# Habilitar Funnel para HTTPS público (opcional)
tailscale funnel 18789

# Verificar
tailscale status
```

### 3.3 Instalar Tailscale no Desktop

```powershell
# Windows — baixar de https://tailscale.com/download
# Após instalar, autenticar com a mesma conta

# Verificar conectividade
tailscale ping meu-gateway
```

### 3.4 Deploy OpenClaw no VPS

```bash
# No VPS
cd /opt
git clone https://github.com/openclaw/openclaw.git
cd openclaw

pnpm install
pnpm ui:build
pnpm build

# Configurar daemon
pnpm openclaw onboard --install-daemon

# Iniciar gateway
pnpm openclaw gateway --port 18789 --verbose
```

### 3.5 Configurar como Serviço (systemd)

```bash
cat > /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=OpenClaw Gateway
After=network.target tailscaled.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw
ExecStart=/usr/bin/node openclaw.mjs gateway --port 18789
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw
systemctl start openclaw
```

> **Checkpoint:** `tailscale ping meu-gateway` funciona do desktop e `curl http://meu-gateway.tail<ID>.ts.net:18789/health` retorna OK.

---

## 4. Fase 3 — Customizar Identidade Whitelabel

### 4.1 Definir Identidade

Escolha o nome do seu agente. Neste guia usamos `{AGENT_NAME}` como placeholder.

```bash
# Exemplos:
# AGENT_NAME=jarvis
# AGENT_NAME=atlas
# AGENT_NAME=cortana
```

### 4.2 Criar Estrutura no AIOS

No seu projeto AIOS-Core, ative o agente @aios-master ou @squad-creator:

```
@aios-master
*create agent
```

Ou manualmente crie os arquivos:

```
apps/{agent-name}/
├── config/
│   └── llm-router-config.yaml    # Copiar de apps/clawdbot/config/
├── hooks/
│   └── session-digest/            # Copiar de apps/clawdbot/hooks/
├── lib/
│   ├── llm-router.js              # Copiar de apps/clawdbot/lib/
│   ├── metrics-alerts.js
│   ├── metrics-collector.js
│   └── metrics-queries.js
└── skills/
    ├── index.js
    ├── config.js                   # ⚠️ CUSTOMIZAR
    ├── package.json
    ├── clickup-ops/
    ├── n8n-trigger/
    ├── supabase-query/
    ├── allos-status/
    ├── alerts/
    ├── memory/
    └── lib/
        ├── blocklist.yaml
        ├── command-safety.js
        └── logger.js
```

### 4.3 Customizar config.js

Editar `apps/{agent-name}/skills/config.js` — Substituir todos os valores AllFluence:

```javascript
// ⚠️ TROCAR ESTES VALORES para sua configuração

// ClickUp
CLICKUP_TEAM_ID: process.env.CLICKUP_TEAM_ID || 'SEU_TEAM_ID',

// N8N Webhooks — criar seus próprios workflows
N8N_WEBHOOK_BASE: process.env.N8N_WEBHOOK_URL || 'https://SEU-N8N.exemplo.com',
WORKFLOWS: {
  // Mapear para seus workflow IDs
  'video-analysis': 'SEU_WEBHOOK_ID_1',
  'content-pipeline': 'SEU_WEBHOOK_ID_2',
  // ...
},

// Supabase
SUPABASE_URL: process.env.SUPABASE_URL || 'https://SEU_PROJECT.supabase.co',

// AllOS Services — substituir por seus domínios
SERVICES: {
  API: process.env.API_URL || 'https://api.SEU-DOMINIO.com',
  N8N: process.env.N8N_URL || 'https://n8n.SEU-DOMINIO.com',
  WORKER: process.env.WORKER_URL || 'https://worker.SEU-DOMINIO.com',
},

// WhatsApp — seu número
WHATSAPP_JID: process.env.WHATSAPP_JID || 'SEU_NUMERO@s.whatsapp.net',

// Slack
SLACK_CHANNEL: process.env.SLACK_CHANNEL || '#seu-canal-alertas',

// Memory
MEMORY_BASE_PATH: process.env.MEMORY_PATH || `~/.${AGENT_NAME}/`,
```

### 4.4 Criar Definição do Agente AIOS

Criar `.aios-core/development/agents/{agent-name}.md`:

```markdown
# {AGENT_NAME}

## Agent Definition

```yaml
agent:
  name: {AgentDisplayName}
  id: {agent-name}
  title: AI Team Member
  icon: 🤖   # Escolha seu ícone

persona:
  role: AI Team Member & Operations Assistant
  style: Prático, eficiente, orientado a resultados
  identity: Assistente de equipe integrado ao AIOS

commands:
  - help: Mostrar comandos disponíveis
  - status: Verificar saúde dos serviços
  - clickup: Operações ClickUp (list, update, create)
  - n8n: Trigger workflows N8N
  - supabase: Queries no banco
  - chat: Conversa livre

dependencies:
  tasks:
    - {agent-name}-ops.md
  tools:
    - clickup-ops
    - n8n-trigger
    - supabase-query
    - {agent-name}-status
```
```

---

## 5. Fase 4 — Configurar LLM Router

### 5.1 Copiar e Customizar Router Config

```bash
cp apps/clawdbot/config/llm-router-config.yaml apps/{agent-name}/config/llm-router-config.yaml
```

### 5.2 Editar Tiers (opcional)

O arquivo `llm-router-config.yaml` permite ajustar:

```yaml
defaults:
  tier: standard          # Tier padrão
  max_retries: 3
  timeout_ms: 30000

tiers:
  budget:
    models:
      - id: deepseek/deepseek-chat
        provider: openrouter
        # Ajustar weight e pricing conforme necessário
    max_cost_per_request: 0.01

  # ... outros tiers

skill_mapping:
  # Mapear suas skills para tiers
  {agent-name}-status: budget
  clickup-ops: standard
  # Adicionar suas skills customizadas
```

### 5.3 Configurar .env

```env
# No .env do projeto
LLM_ROUTER_ENABLED=true
LLM_ROUTER_CONFIG_PATH=apps/{agent-name}/config/llm-router-config.yaml
LLM_ROUTER_DEFAULT_TIER=standard

OPENROUTER_API_KEY=sk-or-v1-xxxx
ANTHROPIC_API_KEY=sk-ant-xxxx
DEEPSEEK_API_KEY=sk-xxxx
```

---

## 6. Fase 5 — Instalar Skills AIOS

### 6.1 Copiar Skills Base

```bash
# Copiar todas as skills
cp -r apps/clawdbot/skills/* apps/{agent-name}/skills/

# Copiar libraries
cp -r apps/clawdbot/lib/* apps/{agent-name}/lib/

# Instalar dependências
cd apps/{agent-name}/skills
npm install
```

### 6.2 Customizar Skills (o que trocar)

| Skill | O que customizar |
|-------|-----------------|
| `clickup-ops` | Team ID, Space IDs, campos customizados |
| `n8n-trigger` | Workflow IDs, webhook URLs |
| `supabase-query` | URL, tabelas, colunas |
| `allos-status` | URLs dos serviços, endpoints de health |
| `alerts` | Webhook Slack, canal, throttle config |

### 6.3 Desabilitar Skills Não Necessárias

Em `apps/{agent-name}/skills/index.js`, comentar as skills que não usar:

```javascript
module.exports = {
  'clickup-ops': require('./clickup-ops'),
  // 'n8n-trigger': require('./n8n-trigger'),  // Desabilitado
  'supabase-query': require('./supabase-query'),
  '{agent-name}-status': require('./allos-status'),  // Renomear
  // 'group-modes': require('./group-modes'),  // Desabilitado
};
```

---

## 7. Fase 6 — Segurança (3 Layers)

### 7.1 Layer 1: Command Safety

Copiar e customizar o blocklist:

```bash
cp apps/clawdbot/skills/lib/blocklist.yaml apps/{agent-name}/skills/lib/blocklist.yaml
```

O blocklist padrão já inclui proteções críticas. Adicionar regras específicas do seu ambiente se necessário.

### 7.2 Layer 2: Docker Sandbox

No VPS, configurar o sandbox:

```bash
# Criar Dockerfile do sandbox
cat > /opt/openclaw/Dockerfile.sandbox << 'EOF'
FROM alpine:3.19
RUN apk add --no-cache nodejs npm python3 py3-pip
RUN adduser -D sandbox
USER sandbox
WORKDIR /home/sandbox
EOF

# Buildar
docker build -f Dockerfile.sandbox -t openclaw-sandbox .
```

Configurar no OpenClaw para usar o sandbox para execução de comandos:

```yaml
# Na configuração do OpenClaw
sandbox:
  enabled: true
  image: openclaw-sandbox
  network: none
  read_only: true
  memory: 256m
  cpu: 0.5
```

### 7.3 Layer 3: Logging/Audit

```bash
# Configurar journald
cat > /etc/systemd/journald.conf.d/openclaw.conf << 'EOF'
[Journal]
MaxRetentionSec=6month
MaxFileSec=1month
Compress=yes
EOF

# Configurar logrotate
cat > /etc/logrotate.d/openclaw << 'EOF'
/var/log/openclaw/*.log {
    daily
    rotate 180
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF

systemctl restart systemd-journald
```

---

## 8. Fase 7 — Integrar com Claude Code (Hooks + Bridge)

### 8.1 Configurar Bridge.js

O `bridge.js` já existe em `.aios-core/infrastructure/services/bridge.js` e funciona por auto-discovery. Ele escaneia subdiretórios em `.aios-core/infrastructure/services/` buscando `index.js`.

Para registrar seu agente como serviço:

```bash
mkdir -p .aios-core/infrastructure/services/{agent-name}
```

Criar `.aios-core/infrastructure/services/{agent-name}/index.js`:

```javascript
'use strict';

const http = require('http');

const SERVICE_URL = process.env.AGENT_GATEWAY_URL
  || 'http://meu-gateway.tail<ID>.ts.net:18789';

module.exports = {
  name: '{agent-name}',
  description: 'AI Team Member Gateway',

  async health() {
    return new Promise((resolve) => {
      const req = http.get(`${SERVICE_URL}/health`, { timeout: 5000 }, (res) => {
        resolve({
          status: res.statusCode === 200 ? 'healthy' : 'degraded',
          url: SERVICE_URL,
        });
      });
      req.on('error', () => resolve({ status: 'unhealthy', url: SERVICE_URL }));
      req.on('timeout', () => {
        req.destroy();
        resolve({ status: 'timeout', url: SERVICE_URL });
      });
    });
  },
};
```

### 8.2 Configurar Claude Code Hooks

Editar `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": "node .aios-core/infrastructure/services/bridge.js status",
        "timeout": 15000
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": "node .aios-core/infrastructure/services/bridge.js validate-call",
        "timeout": 5000
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "command": "node .aios-core/infrastructure/services/bridge.js log-execution",
        "timeout": 5000
      }
    ]
  }
}
```

### 8.3 Testar Integração

```bash
# Verificar bridge status
node .aios-core/infrastructure/services/bridge.js status

# Verificar que o serviço aparece na lista
node .aios-core/infrastructure/services/bridge.js list
```

---

## 9. Fase 8 — Configurar N8N + Portainer (Opcional)

> Esta fase é necessária apenas se você quiser replicar a stack N8N completa.

### 9.1 Instalar Portainer no VPS

```bash
docker volume create portainer_data

docker run -d \
  --name portainer \
  --restart=always \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

### 9.2 Deploy N8N Stack

Copiar os docker-compose files de `infrastructure/n8n/` para o VPS e customizar:

```bash
# No VPS
mkdir -p /opt/n8n/{core,n8n,services,staging}

# Copiar compose files (via scp ou git)
scp infrastructure/n8n/core/*.yml root@<VPS>:/opt/n8n/core/
scp infrastructure/n8n/n8n/*.yml root@<VPS>:/opt/n8n/n8n/
```

### 9.3 Customizar Variáveis N8N

Criar `/opt/n8n/.env`:

```env
# Database
DB_POSTGRESDB_DATABASE=n8n_queue
DB_POSTGRESDB_PASSWORD=SUA_SENHA_SEGURA
POSTGRES_PASSWORD=SUA_SENHA_SEGURA

# N8N
N8N_ENCRYPTION_KEY=GERAR_CHAVE_UNICA_40_CHARS
N8N_HOST=n8n.SEU-DOMINIO.com
N8N_EDITOR_BASE_URL=https://n8n.SEU-DOMINIO.com/
WEBHOOK_URL=https://webhook.SEU-DOMINIO.com/

# Redis
REDIS_PASSWORD=SUA_SENHA_REDIS

# Email
N8N_SMTP_HOST=smtp.SEU-PROVEDOR.com
N8N_SMTP_USER=SEU_EMAIL
N8N_SMTP_PASS=SUA_SENHA_SMTP

# Timezone
GENERIC_TIMEZONE=America/Sao_Paulo
```

### 9.4 Configurar Traefik (Reverse Proxy)

Os compose files já incluem labels Traefik. Substituir os hostnames:

```yaml
# Em cada compose file, trocar:
# De: Host(`n8n.allfluence.ai`)
# Para: Host(`n8n.SEU-DOMINIO.com`)
```

### 9.5 Ordem de Deploy

```bash
# 1. Core (database + redis)
docker stack deploy -c /opt/n8n/core/postgres.docker-compose.yml n8n-core
docker stack deploy -c /opt/n8n/core/redis.docker-compose.yml n8n-core

# 2. Workers (processamento de fila)
docker stack deploy -c /opt/n8n/n8n/n8n-worker-1.docker-compose.yml n8n
docker stack deploy -c /opt/n8n/n8n/n8n-worker-2.docker-compose.yml n8n

# 3. Webhooks
docker stack deploy -c /opt/n8n/n8n/n8n-webhook-1.docker-compose.yml n8n
docker stack deploy -c /opt/n8n/n8n/n8n-webhook-2.docker-compose.yml n8n

# 4. Editor (por último)
docker stack deploy -c /opt/n8n/n8n/n8n-editor.docker-compose.yml n8n
```

---

## 10. Fase 9 — Conectar Canais

### 10.1 WhatsApp (via Evolution API)

```bash
# Deploy Evolution API
docker stack deploy -c /opt/n8n/services/evolution.docker-compose.yml services

# Configurar número WhatsApp no OpenClaw
openclaw channel add whatsapp \
  --provider evolution \
  --phone "+55SEUNUMERO" \
  --api-url "http://evolution:8080"
```

### 10.2 ClickUp Webhooks

```bash
# Criar webhook no ClickUp apontando para seu N8N
# URL: https://webhook.SEU-DOMINIO.com/webhook/clickup-events
```

### 10.3 Slack (opcional)

```bash
openclaw channel add slack \
  --token "xoxb-SEU-TOKEN" \
  --channel "#seu-canal"
```

---

## 11. Fase 10 — Validação Final

### 11.1 Checklist de Verificação

```bash
# 1. Gateway respondendo
curl http://meu-gateway.tail<ID>.ts.net:18789/health

# 2. Tailscale conectado
tailscale ping meu-gateway

# 3. Bridge.js detecta serviços
node .aios-core/infrastructure/services/bridge.js status

# 4. LLM Router funcional
# (Enviar mensagem que aciona tier budget)
openclaw agent --message "status dos serviços"

# 5. Skills respondendo
openclaw agent --message "listar tasks do ClickUp"

# 6. Segurança ativa
# (Testar que comandos bloqueados são rejeitados)
openclaw agent --message "execute rm -rf /"
# Deve ser bloqueado pelo Layer 1

# 7. Métricas coletando
# (Verificar logs após algumas interações)
journalctl -u openclaw --since "1 hour ago" | grep metrics

# 8. Claude Code hooks funcionando
# (Abrir nova sessão Claude Code e verificar status no greeting)
```

### 11.2 Teste End-to-End

```
1. Abrir Claude Code
2. Verificar que SessionStart hook mostra status dos serviços
3. Ativar agente: @{agent-name}
4. Executar: *status
5. Executar: *clickup list (se configurado)
6. Enviar mensagem WhatsApp para o número configurado
7. Verificar resposta do agente
```

---

## 12. Workflow de Agentes AIOS

### Sequência de Agentes para Setup Completo

```
FASE 1-2: Setup Infraestrutura
┌─────────────────────────────────────────────────┐
│  @devops (Gage)                                  │
│  ├── Criar VPS Hetzner                          │
│  ├── Instalar Tailscale                         │
│  ├── Deploy OpenClaw no VPS                     │
│  ├── Configurar systemd service                 │
│  └── Setup Portainer + Docker Swarm             │
└─────────────────────────────────────────────────┘

FASE 3: Identidade Whitelabel
┌─────────────────────────────────────────────────┐
│  @aios-master (Orion) ou @squad-creator         │
│  ├── Criar definição do agente                  │
│  ├── Gerar estrutura de diretórios              │
│  └── Registrar no AIOS                          │
└─────────────────────────────────────────────────┘

FASE 4-5: LLM Router + Skills
┌─────────────────────────────────────────────────┐
│  @architect (Aria)                               │
│  ├── Definir tiers e skill mapping              │
│  ├── Configurar fallback strategy               │
│  └── Revisar arquitetura de skills              │
│                                                  │
│  @dev (Dex)                                      │
│  ├── Customizar config.js                       │
│  ├── Adaptar skills para novo ambiente          │
│  └── Implementar skills customizadas            │
└─────────────────────────────────────────────────┘

FASE 6: Segurança
┌─────────────────────────────────────────────────┐
│  @devops (Gage)                                  │
│  ├── Configurar Docker sandbox                  │
│  ├── Setup logging/audit                        │
│  └── Configurar firewall + Tailscale ACLs       │
│                                                  │
│  @qa (Quinn)                                     │
│  ├── Testar blocklist (50 test cases)           │
│  ├── Verificar isolamento do sandbox            │
│  └── Audit trail compliance                     │
└─────────────────────────────────────────────────┘

FASE 7: Integração Claude Code
┌─────────────────────────────────────────────────┐
│  @dev (Dex)                                      │
│  ├── Criar service index.js para bridge         │
│  ├── Configurar hooks em settings.json          │
│  └── Testar bridge auto-discovery               │
└─────────────────────────────────────────────────┘

FASE 8-9: N8N + Canais
┌─────────────────────────────────────────────────┐
│  @devops (Gage)                                  │
│  ├── Deploy stack N8N                           │
│  ├── Configurar Traefik routing                 │
│  ├── Setup Evolution API (WhatsApp)             │
│  └── DNS + SSL certificates                     │
└─────────────────────────────────────────────────┘

FASE 10: Validação
┌─────────────────────────────────────────────────┐
│  @qa (Quinn)                                     │
│  ├── Checklist de verificação completa          │
│  ├── Teste end-to-end                           │
│  ├── Validação de segurança                     │
│  └── Performance benchmarks                     │
└─────────────────────────────────────────────────┘
```

### Comandos AIOS por Fase

| Fase | Agente | Comando |
|------|--------|---------|
| 1-2 | `@devops` | `*task deploy-openclaw-vps` |
| 3 | `@aios-master` | `*create agent` → seguir wizard |
| 4 | `@architect` | `*create-backend-architecture` |
| 5 | `@dev` | `*develop` → implementar skills |
| 6 | `@devops` | `*task setup-security-layers` |
| 6 | `@qa` | `*task validate-security` |
| 7 | `@dev` | `*develop` → bridge integration |
| 8-9 | `@devops` | `*task deploy-n8n-stack` |
| 10 | `@qa` | `*execute-checklist architect-checklist` |

---

## 13. Troubleshooting

### Gateway não responde

```bash
# Verificar serviço
systemctl status openclaw

# Verificar logs
journalctl -u openclaw -f

# Verificar porta
ss -tlnp | grep 18789

# Reiniciar
systemctl restart openclaw
```

### Tailscale sem conectividade

```bash
# Verificar status
tailscale status

# Re-autenticar
tailscale up --reset

# Verificar firewall
ufw status
ufw allow 41641/udp  # Porta Tailscale
```

### LLM Router retornando erros

```bash
# Verificar API keys
openclaw agent --message "test" --verbose 2>&1 | grep -i "router\|tier\|model"

# Verificar config
node -e "const y=require('js-yaml');const f=require('fs');console.log(JSON.stringify(y.load(f.readFileSync('apps/{agent-name}/config/llm-router-config.yaml','utf8')),null,2))"
```

### Bridge.js não detecta serviços

```bash
# Verificar estrutura
ls -la .aios-core/infrastructure/services/

# Verificar que index.js existe em cada subdiretório
find .aios-core/infrastructure/services -name "index.js"

# Testar manualmente
node .aios-core/infrastructure/services/bridge.js list
```

### Claude Code hooks falhando

```bash
# Verificar settings.json
cat .claude/settings.json | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).hooks))"

# Testar hook manualmente
echo '{"tool":"Bash","input":"echo test"}' | node .aios-core/infrastructure/services/bridge.js validate-call
```

### N8N não acessível

```bash
# Verificar stacks
docker stack ls
docker service ls

# Verificar logs do editor
docker service logs n8n_n8n_editor --tail 50

# Verificar Traefik
docker service logs traefik --tail 50 | grep n8n
```

---

## Apêndice A — Arquivos para Copiar

Lista completa de arquivos a copiar de `apps/clawdbot/` para `apps/{agent-name}/`:

```
apps/clawdbot/
├── config/llm-router-config.yaml          → Copiar + customizar tiers
├── hooks/session-digest/handler.js        → Copiar sem alteração
├── hooks/session-digest/hook.yml          → Copiar + ajustar memory path
├── hooks/session-digest/index.js          → Copiar sem alteração
├── hooks/session-digest/ingester.js       → Copiar sem alteração
├── hooks/session-digest/scorer.js         → Copiar sem alteração
├── hooks/session-digest/templates.js      → Copiar sem alteração
├── hooks/session-digest/types.js          → Copiar sem alteração
├── lib/llm-router.js                      → Copiar sem alteração
├── lib/metrics-alerts.js                  → Copiar + customizar thresholds
├── lib/metrics-collector.js               → Copiar sem alteração
├── lib/metrics-queries.js                 → Copiar sem alteração
├── skills/config.js                       → ⚠️ CUSTOMIZAR TUDO
├── skills/index.js                        → Copiar + ajustar exports
├── skills/package.json                    → Copiar sem alteração
├── skills/clickup-ops/                    → Copiar + ajustar Team ID
├── skills/n8n-trigger/                    → Copiar + ajustar Workflow IDs
├── skills/supabase-query/                 → Copiar + ajustar tabelas
├── skills/allos-status/                   → Copiar + renomear + ajustar URLs
├── skills/alerts/                         → Copiar + ajustar Slack webhook
├── skills/memory/                         → Copiar + ajustar paths
├── skills/lib/blocklist.yaml              → Copiar (adicionar regras se necessário)
├── skills/lib/command-safety.js           → Copiar sem alteração
├── skills/lib/errors.js                   → Copiar sem alteração
└── skills/lib/logger.js                   → Copiar sem alteração
```

## Apêndice B — Checklist Final

- [ ] VPS Hetzner criado e acessível via SSH
- [ ] Tailscale instalado no VPS e desktop, ambos na mesma Tailnet
- [ ] OpenClaw clonado, buildado e rodando como serviço no VPS
- [ ] Identidade whitelabel definida (nome, ícone, persona)
- [ ] Diretório `apps/{agent-name}/` criado com estrutura completa
- [ ] `config.js` customizado com suas credenciais e URLs
- [ ] LLM Router configurado com API keys
- [ ] `.env` populado com todas as variáveis necessárias
- [ ] Blocklist de segurança configurado
- [ ] Docker sandbox operacional (Layer 2)
- [ ] Logging/audit configurado (Layer 3)
- [ ] `bridge.js` detecta o novo serviço
- [ ] Claude Code hooks configurados em `settings.json`
- [ ] N8N stack deployed (se aplicável)
- [ ] Canais conectados (WhatsApp, Slack, etc.)
- [ ] Teste end-to-end passando
- [ ] Agente registrado no AIOS (`@{agent-name}`)

---

*Guia gerado por @architect (Aria) — Arquitetando o futuro 🏗️*
