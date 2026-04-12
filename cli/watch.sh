watch_agent() {
    local filepath="$1"
    debug " entered watch_agent with [$filepath]"

    local agent_id
    agent_id=$(basename "$filepath" .jsonl | sed 's/agent-//')

    # Extract working dir from first file path in content (look for /app/, /spec/, etc.)
    local workdir workdir_escaped match
    match=$(grep -oE "${HOME}/[^\"\\\\]+/(app|spec|lib|src|test)/" "$filepath" 2>/dev/null | head -1 || true)
    workdir=$(echo "$match" | sed 's|/app/$||;s|/spec/$||;s|/lib/$||;s|/src/$||;s|/test/$||' || true)
    [[ -z "$workdir" ]] && workdir=""
    workdir_escaped=$(printf '%s' "$workdir" | sed 's/[\/&]/\\&/g' || true)

    local is_agent=""
    [[ "$filepath" == *"/subagents/"* ]] && is_agent=1
    local header_label
    if [[ -n "$is_agent" ]]; then
        header_label="Watching Agent: $agent_id"
    else
        header_label="Watching Session: $agent_id"
    fi

    clear
    _print_metadata_header "$filepath" "$header_label"
    echo -e "${DIM}Press Ctrl+C to stop${NC}"

    debug " about to start tail -f"
    tail -n +1 -f "$filepath" 2>&1 | jq --unbuffered -r --arg skip_tool "$SKIP_TOOL_OUTPUT" '
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
    { if [[ -n "$workdir_escaped" ]]; then sed -u "s/$workdir_escaped\///g"; else cat; fi; } | \
    _color_sed_u
}

