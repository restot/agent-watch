
get_agent_files() {
    # Return 20 most recent agents, excluding prompt suggestions
    local files
    files=$(find "$PROJECTS_DIR" -path "*/subagents/agent-*.jsonl" -type f 2>/dev/null | grep -v "aprompt_suggestion" || true)
    [[ -n "$files" ]] && echo "$files" | xargs ls -t 2>/dev/null | head -20 || true
}

format_agent_line() {
    local filepath="$1"
    local agent_id project last_type msg_count mod_time status

    agent_id=$(basename "$filepath" .jsonl | sed 's/agent-//')
    local project_dir
    project_dir=$(echo "$filepath" | grep -oE '[^/]+/[^/]+/subagents' | cut -d'/' -f1)
    project="${project_dir#-${_HOME_PATTERN}}"
    project="${project#-}"
    [[ -z "$project" ]] && project="~"

    # Get last activity type
    last_type=$(tail -1 "$filepath" 2>/dev/null | jq -r '.type // "?"' 2>/dev/null) || last_type="?"

    # Get message count
    msg_count=$(wc -l < "$filepath" 2>/dev/null | tr -d ' ')

    # Get modification time
    mod_time=$(stat -f "%Sm" -t "%H:%M" "$filepath" 2>/dev/null || stat -c "%y" "$filepath" 2>/dev/null | cut -d' ' -f2 | cut -d':' -f1,2)

    # Check if still being written to (modified in last 30 seconds)
    local now mod_epoch
    now=$(date +%s)
    mod_epoch=$(stat -f "%m" "$filepath" 2>/dev/null || stat -c "%Y" "$filepath" 2>/dev/null)
    if [[ $((now - mod_epoch)) -lt 30 ]]; then
        status="●"  # Active
    else
        status=" "  # Inactive
    fi

    printf "%s|%s|%s|%s|%s|%s|%s\n" "$status" "$agent_id" "$mod_time" "$last_type" "$msg_count" "$project" "$filepath"
