---
name: skill-creator
description: Dynamic skill creation and scaffolding
version: 1.0.0
tier: standard
always_on: false
---

# Skill Creator

Creates new skills dynamically with proper SKILL.md, index.js,
and configuration scaffolding. Story 12.11.

## Capabilities
- Scaffold new skill structure (SKILL.md + index.js + tools/)
- Generate SKILL.md with YAML frontmatter
- Create index.js with handler and health placeholders
- Validate skill name, category, and uniqueness

## Tools
1. `create_skill` — Create a new skill with full scaffolding
   - `skill_name` (string, required) — Lowercase kebab-case name (e.g., `my-skill`)
   - `category` (string, required) — One of: dev, infrastructure, memory, orchestration, superpowers, system
   - `description` (string, required) — Short description of the skill
   - `tier` (string, optional, default: `standard`) — LLM tier: budget, standard, premium
   - `always_on` (boolean, optional, default: `false`) — Whether skill loads automatically

## Configuration
- No external dependencies
- Requires filesystem write access to skills directory
