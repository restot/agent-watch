get_session_files() {
    # Return all main session JSONL files (not sub-agents), sorted by mtime
    local files
    files=$(find "$PROJECTS_DIR" -maxdepth 2 -name "*.jsonl" -type f 2>/dev/null | grep -vE '/subagents/' || true)
    [[ -n "$files" ]] && echo "$files" | xargs ls -t 2>/dev/null || true
}

# Batch-preload session metadata into associative arrays.
# Call once before loops that need session info. Populates:
#   _PROMPT[sessionId]  — first prompt (truncated, cleaned)
#   _STAT[filepath]     — "mm/dd HH:MM epoch"
#   _WC[filepath]       — message count
_preload_session_data() {
    local files_list="$1"

    # Batch prompts: single jq per index file
    declare -gA _PROMPT
    while IFS=$'\t' read -r sid prompt; do
        [[ -n "$sid" ]] && _PROMPT["$sid"]="$prompt"
    done < <(
        find "$PROJECTS_DIR" -maxdepth 2 -name "sessions-index.json" -type f 2>/dev/null | \
        xargs jq -r '.entries[] | [.sessionId, (.firstPrompt // "" | gsub("[\\n\\t]"; " ") | .[:60])] | @tsv' 2>/dev/null
    )

    # Batch stat: one call for all files → "filepath mm/dd HH:MM epoch"
    declare -gA _STAT
    while IFS= read -r line; do
        local fpath="${line%%.jsonl *}.jsonl"
        local rest="${line#*.jsonl }"
        _STAT["$fpath"]="$rest"
    done < <(
        if [[ "$_STAT_CMD" == "bsd" ]]; then
            echo "$files_list" | xargs stat -f "%N %Sm %m" -t "%m/%d %H:%M" 2>/dev/null
        else
            echo "$files_list" | xargs stat --printf="%n %y %Y\n" 2>/dev/null | \
                awk '{ split($2,d,"-"); split($3,t,":"); printf "%s %s/%s %s:%s %s\n", $1, d[2], d[3], t[1], t[2], $4 }'
        fi
    )

    # Batch wc -l: one call for all files
    declare -gA _WC
    local _wc_n _wc_f
    while read -r _wc_n _wc_f; do
        [[ "$_wc_f" == "total" ]] && continue
        [[ -n "$_wc_f" ]] && _WC["$_wc_f"]="${_wc_n## }"
    done < <(echo "$files_list" | xargs wc -l 2>/dev/null)
}

