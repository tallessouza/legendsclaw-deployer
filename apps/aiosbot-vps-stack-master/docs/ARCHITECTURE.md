# Architecture Overview

## System Diagram

```mermaid
graph TB
    subgraph Local["Local Desktop"]
        CC[Claude Code]
        BJ[Bridge.js]
        SH[Session Hook]
        LC[Local Config]

        CC --> BJ
        CC --> SH
        BJ --> LC
    end

    subgraph VPN["Tailscale VPN"]
        TS[Encrypted Tunnel]
    end

    subgraph VPS["VPS Server"]
        GW[AIOSBot Gateway :18789]

        subgraph Router["LLM Router :55119"]
            B[Budget Tier]
            S[Standard Tier]
            Q[Quality Tier]
            P[Premium Tier]
        end

        subgraph Skills["Skills Engine"]
            INF[Infrastructure]
            MEM[Memory]
            DEV[Dev Skills]
            SUP[Superpowers]
            ORC[Orchestration]
            SYS[System]
        end

        subgraph MCP["MCP Servers"]
            BRV[Brave Search]
            FS[Filesystem]
            MEMO[Memory MCP]
        end

        subgraph WS["Workspace"]
            SOUL[SOUL.md]
            AGENTS[AGENTS.md]
            IDENTITY[IDENTITY.md]
            USER[USER.md]
            MEMF[memory/]
        end

        GW --> Router
        GW --> Skills
        GW --> MCP
        GW --> WS
    end

    subgraph External["External Services"]
        OR[OpenRouter API]
        ANT[Anthropic API]
        SUP_DB[Supabase]
        CU[ClickUp]
        N8N[N8N]
        WA[WhatsApp]
    end

    BJ -->|WSS| TS
    TS -->|WSS| GW

    B --> OR
    S --> OR
    Q --> OR
    Q --> ANT
    P --> ANT

    INF --> SUP_DB
    INF --> CU
    INF --> N8N
    MEMO --> SUP_DB
    GW --> WA
```

## Component Details

### Local Desktop
- **Claude Code**: Primary IDE integration
- **Bridge.js**: Service discovery, validation, and audit logging
- **Session Hook**: Auto-connects to VPS on session start
- **Config**: Gateway URL and authentication

### VPS Server
- **AIOSBot Gateway**: Central hub, handles connections, routes messages
- **LLM Router**: Intelligent model selection based on task complexity
- **Skills Engine**: 32 skills in 6 categories with progressive loading
- **MCP Servers**: External service integrations via mcporter
- **Workspace**: Agent personality, memory, and configuration

### Data Flow
1. User sends message via Claude Code or WhatsApp
2. Message reaches gateway via Tailscale or direct connection
3. Gateway classifies the request (skill hint + keywords)
4. LLM Router selects optimal model for the tier
5. Skills execute tool calls if needed
6. Response flows back through the same path

### Security Layers
1. **Transport**: Tailscale encrypted VPN
2. **Authentication**: Password-based gateway auth
3. **Authorization**: WhatsApp allowlist, DM policy
4. **Secrets**: .env file, permission 600 on configs
5. **Isolation**: Sandbox mode configurable in aiosbot.json (default: off)
6. **Workspace Restriction**: `restrictToWorkspace: true` limits filesystem access to workspace + allowed paths only
7. **Shell Hardening**: `denyPatterns` blocks destructive commands (rm -rf /, fork bombs, pipe-to-shell, etc.)
