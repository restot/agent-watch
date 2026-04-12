cmd_sessions() {
    local input="${1:-}"

    # If a session ID is provided, view it directly
    if [[ -n "$input" ]]; then
        local filepath
        if [[ -f "$input" ]]; then
            filepath="$input"
        else
            filepath=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${input}*.jsonl" -type f 2>/dev/null | grep -v '/subagents/' | head -1)
            if [[ -z "$filepath" ]]; then
                die "Session $input not found"
            fi
        fi
        view_agent "$filepath"
        return
    fi

    command -v fzf >/dev/null 2>&1 || die "Required for interactive mode: fzf (https://github.com/junegunn/fzf)"

    local files
    files=$(get_session_files)

    if [[ -z "$files" ]]; then
        die "No sessions found"
    fi

    # Batch preload all metadata
    _preload_session_data "$files"
    local now
    now=$(date +%s)

    # Preview script for fzf (runs on-demand per item, not upfront for all)
    local preview_script
    preview_script=$(mktemp)
    trap "rm -f '$preview_script'" EXIT
    cat > "$preview_script" << 'PREVIEW_SCRIPT'
#!/usr/bin/env bash
set +e
f="$1"
sid=$(basename "$f" .jsonl)
msgs=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
echo -e "\033[0;36mSession: $sid\033[0m"
echo -e "\033[2mMessages:   \033[0m${msgs}"
echo -e "\033[2m───────────────────────────────────────\033[0m"
echo ""
head -30 "$f" 2>/dev/null | jq -r '
    if .type == "user" then
        if .isCompactSummary then
            "\u001b[2;36m[SUMMARY]\u001b[0m " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
        else
            "\u001b[0;32m[USER]\u001b[0m " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
        end
    elif .type == "assistant" then
        (.message.content // [])[] |
        if .type == "text" then
            "\u001b[0;35m[ASST]\u001b[0m " + .text
        elif .type == "tool_use" then
            "\u001b[0;34m[TOOL]\u001b[0m \u001b[0;33m" + .name + "\u001b[0m " + (.input | tostring)
        else empty end
    elif .type == "system" then
        if .subtype == "compact_boundary" or .subtype == "microcompact_boundary" then
            "\u001b[1;36m[COMPACT]\u001b[0m " + (.content // "")
        elif ((.hookInfos // []) | length) > 0 then
            (.hookInfos[] | "\u001b[2;33m[HOOK]\u001b[0m " + ((.command // "") | split("/") | .[-3:] | join("/")) + " (" + ((.durationMs // 0) | tostring) + "ms)")
        else
            "\u001b[2m[SYSTEM]\u001b[0m " + (.subtype // "system") + (if .content then ": " + (.content | tostring) else "" end)
        end
    elif .type == "progress" then
        if .data.command == "callback" then empty
        elif .data.hookName then
            "\u001b[2;33m[HOOK]\u001b[0m " + .data.hookName + " \u2192 " + ((.data.command // "") | split("/") | last)
        else
            "\u001b[2;33m[HOOK]\u001b[0m " + (.data.type // "progress")
        end
    else empty end
' 2>/dev/null
PREVIEW_SCRIPT
    chmod +x "$preview_script"

    local fzf_out key selection filepath
    fzf_out=$(while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        local session_id="${filepath##*/}"
        session_id="${session_id%.jsonl}"
        local short_id="${session_id:0:8}"
        local dir="${filepath%/*}"
        local project_dir="${dir##*/}"

        local first_prompt="${_PROMPT[$session_id]:-}"
        local msg_count="${_WC[$filepath]:-0}"
        msg_count="${msg_count## }"

        local stat_data="${_STAT[$filepath]:-}"
        local mod_date mod_time mod_epoch st
        if [[ -n "$stat_data" ]]; then
            mod_date="${stat_data%% *}"
            local rest="${stat_data#* }"
            mod_time="${rest%% *}"
            mod_epoch="${rest#* }"
        else
            mod_date="??/??"; mod_time="??:??"; mod_epoch=0
        fi
        [[ $((now - mod_epoch)) -lt 30 ]] && st="●" || st=" "

        local project_name="${project_dir#-${_HOME_PATTERN}}"
        project_name="${project_name#-}"
        [[ -z "$project_name" ]] && project_name="~"

        printf "%-1s %-8s  %-11s  %4s  %-30s  %-60s\t%s\n" \
            "$st" "$short_id" "$mod_date $mod_time" "$msg_count" "$project_name" "$first_prompt" "$filepath"
    done <<< "$files" | \
        fzf --ansi \
            --delimiter='\t' \
            --header="enter=watch | alt-w=view | alt-f=full" \
            --preview="$preview_script {2}" \
            --preview-window=right:50% \
            --expect=alt-w,alt-f \
            --with-nth=1) || exit 0

    key=$(echo "$fzf_out" | head -1)
    selection=$(echo "$fzf_out" | sed -n '2p')

    [[ -z "$selection" ]] && exit 0

    filepath=$(echo "$selection" | cut -d$'\t' -f2)

    [[ ! -f "$filepath" ]] && die "Session file not found: $filepath"

    # Clean up
    rm -f "$preview_script"
    trap - EXIT

    if [[ "$key" == "alt-w" ]]; then
        view_agent "$filepath"
    elif [[ "$key" == "alt-f" ]]; then
        view_agent_full "$filepath"
    else
        watch_agent "$filepath" < /dev/tty
    fi
}


cmd_interactive() {
    command -v fzf >/dev/null 2>&1 || die "Required for interactive mode: fzf (https://github.com/junegunn/fzf)"

    local files
    files=$(get_agent_files)

    if [[ -z "$files" ]]; then
        die "No sub-agents found"
    fi

    # Preview script for fzf (runs on-demand per item, not upfront for all)
    local preview_script
    preview_script=$(mktemp)
    trap "rm -f '$preview_script'" EXIT
    cat > "$preview_script" << 'PREVIEW_SCRIPT'
#!/usr/bin/env bash
set +e
f="$1"
aid=$(basename "$f" .jsonl | sed 's/agent-//')
msgs=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
echo -e "\033[0;36mAgent: $aid\033[0m"
echo -e "\033[2mMessages:   \033[0m${msgs}"
echo -e "\033[2m───────────────────────────────────────\033[0m"
echo ""
head -30 "$f" 2>/dev/null | jq -r '
    if .type == "user" then
        if .isCompactSummary then
            "\u001b[2;36m[SUMMARY]\u001b[0m " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
        else
            "\u001b[0;32m[USER]\u001b[0m " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
        end
    elif .type == "assistant" then
        (.message.content // [])[] |
        if .type == "text" then
            "\u001b[0;35m[ASST]\u001b[0m " + .text
        elif .type == "tool_use" then
            "\u001b[0;34m[TOOL]\u001b[0m \u001b[0;33m" + .name + "\u001b[0m " + (.input | tostring)
        else empty end
    elif .type == "system" then
        if .subtype == "compact_boundary" or .subtype == "microcompact_boundary" then
            "\u001b[1;36m[COMPACT]\u001b[0m " + (.content // "")
        elif ((.hookInfos // []) | length) > 0 then
            (.hookInfos[] | "\u001b[2;33m[HOOK]\u001b[0m " + ((.command // "") | split("/") | .[-3:] | join("/")) + " (" + ((.durationMs // 0) | tostring) + "ms)")
        else
            "\u001b[2m[SYSTEM]\u001b[0m " + (.subtype // "system") + (if .content then ": " + (.content | tostring) else "" end)
        end
    elif .type == "progress" then
        if .data.command == "callback" then empty
        elif .data.hookName then
            "\u001b[2;33m[HOOK]\u001b[0m " + .data.hookName + " \u2192 " + ((.data.command // "") | split("/") | last)
        else
            "\u001b[2;33m[HOOK]\u001b[0m " + (.data.type // "progress")
        end
    else empty end
' 2>/dev/null
PREVIEW_SCRIPT
    chmod +x "$preview_script"

    local fzf_out key selection filepath
    fzf_out=$(echo "$files" | while read -r filepath; do
        [[ -z "$filepath" ]] && continue

        local agent_id project last_type msg_count mod_time st
        agent_id=$(basename "$filepath" .jsonl | sed 's/agent-//')
        local project_dir
        project_dir=$(echo "$filepath" | grep -oE '[^/]+/[^/]+/subagents' | cut -d'/' -f1)
        project="${project_dir#-${_HOME_PATTERN}}"
        project="${project#-}"
        [[ -z "$project" ]] && project="~"
        last_type=$(tail -1 "$filepath" 2>/dev/null | jq -r '.type // "?"' 2>/dev/null) || last_type="?"
        msg_count=$(wc -l < "$filepath" 2>/dev/null | tr -d ' ')
        mod_time=$(stat -f "%Sm" -t "%H:%M" "$filepath" 2>/dev/null || stat -c "%y" "$filepath" 2>/dev/null | cut -d' ' -f2 | cut -d':' -f1,2)

        local now mod_epoch
        now=$(date +%s)
        mod_epoch=$(stat -f "%m" "$filepath" 2>/dev/null || stat -c "%Y" "$filepath" 2>/dev/null)
        [[ $((now - mod_epoch)) -lt 30 ]] && st="●" || st=" "

        printf "%-1s %-9s %-5s %-10s %4s  %-40s\t%s\n" "$st" "$agent_id" "$mod_time" "$last_type" "$msg_count" "$project" "$filepath"
    done | \
        fzf --ansi \
            --delimiter='\t' \
            --header="enter=watch | alt-w=view | alt-f=full" \
            --preview="$preview_script {2}" \
            --preview-window=right:50% \
            --expect=alt-w,alt-f \
            --with-nth=1) || exit 0

    key=$(echo "$fzf_out" | head -1)
    selection=$(echo "$fzf_out" | sed -n '2p')

    debug " key=[$key]"
    debug " selection=[$selection]"

    [[ -z "$selection" ]] && exit 0

    filepath=$(echo "$selection" | cut -d$'\t' -f2)
    debug " filepath=[$filepath]"

    [[ ! -f "$filepath" ]] && die "Agent file not found: $filepath"

    # Clean up
    rm -f "$preview_script"
    trap - EXIT

    if [[ "$key" == "alt-w" ]]; then
        view_agent "$filepath"
    elif [[ "$key" == "alt-f" ]]; then
        view_agent_full "$filepath"
    else
        debug " calling watch_agent"
        watch_agent "$filepath" < /dev/tty
    fi
}

