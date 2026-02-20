# Skills Guide

Comprehensive catalog of all skills included in the AIOSBot VPS Stack.

## Skill Categories

### Infrastructure Skills

#### supabase-query
- **Purpose:** Read-only queries against Supabase database
- **Tier:** Budget
- **Tools:** query_creators, query_projects, get_stats
- **Config:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`

#### n8n-trigger
- **Purpose:** Trigger N8N automation workflows via webhook
- **Tier:** Budget
- **Tools:** trigger_workflow, list_workflows, get_execution
- **Config:** `N8N_WEBHOOK_BASE`, `N8N_API_KEY`

#### clickup-ops
- **Purpose:** ClickUp project management CRUD
- **Tier:** Standard
- **Tools:** list_tasks, create_task, update_task, add_comment, get_project_status
- **Config:** `CLICKUP_API_KEY`, `CLICKUP_TEAM_ID`

#### allos-status
- **Purpose:** Health check and service status reports
- **Tier:** Budget
- **Tools:** health_check, service_status, daily_report
- **Config:** Service URLs in config.js

### Memory Skills

#### knowledge-graph
- **Purpose:** Three-layer entity memory (people, companies, projects)
- **Storage:** `life/areas/{type}/{slug}/facts.jsonl`
- **Format:** Append-only JSONL with supersede support

#### unified-memory
- **Purpose:** Unified memory search across all sources
- **Tools:** memory_search, memory_add, context_get_project
- **Integration:** Supabase unified_memories table

#### context-recovery
- **Purpose:** Recover session context from memory files
- **Usage:** Automatic on session start

#### todo-tracker
- **Purpose:** Track tasks and TODOs across sessions
- **Storage:** Workspace TODO.md

### Dev Skills

#### react-best-practices
- **Purpose:** 57 rules for React performance and patterns
- **Usage:** Automatically applied when writing React code

#### composition-patterns
- **Purpose:** Component composition and design patterns
- **Usage:** Reference for complex component architecture

#### web-design-guidelines
- **Purpose:** 100+ UX/accessibility rules
- **Usage:** Applied when building web interfaces

#### vercel-deploy-claimable
- **Purpose:** Deploy to Vercel with proper env handling
- **Flow:** `env pull → build --prod → deploy --prebuilt`

### Superpowers (Development Workflow)

The Superpowers are a mandatory 6-step development workflow:

| # | Superpower | Purpose |
|---|-----------|---------|
| 1 | **brainstorming** | Explore alternatives before coding |
| 2 | **writing-plans** | Create detailed plans with small tasks |
| 3 | **test-driven-development** | Write test first, then implement |
| 4 | **executing-plans** | Batch execution with checkpoints |
| 5 | **verification-before-completion** | Run all tests before declaring done |
| 6 | **requesting-code-review** | Review before merge |

Additional superpowers:
- **dispatching-parallel-agents** — Fan out work to subagents
- **finishing-a-development-branch** — Clean branch finalization
- **receiving-code-review** — Process review feedback
- **subagent-driven-development** — Multi-agent coding
- **systematic-debugging** — Structured debug approach
- **using-git-worktrees** — Isolated branch development
- **using-superpowers** — Meta-guide for the workflow
- **writing-skills** — Create new skills

### Orchestration Skills

#### planner
- **Purpose:** High-level project planning
- **Note:** Prefer superpowers/writing-plans for code tasks

#### task-orchestrator
- **Purpose:** Manage and dispatch multiple tasks
- **Usage:** For large projects with independent subtasks

### System Skills

#### model-router
- **Purpose:** LLM model selection and routing
- **Config:** `llm-router-config.yaml`

#### cost-monitor
- **Purpose:** Track and alert on LLM costs
- **Thresholds:** Configurable in config.js

## Adding Custom Skills

1. Create a directory in `~/.aiosbot/skills/your-skill/`
2. Add `SKILL.md` with description and usage
3. Add `tools/` directory with tool implementations
4. Add `index.js` exporting the skill
5. Register in `skills/config.js` if needed

## Skill Not Working?

1. Check `aiosbot skills list` — is it loaded?
2. Check `SKILL.md` exists in the skill directory
3. Check dependencies: `cd skills/your-skill && npm install`
4. Check logs: `~/.aiosbot/logs/`
