# Troubleshooting Guide

## Common Issues

### Gateway Won't Start

**Symptom:** `aiosbot gateway start` fails or exits immediately.

**Solutions:**
1. Check port 18789 is free: `lsof -i :18789`
2. Check config syntax: `jq . ~/.aiosbot/aiosbot.json`
3. Check Node.js version: `node --version` (need 18+)
4. Check logs: `~/.aiosbot/logs/`
5. Try debug mode: `AIOSBOT_DEBUG=true aiosbot gateway start`

### Local Can't Connect to VPS

**Symptom:** Bridge or aiosbot shows "connection refused" or timeout.

**Solutions:**
1. Verify Tailscale: `tailscale status` on both machines
2. Ping VPS: `tailscale ping your-gateway`
3. Check gateway is running on VPS: `ssh user@vps 'screen -ls'`
4. Check URL in local config matches VPS hostname
5. Verify password matches in both configs

### Skills Not Loading

**Symptom:** `aiosbot skills list` shows empty or missing skills.

**Solutions:**
1. Check skills directory exists: `ls ~/.aiosbot/skills/`
2. Each skill needs `SKILL.md` and `index.js`
3. Install dependencies: `cd ~/.aiosbot/skills && npm install`
4. Check for syntax errors in skill files

### LLM Router Returns Errors

**Symptom:** Model calls fail with "unauthorized" or "model not found".

**Solutions:**
1. Verify OpenRouter API key: `curl -H "Authorization: Bearer $OPENROUTER_API_KEY" https://openrouter.ai/api/v1/models`
2. Check model IDs in `llm-router-config.yaml`
3. Verify the anthropic-router service is running: `curl http://localhost:55119/health`
4. Check fallback models are configured

### High LLM Costs

**Symptom:** Daily costs exceeding budget.

**Solutions:**
1. Check which models are being used (cost-monitor skill)
2. Force cheaper models for routine tasks
3. Reduce heartbeat frequency
4. Set daily budget cap in AGENTS.md
5. Review subagent model settings

### Memory Not Persisting

**Symptom:** Agent forgets context between sessions.

**Solutions:**
1. Check workspace path is correct in config
2. Verify `memory/` directory exists and is writable
3. Check MEMORY.md exists in workspace
4. Verify compaction memoryFlush is enabled
5. Check Supabase connection for unified-memory

### WhatsApp Not Working

**Symptom:** Messages not being received or sent.

**Solutions:**
1. Check WhatsApp plugin is enabled in config
2. Verify phone number allowlist
3. Check QR code authentication is complete
4. Verify dmPolicy is correctly set

## Useful Debug Commands

```bash
# Gateway health
curl http://localhost:18789/health

# Skills status
aiosbot skills list

# Doctor check
aiosbot doctor

# View logs
tail -f ~/.aiosbot/logs/*.log

# Check screen sessions
screen -ls

# Tailscale status
tailscale status
tailscale netcheck
```

## Getting Help

1. Check the [AIOSBot documentation](https://github.com/SynkraAI/aiosbot-vps-stack)
2. Search GitHub issues
3. Join the community Discord
