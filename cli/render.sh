}

# Print rich metadata header from a session/agent JSONL file.
# Uses head/tail for speed, streams tokens with jq.
_print_metadata_header() {
    local filepath="$1"
    local label="$2"  # displayed as-is, e.g. "Agent: abc123" or "Session: abc123 (full)"

    # --- fast extracts: head for first user+assistant, tail for last entry ---
    local version="" cwd="" branch="" start="" slug="" perm="" model=""
    local end_time msg_count

    while IFS= read -r line; do
        case "$line" in
            U:*) IFS='|' read -r version cwd branch start slug perm <<< "${line#U:}" ;;
            A:*) model="${line#A:}" ;;
        esac
    done < <(head -15 "$filepath" | jq -r '
        if .type == "user" then
            "U:" + (.version // "?") + "|" + (.cwd // "?") + "|" + (.gitBranch // "?") + "|" + (.timestamp // "?") + "|" + (.slug // "") + "|" + (.permissionMode // "?")
        elif .type == "assistant" then
            "A:" + (.message.model // "?")
        else empty end
    ' 2>/dev/null)

    end_time=$(tail -1 "$filepath" | jq -r '.timestamp // "?"' 2>/dev/null) || end_time="?"
    msg_count=$(wc -l < "$filepath" | tr -d ' ')

    # --- token totals (streaming jq, no slurp) ---
    local tok_in=0 tok_out=0 tok_cache_r=0 tok_cache_w=0
    while IFS=$'\t' read -r ti to cr cw; do
        ((tok_in += ti)) || true
        ((tok_out += to)) || true
        ((tok_cache_r += cr)) || true
        ((tok_cache_w += cw)) || true
    done < <(jq -r 'select(.type == "assistant") | .message.usage // empty |
        [(.input_tokens // 0), (.output_tokens // 0), (.cache_read_input_tokens // 0), (.cache_creation_input_tokens // 0)] | @tsv
    ' "$filepath" 2>/dev/null)

    # --- format timestamps: "02/16 23:05" style ---
    local start_fmt="$start" end_fmt="$end_time"
    if [[ "$start" == *T* ]]; then
        if [[ "$_STAT_CMD" == "bsd" ]]; then
            start_fmt=$(date -jf "%Y-%m-%dT%H:%M:%S" "${start%%.*}" "+%m/%d %H:%M" 2>/dev/null || echo "$start")
        else
            start_fmt=$(date -d "${start%%.*}" "+%m/%d %H:%M" 2>/dev/null || echo "$start")
        fi
    fi
    if [[ "$end_time" == *T* ]]; then
        if [[ "$_STAT_CMD" == "bsd" ]]; then
            end_fmt=$(date -jf "%Y-%m-%dT%H:%M:%S" "${end_time%%.*}" "+%m/%d %H:%M" 2>/dev/null || echo "$end_time")
        else
            end_fmt=$(date -d "${end_time%%.*}" "+%m/%d %H:%M" 2>/dev/null || echo "$end_time")
        fi
    fi

    # --- print ---
    # --- detect if sub-agent ---
    local is_subagent=""
    [[ "$filepath" == *"/subagents/"* ]] && is_subagent=1

    echo -e "${CYAN}${label}${NC}"
    echo -e "${DIM}Model:      ${NC}${model}"
    echo -e "${DIM}Version:    ${NC}${version}"
    echo -e "${DIM}Branch:     ${NC}${branch}"
    echo -e "${DIM}Project:    ${NC}${cwd}"
    [[ -n "$is_subagent" && -n "$slug" ]] && echo -e "${DIM}Slug:       ${NC}${slug}"
    [[ -n "$perm" && "$perm" != "?" ]] && echo -e "${DIM}Permission: ${NC}${perm}"
    echo -e "${DIM}Started:    ${NC}${start_fmt}"
    echo -e "${DIM}Ended:      ${NC}${end_fmt}"
    echo -e "${DIM}Messages:   ${NC}${msg_count}"
    echo -e "${DIM}Tokens:     ${NC}$(_fmt_tokens $tok_in) in / $(_fmt_tokens $tok_out) out  ${DIM}(cache: $(_fmt_tokens $tok_cache_r) read, $(_fmt_tokens $tok_cache_w) created)${NC}"
    echo -e "${DIM}───────────────────────────────────────${NC}"
    echo ""
}
