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
| `--last [N]` | Show last message, or last N tokens (no header, no pager) |
| `--skip-tool-output` | Show tool calls and args but hide tool result output |

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

Source modules live in `cli/`, assembled by `build.sh` into `bin/agent-watch`.

```
cli/
  header.sh       — shebang, globals, bash 4+ check, dependency checks
  core.sh         — colors, _color_sed, die/debug/info, _fmt_tokens
  agents.sh       — get_agent_files, format_agent_line
  render.sh       — _print_metadata_header
  sessions.sh     — get_session_files, _preload_session_data
  view.sh         — view_agent, view_agent_full
  watch.sh        — watch_agent
  list.sh         — cmd_list, cmd_list_sessions
  interactive.sh  — cmd_sessions (fzf), cmd_interactive (fzf)
  commands.sh     — _resolve_id, cmd_view, cmd_watch, cmd_wait
  help.sh         — show_usage
  main.sh         — arg parsing + dispatch
```

Build: `./build.sh` (runs `bash -n` syntax check automatically).
Root `agent-watch` is the legacy monolith; `bin/agent-watch` is the build output.
