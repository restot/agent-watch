#!/usr/bin/env bats
# Integration tests for cmd_interactive and cmd_sessions (interactive path)
# Uses a mock fzf script to simulate user selection.

load '../test_helper/common'
load '../test_helper/fixtures'

MOCK_FZF="$BATS_TEST_DIRNAME/../test_helper/mock_fzf.bash"

setup() {
    ORIGINAL_HOME="$HOME"
    BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    FAKE_HOME="$(mktemp -d "${BATS_TMPDIR}/agent-watch-test.XXXXXX")"

    export HOME="$FAKE_HOME"
    export PROJECTS_DIR="$HOME/.claude/projects"

    mkdir -p "$HOME/.claude/projects"
    mkdir -p "$HOME/.claude/.agent-pids"

    export AGENT_WATCH_SOURCED=1
    source "${BATS_TEST_DIRNAME}/../../agent-watch"

    set +e +o pipefail

    _HOME_PATTERN="${HOME//\//-}"
    _HOME_PATTERN="${_HOME_PATTERN#-}"

    DEBUG=0
    OFFSET=0
    LIMIT=0
    LAST=0

    # Set up mock fzf directory
    MOCK_BIN="$(mktemp -d "${BATS_TMPDIR}/mock-bin.XXXXXX")"
    cp "$MOCK_FZF" "$MOCK_BIN/fzf"
    chmod +x "$MOCK_BIN/fzf"
}

teardown() {
    rm -rf "$FAKE_HOME"
    rm -rf "$MOCK_BIN"
    export HOME="$ORIGINAL_HOME"
}

# ── cmd_interactive ──────────────────────────────────────────────

@test "cmd_interactive dies when fzf not in PATH" {
    # Ensure fzf is NOT on PATH
    run env PATH="/usr/bin:/bin" bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        cmd_interactive
    '
    [ "$status" -ne 0 ]
    [[ "$output" == *"Required for interactive mode"* ]]
}

@test "cmd_interactive dies when no agents found" {
    run env PATH="$MOCK_BIN:$PATH" bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        cmd_interactive
    '
    [ "$status" -ne 0 ]
    [[ "$output" == *"No sub-agents found"* ]]
}

@test "cmd_interactive alt-w dispatches to view_agent" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    export MOCK_FZF_KEY="alt-w"
    export MOCK_FZF_SELECT=1
    LIMIT=5000
    run env PATH="$MOCK_BIN:$PATH" MOCK_FZF_KEY="alt-w" MOCK_FZF_SELECT=1 bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        LIMIT=5000
        cmd_interactive
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agent:"* ]]
}

@test "cmd_interactive alt-f dispatches to view_agent_full" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    export MOCK_FZF_KEY="alt-f"
    export MOCK_FZF_SELECT=1
    LIMIT=5000
    run env PATH="$MOCK_BIN:$PATH" MOCK_FZF_KEY="alt-f" MOCK_FZF_SELECT=1 bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        LIMIT=5000
        cmd_interactive
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"(full)"* ]]
}

@test "cmd_interactive escape exits cleanly" {
    local filepath
    filepath=$(create_agent "myproject" "sess1" "aaa111" 4)

    run env PATH="$MOCK_BIN:$PATH" MOCK_FZF_EXIT=1 bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        cmd_interactive
    '
    [ "$status" -eq 0 ]
}

# ── cmd_sessions (interactive path) ─────────────────────────────

@test "cmd_sessions interactive dies when fzf not in PATH" {
    run env PATH="/usr/bin:/bin" bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        cmd_sessions
    '
    [ "$status" -ne 0 ]
    [[ "$output" == *"Required for interactive mode"* ]]
}

@test "cmd_sessions interactive dies when no sessions found" {
    run env PATH="$MOCK_BIN:$PATH" bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        cmd_sessions
    '
    [ "$status" -ne 0 ]
    [[ "$output" == *"No sessions found"* ]]
}

@test "cmd_sessions interactive alt-w dispatches to view_agent" {
    local sid="abcdef1234567890"
    local filepath
    filepath=$(create_session "myproject" "$sid" 4)
    create_session_index "myproject" "${sid}:hello world"

    run env PATH="$MOCK_BIN:$PATH" MOCK_FZF_KEY="alt-w" MOCK_FZF_SELECT=1 bash -c '
        export HOME="'"$FAKE_HOME"'"
        export PROJECTS_DIR="'"$PROJECTS_DIR"'"
        export AGENT_WATCH_SOURCED=1
        source "'"${BATS_TEST_DIRNAME}/../../agent-watch"'"
        set +e +o pipefail
        LIMIT=5000
        cmd_sessions
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session:"* ]]
}
