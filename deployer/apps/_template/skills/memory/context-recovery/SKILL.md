---
name: context-recovery
description: Automatic context recovery after session restart
version: 1.0.0
tier: budget
always_on: true
---

# Context Recovery Skill

Recovers agent context automatically when a new session starts.
Loads previous session state, relevant memories, and working context.

## Capabilities
- Restore conversation context from previous sessions
- Load relevant memory fragments
- Rebuild working state

## Configuration
- Requires: filesystem access to workspace/memory/
