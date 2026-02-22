#!/usr/bin/env bats
# Integration tests for view_agent_full

load '../test_helper/common'
load '../test_helper/fixtures'

# ── view_agent_full metadata header ──────────────────────────────

@test "view_agent_full shows 'Agent: (full)' label for subagent file" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    LIMIT=5000
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agent:"* ]]
    [[ "$output" == *"(full)"* ]]
    [[ "$output" == *"aaa111"* ]]
}

@test "view_agent_full shows 'Session: (full)' label for session file" {
    local filepath
    filepath=$(create_session "myproject" "sess1234" 4)

    LIMIT=5000
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session:"* ]]
    [[ "$output" == *"(full)"* ]]
    [[ "$output" == *"sess1234"* ]]
}

# ── untruncated tool output ──────────────────────────────────────

@test "view_agent_full shows untruncated tool input" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "tools1")

    LIMIT=5000
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[TOOL]"* ]]
    [[ "$output" == *"Bash"* ]]
}

@test "view_agent_full shows tool result content" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "tools1")

    LIMIT=5000
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[RESULT]"* ]]
}

# ── --last mode ──────────────────────────────────────────────────

@test "view_agent_full --last 1 shows last message content" {
    local filepath
    filepath=$(create_agent_with_tools "myproject" "sess1" "tools1")

    LAST=1
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain actual content from last assistant message
    [[ "$output" == *"file1.txt"* ]]
    # Should NOT have the metadata header
    [[ "$output" != *"Model:"* ]]
}

@test "view_agent_full --last N shows token-limited output" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 6)

    LAST=500
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # No metadata header
    [[ "$output" != *"Model:"* ]]
}

# ── --limit mode ─────────────────────────────────────────────────

@test "view_agent_full --limit on large agent emits NEXT_OFFSET" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 40)

    LIMIT=50
    run view_agent_full "$filepath"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEXT_OFFSET="* ]]
}

# ── --offset mode ────────────────────────────────────────────────

@test "view_agent_full --offset skips early messages" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 6)

    # First without offset
    LIMIT=5000
    OFFSET=0
    run view_agent_full "$filepath"
    local full_output="$output"

    # Now with offset=2 — should skip first 2 JSONL lines
    OFFSET=2
    run view_agent_full "$filepath"
    local offset_output="$output"

    [ "$status" -eq 0 ]
    # The offset output should be shorter (fewer messages rendered)
    [ "${#offset_output}" -lt "${#full_output}" ]
}
