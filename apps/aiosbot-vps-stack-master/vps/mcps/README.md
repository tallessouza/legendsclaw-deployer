# MCP Server Configurations

This directory contains MCP (Model Context Protocol) server configurations for use with mcporter.

## Included MCPs

| MCP | Description | Required API Key |
|-----|-------------|-----------------|
| brave-search | Web search | BRAVE_API_KEY |
| filesystem | Local file access | None |
| memory | Persistent memory | SUPABASE_URL + KEY |

## Setup

1. Configure API keys in `.env`
2. Install mcporter: `aiosbot mcp install`
3. Add MCPs: `aiosbot mcp add <name>`

## Adding New MCPs

See [MCP Guide](../../docs/MCP-GUIDE.md) for detailed instructions.
