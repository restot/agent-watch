
view_agent() {
    local filepath="$1"
    local agent_id
    agent_id=$(basename "$filepath" .jsonl | sed 's/agent-//')

    # Extract working dir from first file path in content (look for /app/, /spec/, etc.)
    local workdir workdir_escaped match
    match=$(grep -oE "${HOME}/[^\"\\\\]+/(app|spec|lib|src|test)/" "$filepath" 2>/dev/null | head -1 || true)
    workdir=$(echo "$match" | sed 's|/app/$||;s|/spec/$||;s|/lib/$||;s|/src/$||;s|/test/$||' || true)
    [[ -z "$workdir" ]] && workdir=""
    workdir_escaped=$(printf '%s' "$workdir" | sed 's/[\/&]/\\&/g' || true)

    # Prepare LIMIT marker for jq
    local mark=""
    [[ "$LIMIT" -gt 0 || "$LAST" -gt 1 ]] && mark="yes"

    # Inner render pipeline: offset input -> jq -> workdir strip -> color seds
    _render() {
        if [[ "$LAST" -eq 1 ]]; then
            local _select_types='select(.type == "user" or .type == "assistant" or .type == "tool_result")'
            [[ "$SKIP_TOOL_OUTPUT" -eq 1 ]] && _select_types='select(.type == "user" or .type == "assistant")'
            _tac "$filepath" 2>/dev/null | jq -c "$_select_types" 2>/dev/null | head -1 || true
        elif [[ "$LAST" -gt 1 ]]; then
            cat "$filepath"
        elif [[ "$OFFSET" -gt 0 ]]; then
            tail -n +"$((OFFSET + 1))" "$filepath"
        else
            cat "$filepath"
        fi | \
        jq -r --arg mark "$mark" --arg skip_tool "$SKIP_TOOL_OUTPUT" '
            (if $mark != "" then "@@MSG@@" else empty end),
            if .type == "user" then
                if .isCompactSummary then
                    "@@SUMMARY@@ " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
                else
                    "@@USER@@ " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
                end
            elif .type == "assistant" then
                (.message.content // [])[] |
                if .type == "tool_use" then
                    (.input | tostring) as $inp |
                    "@@TOOL@@ \(.name) @@TOOLEND@@ " + $inp
                elif .type == "text" then
                    "@@ASST@@ " + .text
                else empty end
            elif .type == "tool_result" then
                if $skip_tool == "1" then empty
                else ((.content[0].text // .content // "") | tostring) as $res |
                "@@RESULT@@ " + $res end
            elif .type == "system" then
                if .subtype == "compact_boundary" then
                    "@@COMPACT@@ Conversation compacted (" + (.compactMetadata.trigger // "unknown") + ", " + ((.compactMetadata.preTokens // 0) | tostring) + " tokens before)"
                elif .subtype == "microcompact_boundary" then
                    "@@COMPACT@@ Context microcompacted (" + (.microcompactMetadata.trigger // "auto") + ", saved " + ((.microcompactMetadata.tokensSaved // 0) | tostring) + " tokens)"
                elif ((.hookInfos // []) | length) > 0 then
                    ((.hookInfos // [])[] | "@@HOOK@@ " + ((.command // "") | split("/") | .[-3:] | join("/")) + " (" + ((.durationMs // 0) | tostring) + "ms)"),
                    (if ((.hookErrors // []) | length) > 0 then "@@HOOK@@ [ERRORS]: " + ((.hookErrors // []) | join(", ")) else empty end)
                else
                    "@@SYSTEM@@ " + (.subtype // "system") + (if .content then ": " + (.content | tostring) else "" end)
                end
            elif .type == "progress" then
                if .data.command == "callback" then empty
                elif .data.hookName then
                    "@@HOOK@@ " + .data.hookName + " \u2192 " + ((.data.command // "") | split("/") | last)
                else
                    "@@HOOK@@ " + (.data.type // "progress")
                end
            elif .type == "queue-operation" and .operation == "enqueue" and .content then
                .content as $c |
                if ($c | test("<task-notification>")) then
                    "@@HOOK@@ enqueue: " + (($c | capture("<summary>(?<t>[^<]+)</summary>") | .t) // "task-notification")
                elif ($c | test("<teammate-message")) then
                    "@@HOOK@@ enqueue: " + (($c | capture("teammate_id=\"(?<id>[^\"]+)\"") | .id) // "teammate") + (($c | capture("summary=\"(?<s>[^\"]+)\"") | ": " + .s) // "")
                elif ($c | test("FileChanged")) then
                    "@@HOOK@@ enqueue: FileChanged"
                elif ($c | test("<system-reminder>")) then
                    "@@HOOK@@ enqueue: system-reminder"
                else
                    "@@HOOK@@ enqueue: " + ($c | split("\n") | .[0] | .[:80])
                end
            else empty end
        ' 2>/dev/null | \
        if [[ -n "$workdir_escaped" ]]; then sed "s/$workdir_escaped\///g"; else cat; fi | \
        _color_sed
    }

    # Determine label
    local is_agent=""
    [[ "$filepath" == *"/subagents/"* ]] && is_agent=1
    local header_label
    if [[ -n "$is_agent" ]]; then
        header_label="Agent: $agent_id"
    else
        header_label="Session: $agent_id"
    fi

    if [[ "$LAST" -eq 1 ]]; then
        # Last message only, no header, no pager
        _render
    elif [[ "$LAST" -gt 1 ]]; then
        # Last N tokens, chronological order, no header, no pager
        _render | awk -v limit="$LAST" '
            BEGIN { bc = 0; cur = ""; bt = 0; total = 0 }
            /^@@MSG@@$/ {
                if (cur != "") { blocks[++bc] = cur; btok[bc] = bt; total += bt }
                cur = ""; bt = 0; next
            }
            { cur = (cur == "" ? $0 : cur "\n" $0); bt += int(length / 4) }
            END {
                if (cur != "") { blocks[++bc] = cur; btok[bc] = bt; total += bt }
                s = 1
                while (s < bc && total > limit) { total -= btok[s]; s++ }
                for (i = s; i <= bc; i++) print blocks[i]
            }
        '
    elif [[ "$LIMIT" -gt 0 ]]; then
        # Direct output with token counting (no pager)
        {
            _print_metadata_header "$filepath" "$header_label"
            _render
        } | awk -v limit="$LIMIT" -v offset="$OFFSET" '
            BEGIN { tokens = 0; msgs = 0; exceeded = 0; done = 0 }
            /^@@MSG@@$/ {
                if (exceeded) {
                    printf "NEXT_OFFSET=%d\n", offset + msgs
                    done = 1
                    exit 0
                }
                msgs++
                next
            }
            {
                print
                tokens += int(length / 4)
                if (tokens >= limit) { exceeded = 1 }
            }
            END {
                if (exceeded && !done) {
                    printf "NEXT_OFFSET=%d\n", offset + msgs
                }
            }
        ' || true
    else
        # Standard mode with pager
        {
            _print_metadata_header "$filepath" "$header_label"
            _render
        } | less -R
    fi
}

view_agent_full() {
    local filepath="$1"
    local agent_id
    agent_id=$(basename "$filepath" .jsonl | sed 's/agent-//')

    # Extract working dir from first file path in content
    local workdir workdir_escaped match
    match=$(grep -oE "${HOME}/[^\"\\\\]+/(app|spec|lib|src|test)/" "$filepath" 2>/dev/null | head -1 || true)
    workdir=$(echo "$match" | sed 's|/app/$||;s|/spec/$||;s|/lib/$||;s|/src/$||;s|/test/$||' || true)
    [[ -z "$workdir" ]] && workdir=""
    workdir_escaped=$(printf '%s' "$workdir" | sed 's/[\/&]/\\&/g' || true)

    # Prepare LIMIT marker for jq
    local mark=""
    [[ "$LIMIT" -gt 0 || "$LAST" -gt 1 ]] && mark="yes"

    # Inner render pipeline: offset input -> jq (full, no truncation) -> workdir strip -> color seds
    _render_full() {
        if [[ "$LAST" -eq 1 ]]; then
            local _select_types='select(.type == "user" or .type == "assistant" or .type == "tool_result")'
            [[ "$SKIP_TOOL_OUTPUT" -eq 1 ]] && _select_types='select(.type == "user" or .type == "assistant")'
            _tac "$filepath" 2>/dev/null | jq -c "$_select_types" 2>/dev/null | head -1 || true
        elif [[ "$LAST" -gt 1 ]]; then
            cat "$filepath"
        elif [[ "$OFFSET" -gt 0 ]]; then
            tail -n +"$((OFFSET + 1))" "$filepath"
        else
            cat "$filepath"
        fi | \
        jq -r --arg mark "$mark" --arg skip_tool "$SKIP_TOOL_OUTPUT" '
            (if $mark != "" then "@@MSG@@" else empty end),
            if .type == "user" then
                if .isCompactSummary then
                    "@@SUMMARY@@ " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
                else
                    "@@USER@@ " + (if .message.content | type == "string" then .message.content else .message.content[0].text // "" end)
                end
            elif .type == "assistant" then
                (.message.content // [])[] |
                if .type == "tool_use" then
                    "@@TOOL@@ \(.name) @@TOOLEND@@", (.input | tostring)
                elif .type == "text" then
                    "@@ASST@@ " + .text
                else empty end
            elif .type == "tool_result" then
                if $skip_tool == "1" then empty
                else "@@RESULT@@", ((.content[0].text // .content // "") | tostring) end
            elif .type == "system" then
                if .subtype == "compact_boundary" then
                    "@@COMPACT@@ Conversation compacted (" + (.compactMetadata.trigger // "unknown") + ", " + ((.compactMetadata.preTokens // 0) | tostring) + " tokens before)"
                elif .subtype == "microcompact_boundary" then
                    "@@COMPACT@@ Context microcompacted (" + (.microcompactMetadata.trigger // "auto") + ", saved " + ((.microcompactMetadata.tokensSaved // 0) | tostring) + " tokens)"
                elif ((.hookInfos // []) | length) > 0 then
                    ((.hookInfos // [])[] | "@@HOOK@@ " + ((.command // "") | split("/") | .[-3:] | join("/")) + " (" + ((.durationMs // 0) | tostring) + "ms)"),
                    (if ((.hookErrors // []) | length) > 0 then "@@HOOK@@ [ERRORS]: " + ((.hookErrors // []) | join(", ")) else empty end)
                else
                    "@@SYSTEM@@ " + (.subtype // "system") + (if .content then ": " + (.content | tostring) else "" end)
                end
            elif .type == "progress" then
                if .data.command == "callback" then empty
                elif .data.hookName then
                    "@@HOOK@@ " + .data.hookName + " \u2192 " + ((.data.command // "") | split("/") | last)
                else
                    "@@HOOK@@ " + (.data.type // "progress")
                end
            elif .type == "queue-operation" and .operation == "enqueue" and .content then
                .content as $c |
                if ($c | test("<task-notification>")) then
                    "@@HOOK@@ enqueue: " + (($c | capture("<summary>(?<t>[^<]+)</summary>") | .t) // "task-notification")
                elif ($c | test("<teammate-message")) then
                    "@@HOOK@@ enqueue: " + (($c | capture("teammate_id=\"(?<id>[^\"]+)\"") | .id) // "teammate") + (($c | capture("summary=\"(?<s>[^\"]+)\"") | ": " + .s) // "")
                elif ($c | test("FileChanged")) then
                    "@@HOOK@@ enqueue: FileChanged"
                elif ($c | test("<system-reminder>")) then
                    "@@HOOK@@ enqueue: system-reminder"
                else
                    "@@HOOK@@ enqueue: " + ($c | split("\n") | .[0] | .[:80])
                end
            else empty end
        ' 2>/dev/null | \
        if [[ -n "$workdir_escaped" ]]; then sed "s/$workdir_escaped\///g"; else cat; fi | \
        _color_sed
    }

    # Determine label
    local is_agent=""
    [[ "$filepath" == *"/subagents/"* ]] && is_agent=1
    local header_label
    if [[ -n "$is_agent" ]]; then
        header_label="Agent: $agent_id (full)"
    else
        header_label="Session: $agent_id (full)"
    fi

    if [[ "$LAST" -eq 1 ]]; then
        # Last message only, no header, no pager
        _render_full
    elif [[ "$LAST" -gt 1 ]]; then
        # Last N tokens, chronological order, no header, no pager
        _render_full | awk -v limit="$LAST" '
            BEGIN { bc = 0; cur = ""; bt = 0; total = 0 }
            /^@@MSG@@$/ {
                if (cur != "") { blocks[++bc] = cur; btok[bc] = bt; total += bt }
                cur = ""; bt = 0; next
            }
            { cur = (cur == "" ? $0 : cur "\n" $0); bt += int(length / 4) }
            END {
                if (cur != "") { blocks[++bc] = cur; btok[bc] = bt; total += bt }
                s = 1
                while (s < bc && total > limit) { total -= btok[s]; s++ }
                for (i = s; i <= bc; i++) print blocks[i]
            }
        '
    elif [[ "$LIMIT" -gt 0 ]]; then
        # Direct output with token counting (no pager)
        {
            _print_metadata_header "$filepath" "$header_label"
            _render_full
        } | awk -v limit="$LIMIT" -v offset="$OFFSET" '
            BEGIN { tokens = 0; msgs = 0; exceeded = 0; done = 0 }
            /^@@MSG@@$/ {
                if (exceeded) {
                    printf "NEXT_OFFSET=%d\n", offset + msgs
                    done = 1
                    exit 0
                }
                msgs++
                next
            }
            {
                print
                tokens += int(length / 4)
                if (tokens >= limit) { exceeded = 1 }
            }
            END {
                if (exceeded && !done) {
                    printf "NEXT_OFFSET=%d\n", offset + msgs
                }
            }
        ' || true
    else
        # Standard mode with pager
        {
            _print_metadata_header "$filepath" "$header_label"
            _render_full
        } | less -R
    fi
}

