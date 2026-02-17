# agent-watch

CLI tool for monitoring and browsing Claude Code sub-agent and session transcripts.

## What it does

- Browse and search Claude Code session history and sub-agent transcripts
- Rich metadata headers showing model, version, branch, project, timestamps, message count, token usage
- Interactive fzf-based selection with previews
- Non-interactive commands safe for use by Claude Code agents themselves
- Live tailing of active sub-agents
- Pagination with token budgets for large sessions (`--limit`/`--offset`)
- Auto-detection of agent vs session IDs
- Wait for sub-agent completion -- block until agents finish using PID tracking, token logs, and JSONL staleness detection

## Installation

### Dependencies

- **bash 4+** (macOS ships bash 3 -- install via `brew install bash`)
- **jq** -- JSON parsing (`brew install jq`)
- **fzf** -- interactive selection and previews (`brew install fzf`), only needed for interactive mode
- **bc** -- token formatting (optional, usually pre-installed)

### Install

```sh
curl -fsSL https://github.com/restot/agent-watch/releases/latest/download/agent-watch \
  -o ~/.local/bin/agent-watch && chmod +x ~/.local/bin/agent-watch
```

Verify it's in your `PATH`:

```sh
which agent-watch
```

If not found:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.$(basename "$SHELL")rc
```

Restart your shell or run `exec $SHELL` to apply.

## Usage

```
Usage: agent-watch [flags] [command] [args]

Non-interactive commands (safe for agents):
  list [count]        List recent sub-agents (default: 20)
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

Pagination (for large sessions/agents):
  --limit N           Token budget (chars/4); prints NEXT_OFFSET=M when exceeded
  --offset N          Skip first N messages (combine with --limit to paginate)

Other flags:
  --debug             Show debug output
  --help              Show this help message
  --version           Show version
```

## Examples

List the 10 most recent sub-agents:

```sh
agent-watch list 10
```

View the most recent agent transcript:

```sh
agent-watch view
```

View a specific session or agent by ID (auto-detected):

```sh
agent-watch abc123de
```

Filter sessions by project name:

```sh
agent-watch list-sessions -p my-project
```

Paginate through a large session:

```sh
agent-watch session abc123de --limit 5000
# Output includes NEXT_OFFSET=M if truncated
agent-watch session abc123de --offset 50 --limit 5000
```

Wait for sub-agents to finish before continuing:

```sh
agent-watch wait abc123 def456
```

The `wait` command is a core feature for orchestrating parallel sub-agent workflows. It blocks until all specified agents complete, using three detection methods in order:

1. **Token log** -- checks `~/.claude/subagent-tokens.log` for hook-based completion entries
2. **PID liveness** -- verifies the Claude process is still running via PID files in `~/.claude/.agent-pids/`
3. **JSONL staleness** -- falls back to checking if the agent's JSONL file hasn't been modified for 5 minutes (for agents without PID tracking)

This enables patterns like launching multiple agents in parallel, then waiting for all of them before proceeding:

```sh
# In a Claude Code session, launch agents then:
agent-watch wait abc123 def456 ghi789
# Continues only after all three complete
```

Browse sessions interactively with fzf:

```sh
agent-watch sessions
```

Live tail an active sub-agent:

```sh
agent-watch watch
```

## How it works

agent-watch reads Claude Code's JSONL session and agent files from `~/.claude/projects/`. It parses metadata from the first few entries in each file (model, version, branch, timestamps) and aggregates token usage across all assistant entries.

JSON parsing is handled by jq. Interactive selection uses fzf with preview windows that show session metadata and recent messages. Output is colorized with role-based markers (`[USER]`, `[ASST]`, `[TOOL]`, `[RESULT]`) for readability.


## Contributing

1. Fork the repo
2. Create a branch (`git checkout -b my-feature`)
3. Make your changes to the `agent-watch` script
4. Verify syntax: `bash -n agent-watch`
5. Test against real session/agent files
6. Submit a PR

Keep changes minimal and focused. This is a single-file tool -- no build step, no dependencies beyond bash/jq/fzf.

## License

MIT
