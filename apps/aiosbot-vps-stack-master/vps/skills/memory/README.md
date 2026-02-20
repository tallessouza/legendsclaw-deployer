---
category: memory
description: Persistent memory and context management across sessions
skills:
  - name: knowledge-graph
    description: Three-layer entity memory (people, companies, projects) via JSONL
    always: false
    requires: []
  - name: unified-memory
    description: Unified search across all memory sources via Supabase
    always: false
    requires: [SUPABASE_URL]
  - name: context-recovery
    description: Recover session context from memory files on startup
    always: true
    requires: []
  - name: todo-tracker
    description: Track tasks and TODOs across sessions via TODO.md
    always: false
    requires: []
---
# Memory Skills

Skills for persistent memory and context management across sessions.

## Included Skills

| Skill | Description | Storage |
|-------|-------------|---------|
| knowledge-graph | Three-layer entity memory (people, companies, projects) | `life/areas/` JSONL |
| unified-memory | Unified search across all memory sources | Supabase |
| context-recovery | Recover session context from memory files | Local files |
| todo-tracker | Track tasks and TODOs across sessions | TODO.md |

## Knowledge Graph Structure

```
life/areas/
├── people/
│   └── {slug}/
│       ├── summary.md     # Quick context (5 lines max)
│       └── facts.jsonl    # Atomic facts (append-only)
├── companies/
│   └── {slug}/
└── projects/
    └── {slug}/
```

## Fact Format (facts.jsonl)

```json
{"id": "fact-001", "content": "Fact text here", "source": "session", "date": "2026-02-19", "status": "active"}
```

To supersede a fact:
```json
{"id": "fact-002", "content": "Updated fact", "supersedes": "fact-001", "status": "active"}
```
