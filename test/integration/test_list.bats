#!/usr/bin/env bats
# Integration tests for cmd_list and cmd_list_sessions

load '../test_helper/common'
load '../test_helper/fixtures'

# ── cmd_list ──────────────────────────────────────────────────────

@test "cmd_list shows agents" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)
    _f=$(create_agent "myproject" "sess1" "bbb222" 4)

    run cmd_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaa111"* ]]
    [[ "$output" == *"bbb222"* ]]
}

@test "cmd_list respects count" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)
    sleep 1
    _f=$(create_agent "myproject" "sess1" "bbb222" 4)

    run cmd_list 1
    [ "$status" -eq 0 ]

    # Count lines that contain an agent ID (below the header lines).
    # Headers contain "AGENT" and "──────"; actual agent lines contain the 8-char id.
    local agent_lines
    agent_lines=$(echo "$output" | grep -cE '[a-f0-9]{6}' || true)
    [ "$agent_lines" -eq 1 ]
}

@test "cmd_list -p filters by project" {
    local _f
    _f=$(create_agent "alpha-project" "sess1" "aaa111" 4)
    _f=$(create_agent "beta-project" "sess2" "bbb222" 4)

    run cmd_list -p "alpha"
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaa111"* ]]
    [[ "$output" != *"bbb222"* ]]
}

@test "cmd_list -p is case-insensitive" {
    local _f
    _f=$(create_agent "Alpha-Project" "sess1" "aaa111" 4)

    run cmd_list -p "ALPHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaa111"* ]]
}

@test "cmd_list with no agents shows header only" {
    run cmd_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"AGENT"* ]]
    # No agent ID lines below the header
    local agent_lines
    agent_lines=$(echo "$output" | grep -cE '^.{0,3}[a-f0-9]{6,}' || true)
    [ "$agent_lines" -eq 0 ]
}

@test "cmd_list excludes prompt_suggestion files" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)

    # Create a prompt_suggestion file that would match the agent glob but should be excluded
    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-myproject/sess1/subagents"
    mkdir -p "$dir"
    echo '{"type":"user","message":{"role":"user","content":"suggestion"}}' > "${dir}/agent-aprompt_suggestion_xxx.jsonl"

    run cmd_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaa111"* ]]
    [[ "$output" != *"prompt_suggestion"* ]]
}

# ── cmd_list_sessions ─────────────────────────────────────────────

@test "cmd_list_sessions shows sessions with prompts" {
    local sid="abcdef1234567890"
    local _f
    _f=$(create_session "myproject" "$sid" 4)
    create_session_index "myproject" "${sid}:hello world prompt"

    run cmd_list_sessions
    [ "$status" -eq 0 ]
    [[ "$output" == *"abcdef12"* ]]
    [[ "$output" == *"hello world prompt"* ]]
}

@test "cmd_list_sessions shows no sessions found when empty" {
    run cmd_list_sessions
    [ "$status" -eq 0 ]
    [[ "$output" == *"(no sessions found)"* ]]
}

@test "cmd_list_sessions -p filters by project" {
    local sid1="aaaa1111aaaa1111"
    local sid2="bbbb2222bbbb2222"
    local _f
    _f=$(create_session "alpha-project" "$sid1" 4)
    create_session_index "alpha-project" "${sid1}:alpha prompt"
    _f=$(create_session "beta-project" "$sid2" 4)
    create_session_index "beta-project" "${sid2}:beta prompt"

    run cmd_list_sessions -p "alpha"
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaaa1111"* ]]
    [[ "$output" != *"bbbb2222"* ]]
}

@test "cmd_list_sessions respects count" {
    local sid1="aaaa1111aaaa1111"
    local sid2="bbbb2222bbbb2222"
    local _f
    _f=$(create_session "myproject" "$sid1" 4)
    sleep 1
    _f=$(create_session "myproject" "$sid2" 4)
    create_session_index "myproject" "${sid1}:first" "${sid2}:second"

    run cmd_list_sessions 2
    [ "$status" -eq 0 ]

    # Both sessions should appear when count is 2
    local session_lines
    session_lines=$(echo "$output" | grep -cE '[a-f0-9]{8}' || true)
    [ "$session_lines" -ge 2 ]

    # Now only 1
    run cmd_list_sessions 1
    [ "$status" -eq 0 ]
    session_lines=$(echo "$output" | grep -cE '(aaaa1111|bbbb2222)' || true)
    [ "$session_lines" -eq 1 ]
}
