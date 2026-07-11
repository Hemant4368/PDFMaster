# AI Development Setup

This document describes the AI tooling configured for this project.

## Tools

### 1. Claude Code (v2.1.193)

Claude Code is installed as the primary AI coding assistant.

**Config files:**
- `.claude/settings.json` — hooks and session settings
- `CLAUDE.md` — project instructions for Claude

### 2. Ruflo (v3.10.46)

Ruflo is the agent meta-harness providing agents, swarms, memory, and coordination.

**Initialization:** `npx ruflo@latest init`

**Key components:**
- `.claude/agents/` — 17 specialized agent definitions
- `.claude/commands/` — 16 custom commands
- `.claude/skills/` — 30 skills
- `.claude-flow/` — runtime config and data

**Next steps:**
```bash
ruflo daemon start        # start background workers
ruflo memory init         # initialize memory database
ruflo swarm init          # initialize a swarm
```

### 3. Code Review Graph (v2.3.6)

Builds a persistent structural map of the codebase for context-efficient AI interactions.

**Installation:** `pip install code-review-graph`

**Configuration:** `.mcp.json` registers the MCP server for Claude Code.

**Usage:**
```bash
code-review-graph build     # parse the codebase
code-review-graph update    # incremental update
code-review-graph watch     # auto-update on file changes
```

**Key MCP tools:** `detect_changes`, `query_graph`, `semantic_search_nodes`, `get_impact_radius`, `get_review_context`

The graph auto-updates on file edits via hooks configured in `.claude/settings.json`.

## Workflow

1. Claude Code uses Ruflo for agent orchestration
2. Code Review Graph provides structural context (callers, dependents, tests)
3. Ruflo MCP tools (`memory_store`, `swarm_init`, `agent_spawn`) handle persistent memory and swarm coordination
