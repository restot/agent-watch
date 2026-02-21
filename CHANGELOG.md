# Changelog

## 1.0.6

- **Stop truncating project names** -- project names were hard-truncated to 30-40 chars in `list-sessions`, `sessions`, and agent fzf views, making long project paths unsearchable and indistinguishable. Removed all truncation so full project names display and match correctly.

## 1.0.5

- **Fix project filter on long paths** -- `list-sessions -p` filtered against the 30-char display-truncated project name, so long project paths were unsearchable. Filter now runs before truncation.

## 1.0.4

- **Fix interactive modes crashing** -- `sessions` and interactive agent selection (`agent-watch` with no args) silently exited when any session/agent file had incomplete JSON (e.g. active sessions). Replaced upfront preview generation with lazy on-demand previews via fzf `--preview`, fixing both the crash and making fzf appear instantly regardless of file count.
- **`view` and `watch` now work with sessions** -- previously only resolved sub-agent IDs. Now auto-detects agent or session ID, and no-arg defaults fall back to most recent session if no agents exist.
- **`list -p` project filter** -- `list` command now supports `-p`/`--project` for filtering agents by project name, matching `list-sessions`.

## 1.0.3

- **Fix self-update crash** -- `update` command was overwriting the running script mid-execution, causing bash to read corrupted content and error out. Now downloads to a temp file and atomically replaces via `mv`.

## 1.0.2

- **Configurable stale timeout** -- `AGENT_WATCH_STALE_TIMEOUT` env var to configure the JSONL staleness threshold for `wait` fallback (default: 300s)
- **Architecture diagram** -- excalidraw flowchart in README replacing mermaid
- **Core Features section** -- README restructured with dedicated feature descriptions
- **Wiki** -- [Token Log & PID Tracking setup guide](https://github.com/restot/agent-watch/wiki/Token-Log-Setup) documenting hooks, settings.json config, and agent PIDs
- **Documentation** -- clarified PID hook is required for robust `wait` behavior; split examples into interactive/non-interactive

## 1.0.1

- **Rich metadata in fzf previews** -- interactive session and agent selection now shows full metadata header (model, version, tokens, timestamps) in the preview panel
- **Self-update** -- `agent-watch update` downloads the latest release in place
- **Version check** -- `agent-watch version` / `-v` / `--version` shows current version and checks for updates
- **CLAUDE.md** -- copy-paste reference to teach your Claude Code agents how to use agent-watch
- **README improvements** -- curl-based install from GitHub releases, detailed `wait` command documentation, contributing guide
- **Wiki** -- [Token Log & PID Tracking setup guide](https://github.com/restot/agent-watch/wiki/Token-Log-Setup) for faster `wait` detection via Claude Code hooks

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
- **Wait for agents** -- `wait` command blocks until one or more sub-agents complete, using PID files and JSONL staleness as completion signals
- **Cross-platform support** -- BSD/GNU stat and date detection, portable shebang, dynamic home directory path handling
- **Dependency checking** -- startup check for jq, interactive-mode check for fzf
