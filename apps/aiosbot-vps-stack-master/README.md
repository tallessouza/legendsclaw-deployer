# AIOSBot VPS Stack

A complete whitelabel stack for running [AIOSBot](https://github.com/SynkraAI/aiosbot-vps-stack) on your own VPS with an intelligent LLM router, 32 skills across 6 categories, MCP integrations, and local desktop bridge.

## What's Included

| Component | Description |
|-----------|-------------|
| **Gateway** | AIOSBot gateway with WebSocket support, Tailscale VPN |
| **LLM Router** | 4-tier intelligent routing (Budget → Standard → Quality → Premium) |
| **Skills** | 32 skills in 6 categories with progressive loading (infrastructure, memory, dev, superpowers, orchestration, system) |
| **MCPs** | MCP server configurations via mcporter |
| **Workspace** | Agent personality files (SOUL, AGENTS, MEMORY shipped; IDENTITY, USER generated on first boot) |
| **Bridge** | Local service discovery and audit logging |
| **Hooks** | Claude Code session hooks for auto-connection |

## Architecture

```
┌─────────────────────────┐     ┌──────────────────────────┐
│     LOCAL DESKTOP        │     │         VPS               │
│                          │     │                            │
│  Claude Code             │     │  AIOSBot Gateway          │
│    ↓                     │     │    ├── LLM Router (4-tier) │
│  Bridge.js ──Tailscale──────→ │    ├── Skills (32)          │
│    ↓                     │     │    ├── MCPs (mcporter)     │
│  Session Hook            │     │    └── Workspace Files     │
│                          │     │                            │
│  ~/.aiosbot/            │     │  /home/aiosbot/.aiosbot/   │
│    ├── aiosbot.json     │     │    ├── aiosbot.json      │
│    ├── node.json         │     │    ├── skills/            │
│    └── bridge/           │     │    └── memory/            │
└─────────────────────────┘     └──────────────────────────┘
```

## Quick Start

### Prerequisites

- A VPS (Ubuntu 20.04+ recommended) with root access
- [Tailscale](https://tailscale.com) account
- Node.js 18+ on both VPS and local machine
- API keys for your preferred LLM providers (OpenRouter, Anthropic, etc.)

### 1. Clone and Configure

```bash
git clone https://github.com/YourOrg/aiosbot-vps-stack.git
cd aiosbot-vps-stack
./setup.sh
```

The setup wizard will ask for:
- Your identity (name, org, agent personality)
- VPS details (IP, Tailscale hostname)
- API keys (OpenRouter, Anthropic, etc.)
- Optional integrations (ClickUp, Supabase, N8N)

### 2. Install on VPS

```bash
# Copy files to VPS
scp -r vps/* root@YOUR_VPS_IP:/tmp/aiosbot/

# SSH and install
ssh root@YOUR_VPS_IP
cd /tmp/aiosbot
./install.sh
```

### 3. Install Locally

```bash
./local/install.sh
```

### 4. Verify

```bash
./scripts/validate.sh
./tests/test-gateway.sh
./tests/test-local.sh
```

## Directory Structure

```
aiosbot-vps-stack/
├── README.md                    # This file
├── .env.example                 # Environment variables template
├── setup.sh                     # Interactive setup wizard
├── vps/                         # VPS components
│   ├── install.sh              # VPS installer
│   ├── docker-compose.yml      # Container orchestration
│   ├── config/                 # Gateway configuration
│   ├── workspace/              # Agent personality files
│   ├── skills/                 # Organized skill categories
│   └── mcps/                   # MCP configurations
├── local/                       # Desktop components
│   ├── install.sh              # Local installer
│   ├── bridge/                 # Service discovery bridge
│   ├── hooks/                  # Claude Code hooks
│   ├── config/                 # Local gateway config
│   └── skills/                 # Local skill config
├── docs/                        # Documentation
├── scripts/                     # Utility scripts
└── tests/                       # Validation tests
```

## LLM Router

The 4-tier LLM router optimizes cost and quality:

| Tier | Models | Max Cost/Request | Use Case |
|------|--------|-----------------|----------|
| Budget | DeepSeek V3, Gemini Flash | $0.01 | Status checks, simple queries |
| Standard | Mistral Large, GPT-4o Mini | $0.10 | CRUD operations, workflows |
| Quality | Claude Sonnet, GPT-4o | $2.00 | Analysis, code review |
| Premium | Claude Opus | $10.00 | Strategic planning, critical ops |

See [docs/LLM-ROUTER.md](docs/LLM-ROUTER.md) for details.

## Skills

Skills are organized by category:

| Category | Skills | Purpose |
|----------|--------|---------|
| Infrastructure | supabase-query, n8n-trigger, clickup-ops, allos-status | Service integrations |
| Memory | knowledge-graph, unified-memory, context-recovery, todo-tracker | Persistent memory |
| Dev | react-best-practices, composition-patterns, web-design, vercel-deploy | Development helpers |
| Superpowers | brainstorming, TDD, planning, debugging, code review (14 total) | Development workflow |
| Orchestration | planner, task-orchestrator | Task management |
| System | model-router, cost-monitor, skill-creator | System maintenance |

See [docs/SKILLS-GUIDE.md](docs/SKILLS-GUIDE.md) for the full catalog.

## Configuration

All configuration uses `{{PLACEHOLDER}}` template syntax. Run `setup.sh` to fill in values interactively, or edit `.env` directly.

Key configuration files (generated from `.template` files by `setup.sh`):
- `.env` — All secrets and environment variables
- `vps/config/aiosbot.json.template` → `aiosbot.json` — VPS gateway configuration
- `local/config/aiosbot.json.template` → `aiosbot.json` — Local desktop configuration
- `vps/config/llm-router-config.yaml` — LLM routing rules (static, no templates)
- `vps/workspace/*.md` — Agent personality and behavior (IDENTITY.md and USER.md generated on first boot)

## Security

- All API keys are stored in `.env` (never committed)
- Gateway uses password authentication
- Tailscale provides encrypted VPN tunnel
- WhatsApp uses allowlist-based access control
- Config files have restricted permissions (600)

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

## License

MIT
