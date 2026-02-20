# MCP Integration Guide

Guide for configuring and using MCP (Model Context Protocol) servers with AIOSBot.

## Overview

MCPs extend AIOSBot's capabilities by connecting to external services. They run via **mcporter** on the VPS.

## Available MCPs

| MCP | Purpose | Required Config |
|-----|---------|----------------|
| **memory** | Persistent memory via Supabase | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` |
| **brave-search** | Web search | `BRAVE_API_KEY` |
| **exa** | Advanced web search & research | `EXA_API_KEY` |
| **context7** | Library documentation lookup | None (free) |
| **filesystem** | File system operations | Path config |
| **puppeteer** | Browser automation | Chrome/Chromium |
| **sqlite** | Local SQLite database | DB path |
| **github** | GitHub API operations | `GITHUB_TOKEN` |

## Configuration

MCP configuration is managed via mcporter. The config file is at:
```
~/.aiosbot/skills/mcp-config/
```

### Adding an MCP

```bash
# Via mcporter
aiosbot mcp add <mcp-name>

# Or manually edit the config
```

### MCP Config Template

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-memory"],
      "env": {
        "SUPABASE_URL": "${SUPABASE_URL}",
        "SUPABASE_KEY": "${SUPABASE_SERVICE_ROLE_KEY}"
      }
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-filesystem", "/home/aiosbot/workspace"]
    }
  }
}
```

## Connecting MCPs to Services

### Memory → Supabase
The memory MCP stores long-term memories in Supabase's `unified_memories` table.

Required setup:
1. Create Supabase project
2. Run the memory schema migration
3. Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`

### Search → Brave/EXA
Web search for real-time information.

Required setup:
1. Get API key from Brave Search or EXA
2. Set the API key in `.env`

## Troubleshooting

### MCP Not Loading
```bash
# Check mcporter status
aiosbot mcp list

# Check logs
tail -f ~/.aiosbot/logs/mcp.log
```

### MCP Timeout
- Default timeout: 30s
- Increase in aiosbot.json if needed
- Check network connectivity to the service

### MCP Authentication Failed
- Verify API keys in `.env`
- Check key hasn't expired
- Test directly: `curl -H "Authorization: Bearer $API_KEY" ...`
