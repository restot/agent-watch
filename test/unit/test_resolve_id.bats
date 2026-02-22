#!/usr/bin/env bats
# Tests for _resolve_id

load '../test_helper/common'
load '../test_helper/fixtures'

# --- empty input ---

@test "_resolve_id with empty input and agents returns most recent agent file" {
    local f1 f2
    f1=$(create_agent "myproject" "sess1" "aaa111")
    sleep 1
    f2=$(create_agent "myproject" "sess1" "bbb222")

    run _resolve_id ""
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"agent-bbb222.jsonl"* ]]
}

@test "_resolve_id with empty input and only sessions falls back to session" {
    local f1
    f1=$(create_session "myproject" "sess-only-abc123")

    run _resolve_id ""
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"sess-only-abc123.jsonl"* ]]
}

# --- exact filepath ---

@test "_resolve_id with exact filepath returns it" {
    local f1
    f1=$(create_agent "myproject" "sess1" "exact123")

    run _resolve_id "$f1"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$f1" ]]
}

# --- agent ID prefix ---

@test "_resolve_id with agent ID prefix finds matching agent" {
    create_agent "myproject" "sess1" "abc12345"

    run _resolve_id "abc123"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"agent-abc12345.jsonl"* ]]
}

# --- session ID prefix ---

@test "_resolve_id with session ID prefix finds matching session" {
    create_session "myproject" "def456789-session"

    run _resolve_id "def456789"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"def456789-session.jsonl"* ]]
}

# --- agents preferred over sessions ---

@test "_resolve_id prefers agents over sessions with same prefix" {
    create_agent "myproject" "sess1" "same99-agent"
    create_session "myproject" "same99-session"

    run _resolve_id "same99"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"agent-same99"* ]]
}

# --- nonexistent ---

@test "_resolve_id with nonexistent input dies with error" {
    run _resolve_id "zzz-does-not-exist"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"No agent or session found"* ]]
}

# --- empty input, no files ---

@test "_resolve_id with empty input and no files dies" {
    run _resolve_id ""
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"No agents or sessions found"* ]]
}
