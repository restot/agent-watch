show_usage() {
    cat <<EOF
Usage: agent-watch [command] [args] [flags]

Non-interactive commands (safe for agents):
  list [count]        List recent sub-agents (default: 20)
    -p, --project <name>  Filter by project (case-insensitive partial match)
  list-sessions [n]   List all sessions (or last n)
    -p, --project <name>  Filter by project (case-insensitive partial match)
  view [id]           View agent transcript (most recent if no id)
  session <id>        View a specific session
  <id>                Auto-detect: view agent or session by ID
  wait <id> [id...]   Block until agent(s) complete
  update              Self-update to the latest release

Interactive commands (require TTY):
  (none)              fzf selection of sub-agents
  sessions [id]       fzf browser for sessions (or view specific session by ID)
  watch [id]          Live tail of agent output

All views display a metadata header:
  Model, Version, Branch, Project, Started/Ended, Messages, Tokens
  Sub-agents also show Slug; Permission shown when available.

Message markers:
  [USER]     User messages          [TOOL]     Tool calls (name + input)
  [ASST]     Assistant responses    [RESULT]   Tool results
  [COMPACT]  Compaction boundary    [SUMMARY]  Post-compaction summary
  [HOOK]     Hook execution         (callbacks are filtered out)

Pagination (for large sessions/agents):
  --limit N           Token budget (chars/4); prints NEXT_OFFSET=M when exceeded
  --offset N          Skip first N messages (combine with --limit to paginate)
  --last [N]          Show last message, or last N tokens (no header, no pager)

Other flags:
  --skip-tool-output  Show tool calls and args but hide tool result output
  --no-color          Disable colored output (also respects NO_COLOR env var)
  --debug             Show debug output
  --help              Show this help message
  --version           Show version number

Environment:
  NO_COLOR                    Disable colored output (see https://no-color.org/)
  AGENT_WATCH_STALE_TIMEOUT   Staleness threshold in seconds for wait fallback (default: 300)

Examples:
  agent-watch                     # Interactive agent selection (fzf)
  agent-watch list                # List recent agents
  agent-watch list-sessions       # List all sessions
  agent-watch list-sessions 10    # List 10 most recent sessions
  agent-watch list-sessions -p oc # Filter sessions by project name
  agent-watch view                # View most recent agent transcript
  agent-watch abc123              # Auto-detect: view agent or session by ID
  agent-watch wait abc123 def456  # Wait for multiple agents to complete
  agent-watch sessions            # Browse sessions interactively (fzf)
  agent-watch watch               # Live tail most recent agent
  agent-watch abc123 --limit 5000               # Token-limited view
  agent-watch abc123 --offset 50 --limit 5000   # Paginate from message 50
EOF
}
