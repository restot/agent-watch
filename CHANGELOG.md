# Changelog

## 1.2.1

- **Data-driven rendering** -- system and progress entries are rendered based on their data fields, not hardcoded subtypes. Any system entry with `hookInfos` shows each hook command and duration as `[HOOK]`. Other system entries render as `[SYSTEM]` with subtype and content. All progress entries render as `[HOOK]` with available metadata. Future Claude Code entry types will render automatically.

## 1.2.0

- **Compaction support** -- sessions that hit context limits now render correctly past compaction boundaries. `[COMPACT]` markers show when compaction occurred (auto/manual) and how many tokens were involved. Compaction summaries display as `[SUMMARY]` instead of `[USER]` so they're visually distinct from real user messages. Both full compaction (`compact_boundary`) and in-place microcompaction (`microcompact_boundary`) are supported.
- **Hook visibility** -- hook executions are now rendered as `[HOOK]` entries showing the hook event, name, and script (e.g. `SessionStart:startup → session-start.sh`). Stop hook summaries show how many hooks ran and whether any errored. Synthetic `callback` entries are filtered out to reduce noise.
- **New color tags** -- `[COMPACT]` (bold cyan), `[HOOK]` (dim yellow), `[SUMMARY]` (dim cyan) across all render paths: view, view full, watch, and fzf previews.
- **28 new tests** -- unit, integration, and e2e coverage for compaction boundaries, microcompaction, hook progress, stop hook summaries, callback filtering, and error flags.

## 1.1.5

- **Remove all content truncation** -- tool inputs, tool results, assistant text, and user text are no longer truncated in any render path (view, fzf preview). Previously tool inputs were cut at 200 chars, results at 100, and text at 300, which caused downstream consumers to miss Edit/Write content.

## 1.1.4

- **Bash 4+ auto-detection** -- on macOS where `/bin/bash` is 3.2, agent-watch now detects the outdated version at startup and re-execs itself under Homebrew bash (`/opt/homebrew/bin/bash` or `/usr/local/bin/bash`). If no suitable bash is found, it exits with a clear error and install instructions.

## 1.1.3

- **`NO_COLOR` support** -- respects the [NO_COLOR](https://no-color.org/) environment variable and adds a `--no-color` flag to disable ANSI color output. When calling agent-watch from agents, this avoids wasting tokens on escape codes. Colors are stripped from all output: metadata headers, role markers (`[USER]`, `[ASST]`, `[TOOL]`, `[RESULT]`), list/session views, and helper messages.
- **Docker test environment** -- added `Dockerfile` and `make docker-test` / `make docker-coverage` targets for running the full test suite and coverage analysis in Docker without installing dependencies locally.
- **Refactored color pipeline** -- deduplicated three copy-pasted sed pipelines into shared `_color_sed` / `_color_sed_u` helpers, reducing code and ensuring consistent behavior across `view`, `view full`, and `watch` modes.

## 1.1.2

- **Fix `--last N` reversing multi-line content** -- the `--last N` token-budget mode reversed all lines within messages because it used `_tac` on the rendered output. Multi-line assistant responses (tables, formatted text) appeared with lines in reverse order. Fixed by reading the file forward and using awk to collect message blocks, dropping oldest blocks until within the token budget.

## 1.1.1

- **Fix `--last` returning empty output** -- `view` and `view full` both called an undefined `__tac` function in the `--last` single-message branch, silently producing no output. Fixed to use the correct `_tac` helper.
- **Test coverage expansion** -- 110 tests (up from 79), adding coverage for `agent_pid_alive`, `view_agent_full`, interactive fzf modes (via mock fzf), tool rendering, active markers, and additional CLI flags. New test files: `test_agent_pid_alive`, `test_view_full`, `test_interactive`.
- **Coverage tool accuracy** -- `coverage.sh` now uses a state machine to exclude heredoc bodies, jq/awk program strings, and preview scripts from the executable-line count. Reported coverage reflects actual bash code (72%, up from 42% with inflated denominator).
- **Coverage badge** -- `coverage.sh` generates a shields.io-style SVG badge (`coverage-badge.svg`) with percentage and short SHA, displayed in the README.

## 1.1.0

- **`--last N` token budget** -- `--last` now accepts an optional token count (e.g. `--last 5000`) to show the last N tokens of a conversation. Messages are selected from the end and displayed in chronological order. `--last` without a number still shows the single last message.
- **Fix project name display** -- project names with dashes (e.g. `ai-voice`) were incorrectly split into `ai/voice`. Project names now display as raw directory names with the home prefix stripped, matching Claude CLI conventions.
- **Test suite** -- 79 tests across lint, unit, integration, and e2e suites using bats-core. CI runs on both Ubuntu and macOS to cover GNU/BSD differences.

## 1.0.7

- **`--last` flag** -- show only the last message from a session or agent log, with no header or pager. Works with `view`, `session`, and auto-detect ID commands.
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
