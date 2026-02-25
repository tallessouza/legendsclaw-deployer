---
name: elicitation
description: Structured interview sessions via templates
version: 1.0.0
tier: standard
always_on: false
---

# Elicitation Skill

Conducts structured interviews via templates. Start sessions, process responses,
track progress, and export results.

## Capabilities
- Start interview session from template
- Process user responses and advance questions
- Track session progress (% complete, fields filled)
- Export results as structured JSON

## Tools
1. `start_session` — Start interview from template_id
2. `process_message` — Process user response, advance to next question
3. `get_status` — Return session progress
4. `export_results` — Export results as structured JSON

## Configuration
- Requires: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
- Tables: elicitation_templates, elicitation_sessions, elicitation_results
- LLM Router integration for data extraction (optional, fallback to regex)
