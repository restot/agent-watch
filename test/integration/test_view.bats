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
