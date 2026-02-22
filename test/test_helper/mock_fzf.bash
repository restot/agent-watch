#!/usr/bin/env bash
# Mock fzf for testing interactive modes.
# Reads stdin, selects line N (MOCK_FZF_SELECT, default 1).
# Outputs in --expect format: key line + selection line.
# MOCK_FZF_KEY: simulated key (empty=enter, alt-w, alt-f)
# MOCK_FZF_EXIT: set to 1 to simulate Escape (exit 1)
set +e

if [[ "${MOCK_FZF_EXIT:-}" == "1" ]]; then
    exit 1
fi

select_n="${MOCK_FZF_SELECT:-1}"
key="${MOCK_FZF_KEY:-}"

# Read all stdin lines
lines=()
while IFS= read -r line; do
    lines+=("$line")
done

if [[ ${#lines[@]} -eq 0 ]]; then
    exit 1
fi

# Select the Nth line (1-indexed)
idx=$((select_n - 1))
if [[ $idx -ge ${#lines[@]} ]]; then
    idx=$(( ${#lines[@]} - 1 ))
fi

# --expect format: first line is the key pressed, second line is the selection
echo "$key"
echo "${lines[$idx]}"
