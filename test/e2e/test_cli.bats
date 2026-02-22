#!/usr/bin/env bats
# End-to-end CLI tests — run agent-watch as a subprocess with HOME override

load "../test_helper/common"
load "../test_helper/fixtures"

AW="$BATS_TEST_DIRNAME/../../agent-watch"

setup() {
    ORIGINAL_HOME="$HOME"
    BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    FAKE_HOME="$(mktemp -d "${BATS_TMPDIR}/agent-watch-e2e.XXXXXX")"

    export HOME="$FAKE_HOME"
    export PROJECTS_DIR="$HOME/.claude/projects"

    mkdir -p "$HOME/.claude/projects"
    mkdir -p "$HOME/.claude/.agent-pids"

    # Source briefly to get _HOME_PATTERN and fixture helpers
    export AGENT_WATCH_SOURCED=1
    source "$AW"

    # Reset shell options and env — agent-watch sets -euo pipefail
    set +e +o pipefail
    unset AGENT_WATCH_SOURCED

    _HOME_PATTERN="${HOME//\//-}"
    _HOME_PATTERN="${_HOME_PATTERN#-}"

    # Create standard fixtures (suppress echoed filepaths)
    create_agent "test-project" "sess-111aaa222" "aaa111bbb" 4 >/dev/null
    create_session "test-project" "sess-222ccc333" 4 >/dev/null
    create_session_index "test-project" "sess-222ccc333:hello cli test"
}

teardown() {
    rm -rf "$FAKE_HOME"
    export HOME="$ORIGINAL_HOME"
}

@test "agent-watch list works" {
    run env HOME="$FAKE_HOME" "$AW" list
    echo "status=$status"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaa111bb"* ]]
}

@test "agent-watch list-sessions works" {
    run env HOME="$FAKE_HOME" "$AW" list-sessions
    [ "$status" -eq 0 ]
    [[ "$output" == *"sess-222"* ]]
}

@test "agent-watch <agent-id> auto-detects agent" {
    run env HOME="$FAKE_HOME" "$AW" --limit 5000 aaa111bbb
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agent:"* ]]
}

@test "agent-watch session views session" {
    run env HOME="$FAKE_HOME" "$AW" session --limit 5000 sess-222
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session:"* ]]
}

@test "agent-watch view shows most recent" {
    run env HOME="$FAKE_HOME" "$AW" view --limit 5000
    [ "$status" -eq 0 ]
}

@test "agent-watch --last shows output without Model header" {
    run env HOME="$FAKE_HOME" "$AW" --last aaa111
    [ "$status" -eq 0 ]
    [[ "$output" != *"Model:"* ]]
}

@test "agent-watch --limit on small agent works without error" {
    run env HOME="$FAKE_HOME" "$AW" --limit 50 aaa111
    [ "$status" -eq 0 ]
}

@test "agent-watch help shows usage" {
    run env HOME="$FAKE_HOME" "$AW" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "agent-watch wait returns immediately for completed agent" {
    create_token_log "aaa111bbb"
    run env HOME="$FAKE_HOME" "$AW" wait aaa111bbb
    [ "$status" -eq 0 ]
    [[ "$output" == *"All agents completed"* ]]
}

@test "agent-watch nonexistent id exits 1" {
    run env HOME="$FAKE_HOME" "$AW" zzz-nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" == *"No agent or session found"* ]]
}
