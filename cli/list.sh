cmd_list() {
    local count=20
    local project_filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--project) project_filter="$2"; shift 2 ;;
            *) count="$1"; shift ;;
        esac
    done

    if [[ -n "$project_filter" ]]; then
        echo -e "${BLUE}Sub-agents for project matching '${project_filter}' (newest first):${NC}"
    else
        echo -e "${BLUE}Recent sub-agents (newest first):${NC}"
    fi
    echo ""
    printf "%-3s %-10s %-6s %-12s %-6s %s\n" "" "AGENT" "TIME" "LAST" "MSGS" "PROJECT"
    printf "%-3s %-10s %-6s %-12s %-6s %s\n" "─" "──────────" "─────" "──────────" "────" "───────"

    local printed=0
    get_agent_files | while read -r filepath; do
        [[ -z "$filepath" ]] && continue
        [[ $printed -ge $count ]] && break
        local line
        line=$(format_agent_line "$filepath")
        local status agent_id mod_time last_type msg_count project
        IFS='|' read -r status agent_id mod_time last_type msg_count project _ <<< "$line"

        # Filter by project (case-insensitive)
        if [[ -n "$project_filter" ]]; then
            [[ "${project,,}" != *"${project_filter,,}"* ]] && continue
        fi

        if [[ "$status" == "●" ]]; then
            printf "${GREEN}%-3s${NC} %-10s %-6s %-12s %-6s %s\n" "$status" "$agent_id" "$mod_time" "[$last_type]" "$msg_count" "$project"
        else
            printf "%-3s %-10s %-6s %-12s %-6s %s\n" "$status" "$agent_id" "$mod_time" "[$last_type]" "$msg_count" "$project"
        fi
        ((printed++)) || true
    done
}

cmd_list_sessions() {
    local count=0
    local project_filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--project) project_filter="$2"; shift 2 ;;
            *) count="$1"; shift ;;
        esac
    done

    if [[ -n "$project_filter" ]]; then
        echo -e "${BLUE}Sessions for project matching '${project_filter}' (newest first):${NC}"
    else
        echo -e "${BLUE}Recent sessions (newest first):${NC}"
    fi
    echo ""
    printf "%-3s %-10s %-13s %-6s %-30s  %s\n" "" "SESSION" "DATE" "MSGS" "PROJECT" "PROMPT"
    printf "%-3s %-10s %-13s %-6s %-30s  %s\n" "─" "────────" "─────────────" "────" "──────────────────────────────" "──────"

    local files
    files=$(get_session_files)

    if [[ -z "$files" ]]; then
        echo "  (no sessions found)"
        return
    fi

    # Batch preload all metadata (~6 subprocesses instead of ~20/session)
    _preload_session_data "$files"
    local now
    now=$(date +%s)

    # Pure-bash formatting loop (zero subprocesses per iteration)
    local printed=0
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue
        [[ $count -gt 0 && $printed -ge $count ]] && break

        local session_id="${filepath##*/}"
        session_id="${session_id%.jsonl}"
        local short_id="${session_id:0:8}"
        local dir="${filepath%/*}"
        local project_dir="${dir##*/}"

        local first_prompt="${_PROMPT[$session_id]:-}"
        local msg_count="${_WC[$filepath]:-0}"
        msg_count="${msg_count## }"

        local stat_data="${_STAT[$filepath]:-}"
        local mod_date mod_time mod_epoch
        if [[ -n "$stat_data" ]]; then
            mod_date="${stat_data%% *}"
            local rest="${stat_data#* }"
            mod_time="${rest%% *}"
            mod_epoch="${rest#* }"
        else
            mod_date="??/??"; mod_time="??:??"; mod_epoch=0
        fi

        local status=" "
        [[ $((now - mod_epoch)) -lt 30 ]] && status="●"

        local project_name="${project_dir#-${_HOME_PATTERN}}"
        project_name="${project_name#-}"
        [[ -z "$project_name" ]] && project_name="~"

        # Filter by project (case-insensitive partial match)
        if [[ -n "$project_filter" ]]; then
            [[ "${project_name,,}" != *"${project_filter,,}"* ]] && continue
        fi

        local datetime="$mod_date $mod_time"
        if [[ "$status" == "●" ]]; then
            printf "${GREEN}%-3s${NC} %-10s %-13s %4s  %-30s  %s\n" \
                "$status" "$short_id" "$datetime" "$msg_count" "$project_name" "$first_prompt"
        else
            printf "%-3s %-10s %-13s %4s  %-30s  %s\n" \
                "$status" "$short_id" "$datetime" "$msg_count" "$project_name" "$first_prompt"
        fi
        ((printed++)) || true
    done <<< "$files"
}

