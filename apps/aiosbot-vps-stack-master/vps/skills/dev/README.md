---
category: dev
description: Software development best practices, React patterns, and deployment
skills:
  - name: react-best-practices
    description: 57 performance and pattern rules for React (auto-applied)
    always: false
    requires: []
  - name: composition-patterns
    description: Component composition and design patterns reference
    always: false
    requires: []
  - name: web-design-guidelines
    description: 100+ UX and accessibility rules (auto-applied)
    always: false
    requires: []
  - name: vercel-deploy-claimable
    description: Vercel deployment with env handling
    always: false
    requires: [VERCEL_TOKEN]
  - name: react-native-skills
    description: React Native development patterns reference
    always: false
    requires: []
---
# Dev Skills

Skills for software development best practices and deployment.

## Included Skills

| Skill | Description | Rules |
|-------|-------------|-------|
| react-best-practices | 57 performance and pattern rules for React | Auto-applied |
| composition-patterns | Component composition and design patterns | Reference |
| web-design-guidelines | 100+ UX/accessibility rules | Auto-applied |
| vercel-deploy-claimable | Vercel deployment with env handling | On demand |
| react-native-skills | React Native development patterns | Reference |

## Usage

Dev skills are automatically loaded when relevant code tasks are detected.
They provide rules and patterns that guide code generation.

### React Best Practices
Automatically applied when writing React code. Covers:
- Performance optimization (useMemo, useCallback)
- State management patterns
- Component structure
- Error boundaries
- Testing patterns

### Vercel Deploy
Flow: `env pull → build --prod → deploy --prebuilt`

Ensures environment variables are consistent between build and runtime.
