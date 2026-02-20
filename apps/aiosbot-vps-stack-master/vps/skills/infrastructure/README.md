---
category: infrastructure
description: External service integrations (Supabase, N8N, ClickUp, health checks)
skills:
  - name: supabase-query
    description: Read-only Supabase database queries
    always: false
    requires: [SUPABASE_URL, SUPABASE_ANON_KEY]
  - name: n8n-trigger
    description: Trigger N8N automation workflows via webhook
    always: false
    requires: [N8N_WEBHOOK_URL]
  - name: clickup-ops
    description: ClickUp task management (create, update, list)
    always: false
    requires: [CLICKUP_TEAM_ID]
  - name: allos-status
    description: Service health checks and system status
    always: false
    requires: []
---
# Infrastructure Skills

Skills for integrating with external services and infrastructure.

## Included Skills

| Skill | Description | Config Required |
|-------|-------------|-----------------|
| supabase-query | Read-only Supabase queries | SUPABASE_URL, SUPABASE_ANON_KEY |
| n8n-trigger | Trigger N8N workflows | N8N_WEBHOOK_BASE |
| clickup-ops | ClickUp task management | CLICKUP_API_KEY, CLICKUP_TEAM_ID |
| allos-status | Service health checks | Service URLs |

## Installation

These skills are copied to `~/.aiosbot/skills/` during VPS installation.
Each skill has its own directory with:
- `SKILL.md` — Description and usage
- `index.js` — Main entry point
- `tools/` — Individual tool implementations

## Adding Your Own Infrastructure Skill

1. Create directory: `~/.aiosbot/skills/your-skill/`
2. Add `SKILL.md` with description
3. Add `index.js` exporting tools
4. Add `tools/index.js` with tool definitions
5. Update `config.js` with any required configuration
