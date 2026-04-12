#!/usr/bin/env bash
# Build bin/agent-watch from cli/ source modules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$SCRIPT_DIR/cli"
OUTPUT="$SCRIPT_DIR/bin/agent-watch"

# Concatenation order matters: header first, core before commands, main last
MODULES=(
  header.sh
  core.sh
  agents.sh
  render.sh
  sessions.sh
  view.sh
  watch.sh
  list.sh
  interactive.sh
  commands.sh
  help.sh
  main.sh
)

# Build
{
  first=true
  for mod in "${MODULES[@]}"; do
    src="$CLI_DIR/$mod"
    [[ -f "$src" ]] || { echo "Missing: $src" >&2; exit 1; }

    if $first; then
      # Include shebang from header
      cat "$src"
      first=false
    else
      # Skip shebang lines in non-header modules, add blank line separator
      echo ""
      sed '/^#!/d' "$src"
    fi
  done
} > "$OUTPUT"

chmod +x "$OUTPUT"

# Verify syntax
if bash -n "$OUTPUT"; then
  lines=$(wc -l < "$OUTPUT" | tr -d ' ')
  echo "Built $OUTPUT ($lines lines)"
else
  echo "Syntax error in $OUTPUT" >&2
  exit 1
fi
