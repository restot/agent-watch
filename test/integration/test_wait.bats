#!/usr/bin/env bats
# Integration tests for cmd_wait

load '../test_helper/common'
load '../test_helper/fixtures'

# ── argument validation ───────────────────────────────────────────

@test "cmd_wait with no args dies with Usage" {
    run cmd_wait
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# ── token log completion ─────────────────────────────────────────

@test "cmd_wait exits immediately when token log shows completion" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)
    create_token_log "aaa111"

    run cmd_wait "aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"All agents completed"* ]]
}

@test "cmd_wait detects all agents done in token log" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)
    _f=$(create_agent "myproject" "sess1" "bbb222" 4)
    create_token_log "aaa111"
    create_token_log "bbb222"

    run cmd_wait "aaa111" "bbb222"
    [ "$status" -eq 0 ]
    [[ "$output" == *"All agents completed"* ]]
}

# ── dead PID file ─────────────────────────────────────────────────

@test "cmd_wait with dead PID file reports completion" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)
    # PID 99999 should not exist
    create_pid_file "aaa111" 99999

    run cmd_wait "aaa111"
    [ "$status" -eq 0 ]
    # Process is dead, so agent should be reported as exited
    [[ "$output" == *"process exited"* ]] || [[ "$output" == *"All agents completed"* ]]
}

# ── staleness fallback ────────────────────────────────────────────

@test "cmd_wait uses staleness fallback" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    # Touch the agent file to an old date (2 seconds ago would exceed 1s threshold)
    touch -t 202601010000 "$filepath"

    # Set a very short stale timeout so the test completes quickly
    export AGENT_WATCH_STALE_TIMEOUT=1

    run cmd_wait "aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"presuming dead"* ]] || [[ "$output" == *"All agents completed"* ]]
}

# ── agent count reporting ─────────────────────────────────────────

@test "cmd_wait reports agent count" {
    local _f
    _f=$(create_agent "myproject" "sess1" "aaa111" 4)
    _f=$(create_agent "myproject" "sess1" "bbb222" 4)
    create_token_log "aaa111"
    create_token_log "bbb222"

    run cmd_wait "aaa111" "bbb222"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 agent(s)"* ]]
}
