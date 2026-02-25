---
name: memory
description: Context persistence — local filesystem memory
version: 1.0.0
tier: budget
always_on: false
---

# Memory Skill

Context persistence using local filesystem. Stores and retrieves agent memory,
daily notes, and context data.

## Capabilities
- Store and retrieve memories from local filesystem
- Daily note management
- Context data persistence across sessions

## Configuration
- Requires: filesystem access to ~/.clawd/memory/
- No external dependencies
