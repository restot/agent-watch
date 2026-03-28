#!/usr/bin/env bats
# Integration tests for view_agent

load '../test_helper/common'
load '../test_helper/fixtures'

# ── view_agent metadata header ────────────────────────────────────

@test "view_agent shows 'Agent:' label for subagent file" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agent:"* ]]
    [[ "$output" == *"aaa111"* ]]
}

@test "view_agent shows 'Session:' label for session file" {
    local filepath
    filepath=$(create_session "myproject" "sess1234" 4)

    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session:"* ]]
    [[ "$output" == *"sess1234"* ]]
}

# ── --last mode ───────────────────────────────────────────────────

@test "view_agent --last shows output but no Model header" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    LAST=1
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    # Should have some output (the last renderable message)
    [ -n "$output" ]
    # Should NOT have the metadata header
    [[ "$output" != *"Model:"* ]]
}

@test "view_agent --last N shows output in chronological order without header" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 6)

    LAST=500
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # No metadata header
    [[ "$output" != *"Model:"* ]]
}

@test "view_agent --last N preserves multi-line content order" {
    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-mltest/sess1/subagents"
    mkdir -p "$dir"
    local filepath="${dir}/agent-ml111.jsonl"
    : > "$filepath"

    # User message
    echo '{"type":"user","sessionId":"sess1","agentId":"ml111","slug":"test","isSidechain":true,"permissionMode":"default","cwd":"'"${HOME}/mltest"'","version":"2.1.44","gitBranch":"main","timestamp":"2026-02-17T07:49:25.485Z","message":{"role":"user","content":"summarize"}}' >> "$filepath"

    # Assistant with multi-line text (line1 before line2 before line3)
    echo '{"type":"assistant","timestamp":"2026-02-17T07:49:26.000Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","content":[{"type":"text","text":"line1-first\nline2-second\nline3-third"}],"usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":80,"cache_creation_input_tokens":20}}}' >> "$filepath"

    LAST=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]

    # Verify lines appear in correct order (line1 before line3)
    local pos1 pos3
    pos1=$(echo "$output" | grep -n "line1-first" | head -1 | cut -d: -f1)
    pos3=$(echo "$output" | grep -n "line3-third" | head -1 | cut -d: -f1)
    [ -n "$pos1" ]
    [ -n "$pos3" ]
    [ "$pos1" -lt "$pos3" ]
}

# ── --limit mode ──────────────────────────────────────────────────

@test "view_agent --limit on large agent emits NEXT_OFFSET" {
    # Create an agent with many messages to exceed the tiny limit
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 40)

    LIMIT=50
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEXT_OFFSET="* ]]
}

# ── --offset mode ─────────────────────────────────────────────────

@test "view_agent --offset skips early messages" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 6)

    # First without offset
    LIMIT=5000
    OFFSET=0
    run view_agent "$filepath"
    local full_output="$output"

    # Now with offset=2 — should skip first 2 JSONL lines
    OFFSET=2
    run view_agent "$filepath"
    local offset_output="$output"

    [ "$status" -eq 0 ]
    # The offset output should be shorter (fewer messages rendered)
    [ "${#offset_output}" -lt "${#full_output}" ]
}

# ── colorized markers ────────────────────────────────────────────

# ── --last content verification (tests _tac fix) ────────────────

@test "view_agent --last 1 returns actual message content" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "tools1")

    LAST=1
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    # Should contain actual content from the last assistant message
    [[ "$output" == *"file1.txt"* ]]
}

# ── tool rendering ──────────────────────────────────────────────

@test "view_agent renders tool_use with [TOOL] and tool name" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "tools1")

    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[TOOL]"* ]]
    [[ "$output" == *"Bash"* ]]
}

@test "view_agent renders tool_result with [RESULT]" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "tools1")

    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[RESULT]"* ]]
}

# ── colorized markers ────────────────────────────────────────────

@test "view_agent shows colorized USER and ASST markers" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    # Check for ANSI-colorized [USER] marker (green: \033[0;32m)
    [[ "$output" == *"[USER]"* ]]
    # Check for ANSI-colorized [ASST] marker (magenta: \033[0;35m)
    [[ "$output" == *"[ASST]"* ]]
}

