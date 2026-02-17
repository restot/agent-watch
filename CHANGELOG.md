# Changelog

## 1.0.0

Initial release.

### Features

- **Session and agent browsing** -- view, search, and paginate through Claude Code session history and sub-agent transcripts
- **Rich metadata headers** -- all views display model, version, branch, project, timestamps, message count, and token usage breakdown (input/output/cache)
- **Interactive mode** -- fzf-based selection with preview panels showing metadata and first exchanges for both sessions and agents
- **Non-interactive commands** -- `list`, `list-sessions`, `view`, `session`, `wait`, and auto-detect by ID -- safe for use by Claude Code agents
- **Live tailing** -- `watch` command streams agent output in real-time with colorized role markers
- **Pagination** -- `--limit` (token budget) and `--offset` for navigating large sessions without loading everything into memory
- **Session filtering** -- `list-sessions -p <name>` filters by project name (case-insensitive partial match)
- **Wait for agents** -- `wait` command blocks until one or more sub-agents complete, using PID files, token log entries, and JSONL staleness as completion signals
- **Cross-platform support** -- BSD/GNU stat and date detection, portable shebang, dynamic home directory path handling
- **Dependency checking** -- startup check for jq, interactive-mode check for fzf
