# agent-watch

CLI tool for monitoring sub-agents and browsing sessions.

## Non-interactive (safe for agents)

| Command | Description |
|---------|-------------|
| `agent-watch list [count]` | List recent sub-agents (default: 20) |
| `agent-watch list-sessions [count]` | List all sessions (or last `count`) |
| `agent-watch list-sessions -p <name>` | Filter by project (case-insensitive partial match) |
| `agent-watch view [id]` | View agent transcript (most recent if no id) |
| `agent-watch <id>` | Auto-detect: view agent or session by ID |
| `agent-watch session <id>` | View a specific session |
| `agent-watch wait <id> [id...]` | Block until agent(s) complete |
| `agent-watch update` | Self-update to the latest release |
| `agent-watch version` | Show version and check for updates |

## Pagination (for large sessions/agents)

| Flag | Description |
|------|-------------|
| `--limit N` | Token budget (chars/4); prints `NEXT_OFFSET=M` when exceeded |
| `--offset N` | Skip first N messages (combine with `--limit` to paginate) |

```
agent-watch session abc123 --limit 5000
agent-watch session abc123 --offset 50 --limit 5000
```

## Interactive (require TTY, not usable by agents)

| Command | Description |
|---------|-------------|
| `agent-watch` | fzf selection of sub-agents |
| `agent-watch sessions` | fzf browser for sessions |
| `agent-watch watch [id]` | Live tail of agent output |

## Development

Single bash script. No build step. Test with `bash -n agent-watch` for syntax checks.
