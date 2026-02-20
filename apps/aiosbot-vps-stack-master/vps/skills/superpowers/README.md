---
category: superpowers
description: Mandatory 6-step development workflow for writing quality code
skills:
  - name: brainstorming
    description: Explore alternatives with divergent/convergent thinking before coding
    always: false
    requires: []
  - name: writing-plans
    description: Create detailed plans with 2-5 minute tasks
    always: false
    requires: []
  - name: test-driven-development
    description: Write test first, see it fail, then implement
    always: false
    requires: []
  - name: executing-plans
    description: Batch execution with checkpoints and progress tracking
    always: false
    requires: []
  - name: verification-before-completion
    description: Run all tests and validations before declaring done
    always: false
    requires: []
  - name: requesting-code-review
    description: Structured code review request before merge
    always: false
    requires: []
  - name: dispatching-parallel-agents
    description: Fan out work to subagents for parallel execution
    always: false
    requires: []
  - name: finishing-a-development-branch
    description: Clean branch finalization and merge preparation
    always: false
    requires: []
  - name: receiving-code-review
    description: Process and apply code review feedback
    always: false
    requires: []
  - name: subagent-driven-development
    description: Multi-agent coordinated coding
    always: false
    requires: []
  - name: systematic-debugging
    description: Structured debug approach with hypothesis testing
    always: false
    requires: []
  - name: using-git-worktrees
    description: Isolated branch development via git worktrees
    always: false
    requires: []
  - name: using-superpowers
    description: Meta-guide for the superpowers workflow
    always: false
    requires: []
  - name: writing-skills
    description: Create new skills from templates
    always: false
    requires: []
---
# Superpowers - Development Workflow

The mandatory 6-step development workflow for writing quality code.

## The Flow (DO NOT SKIP STEPS)

```
1. Brainstorming → 2. Planning → 3. TDD → 4. Execution → 5. Verification → 6. Review
```

## Skills

| # | Skill | Purpose | When to Use |
|---|-------|---------|-------------|
| 1 | brainstorming | Explore alternatives before coding | Before any new feature |
| 2 | writing-plans | Create detailed plans with small tasks | After brainstorming |
| 3 | test-driven-development | Write test first, see fail, implement | During development |
| 4 | executing-plans | Batch execution with checkpoints | Implementation phase |
| 5 | verification-before-completion | Run all tests before declaring done | Before marking complete |
| 6 | requesting-code-review | Code review before merge | Before merge/PR |

## Additional Superpowers

| Skill | Purpose |
|-------|---------|
| dispatching-parallel-agents | Fan out work to subagents |
| finishing-a-development-branch | Clean branch finalization |
| receiving-code-review | Process review feedback |
| subagent-driven-development | Multi-agent coding |
| systematic-debugging | Structured debug approach |
| using-git-worktrees | Isolated branch development |
| using-superpowers | Meta-guide for the workflow |
| writing-skills | Create new skills |

## Why This Matters

- Skipping brainstorming → Wrong implementation
- Skipping TDD → Bugs in production
- Skipping verification → Incomplete features
- Skipping review → Technical debt

Each step takes 2-5 minutes. The whole flow prevents hours of rework.
