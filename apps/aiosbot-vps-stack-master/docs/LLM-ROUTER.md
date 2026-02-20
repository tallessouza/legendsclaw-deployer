# LLM Router - 4-Tier Intelligent Routing

## Overview

The LLM Router optimizes cost and quality by routing requests to the most appropriate model based on task complexity. It uses OpenRouter as the primary provider with direct Anthropic API as fallback.

## Architecture

```
Request → Tier Classification → Model Selection → Execution → Fallback (if needed)
          ↓                      ↓                              ↓
     skill_hint OR           Priority-based              Escalate to
     keyword analysis        within tier                 higher tier
```

## Tiers

### Budget Tier ($0.01 max/request)
- **DeepSeek V3** — Fast, cheap, good for simple tasks
- **Gemini Flash** — Google's fastest model, supports vision
- **Use for:** Status checks, health pings, simple lookups

### Standard Tier ($0.10 max/request)
- **Mistral Large** — Balanced cost/quality
- **GPT-4o Mini** — OpenAI's efficient model
- **Use for:** CRUD operations, workflow triggers, data fetching

### Quality Tier ($2.00 max/request)
- **Claude Sonnet** — Anthropic's balanced model
- **GPT-4o** — OpenAI's flagship
- **Use for:** Code review, analysis, document processing

### Premium Tier ($10.00 max/request)
- **Claude Opus** — Anthropic's most capable model
- **Use for:** Strategic planning, complex reasoning

## How Routing Works

### 1. Skill Hint (Highest Priority)
Each skill maps to a default tier:
```yaml
skill_mapping:
  allos-status: budget
  clickup-ops: standard
  code-review: quality
  strategic-planning: premium
```

### 2. Keyword Analysis (Fallback)
When no skill hint is provided, keywords determine the tier:
```yaml
budget: [status, check, list, simple, quick]
standard: [create, update, modify, send, trigger]
quality: [analyze, review, complex, detailed]
premium: [critical, strategic, enterprise]
```

### 3. Fallback Chain
If a model fails, the router escalates:
```
Budget → Standard → Quality → Premium → Direct Anthropic API
```

## Error Handling

| Error Type | Strategy |
|-----------|----------|
| Rate limit | Exponential backoff |
| Timeout | Try faster model |
| Server error | Exponential backoff |
| Context length | Try next model |
| Invalid request | Try next model |

## Configuration

Edit `vps/config/llm-router-config.yaml` to:
- Add/remove models
- Change tier assignments
- Adjust cost limits
- Modify keyword mappings
- Configure fallback behavior

## Cost Optimization Tips

1. Set a daily budget cap in AGENTS.md
2. Use `fast` or `cheap` model aliases for routine tasks
3. Monitor costs via the cost-monitor skill
4. Force Haiku for simple tool-calling queries
5. Use Gemini Flash for heartbeat checks
