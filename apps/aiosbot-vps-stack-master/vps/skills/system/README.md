---
category: system
description: System maintenance, monitoring, LLM routing, and meta-operations
skills:
  - name: model-router
    description: LLM model selection and intelligent 4-tier routing
    always: false
    requires: []
  - name: cost-monitor
    description: Track and alert on daily LLM API costs
    always: false
    requires: []
  - name: skill-creator
    description: Create new skills from templates
    always: false
    requires: []
---
# System Skills

Skills for system maintenance, monitoring, and meta-operations.

## Included Skills

| Skill | Description |
|-------|-------------|
| model-router | LLM model selection and intelligent routing |
| cost-monitor | Track and alert on LLM API costs |
| skill-creator | Create new skills from templates |

## Model Router

Routes LLM requests to the optimal model based on:
- Skill hint (direct mapping)
- Keyword analysis (content-based)
- Cost constraints (per-tier limits)
- Fallback chain (automatic escalation)

Config: `~/.aiosbot/llm-router-config.yaml`

## Cost Monitor

Tracks daily LLM spending and alerts when thresholds are exceeded:
- Warning: $50/day (configurable)
- Critical: $100/day (configurable)
- Error rate monitoring
- Fallback rate monitoring