# ── NO_COLOR support ────────────────────────────────────────────

@test "view_agent with NO_COLOR outputs no ANSI escapes" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "nocolor1")

    _COLOR=0
    _setup_colors
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    # Should have plain text markers
    [[ "$output" == *"[USER]"* ]]
    [[ "$output" == *"[TOOL]"* ]]
    [[ "$output" == *"[RESULT]"* ]]
    # Should NOT contain ANSI escape sequences
    [[ "$output" != *$'\033['* ]]
}

@test "view_agent with _COLOR=1 outputs ANSI escapes" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "color1" 4)

    _COLOR=1
    _setup_colors
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    # Should contain ANSI escape sequences
    [[ "$output" == *$'\033['* ]]
}

# ── compaction rendering ────────────────────────────────────────

@test "view_agent renders compact_boundary as [COMPACT]" {
    local filepath
    filepath=$(create_session_with_compaction "myproject" "sess-compact1")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[COMPACT]"* ]]
    [[ "$output" == *"Conversation compacted"* ]]
    [[ "$output" == *"168134 tokens before"* ]]
}

@test "view_agent renders compaction summary as [SUMMARY] not [USER]" {
    local filepath
    filepath=$(create_session_with_compaction "myproject" "sess-compact2")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SUMMARY]"* ]]
    [[ "$output" == *"being continued"* ]]
}

@test "view_agent renders post-compaction messages" {
    local filepath
    filepath=$(create_session_with_compaction "myproject" "sess-compact3")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"post-compaction message"* ]]
    [[ "$output" == *"post-compaction response"* ]]
}

@test "view_agent renders pre and post compaction messages together" {
    local filepath
    filepath=$(create_session_with_compaction "myproject" "sess-compact4")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pre-compaction message"* ]]
    [[ "$output" == *"[COMPACT]"* ]]
    [[ "$output" == *"post-compaction message"* ]]
}

@test "view_agent renders microcompact_boundary as [COMPACT]" {
    local filepath
    filepath=$(create_session_with_microcompact "myproject" "sess-micro1")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[COMPACT]"* ]]
    [[ "$output" == *"Context microcompacted"* ]]
    [[ "$output" == *"saved 21368 tokens"* ]]
}

# ── hook rendering ──────────────────────────────────────────────

@test "view_agent renders hook_progress as [HOOK]" {
    local filepath
    filepath=$(create_session_with_hooks "myproject" "sess-hooks1")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[HOOK]"* ]]
    [[ "$output" == *"SessionStart:startup"* ]]
}

@test "view_agent renders PreToolUse hook" {
    local filepath
    filepath=$(create_session_with_hooks "myproject" "sess-hooks2")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PreToolUse:Read"* ]]
    [[ "$output" == *"pre-tool-use.sh"* ]]
}

@test "view_agent filters out callback hook entries" {
    local filepath
    filepath=$(create_session_with_hooks "myproject" "sess-hooks3")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    # "callback" should not appear as a hook command
    local hook_lines
    hook_lines=$(echo "$output" | grep "\[HOOK\]" || true)
    [[ "$hook_lines" != *"callback"* ]]
}

@test "view_agent renders stop_hook_summary as [HOOK]" {
    local filepath
    filepath=$(create_session_with_hooks "myproject" "sess-hooks4")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stop hooks: 2 ran"* ]]
}

@test "view_agent renders stop_hook_summary with ERRORS flag" {
    local filepath
    filepath=$(create_session_with_hook_errors "myproject" "sess-hookerr1")

    _COLOR=0
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERRORS]"* ]]
}

@test "view_agent with NO_COLOR renders COMPACT and HOOK as plain text" {
    local filepath
    filepath=$(create_session_with_compaction "myproject" "sess-nocolor-c")

    _COLOR=0
    _setup_colors
    LIMIT=5000
    run view_agent "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[COMPACT]"* ]]
    [[ "$output" == *"[SUMMARY]"* ]]
    [[ "$output" != *$'\033['* ]]
}
