#!/usr/bin/env bats
# Integration tests for _print_metadata_header

load '../test_helper/common'
load '../test_helper/fixtures'

setup() {
    # Call the common setup first
    ORIGINAL_HOME="$HOME"
    BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    FAKE_HOME="$(mktemp -d "${BATS_TMPDIR}/agent-watch-test.XXXXXX")"

    export HOME="$FAKE_HOME"
    export PROJECTS_DIR="$HOME/.claude/projects"

    mkdir -p "$HOME/.claude/projects"
    mkdir -p "$HOME/.claude/.agent-pids"

    export AGENT_WATCH_SOURCED=1
    source "${BATS_TEST_DIRNAME}/../../agent-watch"

    _HOME_PATTERN="${HOME//\//-}"
    _HOME_PATTERN="${_HOME_PATTERN#-}"

    DEBUG=0
    OFFSET=0
    LIMIT=0
    LAST=0

    # Create a shared agent fixture for all tests in this file
    AGENT_FILE=$(create_agent "myproject" "sess1" "aaa111" 4)
}

# ── Model ─────────────────────────────────────────────────────────

@test "_print_metadata_header shows Model" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Model:"* ]]
    [[ "$output" == *"claude-sonnet-4-20250514"* ]]
}

# ── Version ───────────────────────────────────────────────────────

@test "_print_metadata_header shows Version" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Version:"* ]]
    [[ "$output" == *"2.1.44"* ]]
}

# ── Branch ────────────────────────────────────────────────────────

@test "_print_metadata_header shows Branch" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch:"* ]]
    [[ "$output" == *"main"* ]]
}

# ── Tokens ────────────────────────────────────────────────────────

@test "_print_metadata_header shows Tokens with in and out" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tokens:"* ]]
    [[ "$output" == *"in"* ]]
    [[ "$output" == *"out"* ]]
}

# ── Slug ──────────────────────────────────────────────────────────

@test "_print_metadata_header shows Slug for subagent files" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Slug:"* ]]
    [[ "$output" == *"test-task"* ]]
}

# ── Messages ──────────────────────────────────────────────────────

@test "_print_metadata_header shows Messages count" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Messages:"* ]]
    # The agent has 4 messages
    [[ "$output" == *"4"* ]]
}

# ── Timestamps ────────────────────────────────────────────────────

@test "_print_metadata_header shows Started and Ended timestamps" {
    run _print_metadata_header "$AGENT_FILE" "Agent: aaa111"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Started:"* ]]
    [[ "$output" == *"Ended:"* ]]
}
