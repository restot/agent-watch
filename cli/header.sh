#!/usr/bin/env bash
# Interactive sub-agent & session manager
# Usage: agent-watch [command] [args]
#   agent-watch              - Interactive selection + watch
#   agent-watch list         - List all agents
#   agent-watch watch [id]   - Watch specific agent
#   agent-watch wait <ids>   - Wait for agents to complete
#   agent-watch sessions     - Browse main agent sessions

# Require bash 4+ (for associative arrays). Re-exec under Homebrew bash if needed.
if ((BASH_VERSINFO[0] < 4)); then
    for _candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$_candidate" ]] && "$_candidate" -c '((BASH_VERSINFO[0]>=4))' 2>/dev/null; then
            exec "$_candidate" "$0" "$@"
        fi
    done
    echo "agent-watch: requires bash 4+ (found $BASH_VERSION). Install with: brew install bash" >&2
    exit 1
fi

set -euo pipefail

VERSION="1.3.0"
PROJECTS_DIR="$HOME/.claude/projects"
DEBUG=0
OFFSET=0
LIMIT=0
LAST=0
SKIP_TOOL_OUTPUT=0

# Home dir as it appears in Claude's project directory names (path separators become dashes)
_HOME_PATTERN="${HOME//\//-}"
_HOME_PATTERN="${_HOME_PATTERN#-}"  # strip leading dash

# Detect stat flavor (BSD vs GNU)
if stat -f "%N" /dev/null >/dev/null 2>&1; then
    _STAT_CMD="bsd"
else
    _STAT_CMD="gnu"
fi

# Portable tac (GNU has tac, BSD/macOS has tail -r)
if command -v tac >/dev/null 2>&1; then
    _tac() { tac "$@"; }
else
    _tac() { tail -r "$@"; }
fi

# Required dependencies
command -v jq >/dev/null 2>&1 || { echo "Error: Required: jq (https://jqlang.github.io/jq/)"; exit 1; }

# Colors — disabled by NO_COLOR env var (https://no-color.org/) or --no-color flag
if [[ -n "${NO_COLOR:-}" ]]; then
    _COLOR=0
else
    _COLOR=1
fi
