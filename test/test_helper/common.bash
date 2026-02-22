# common.bash — loaded by every bats test
# Sets up isolated temp environment and sources agent-watch for unit testing

setup() {
    ORIGINAL_HOME="$HOME"
    BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    FAKE_HOME="$(mktemp -d "${BATS_TMPDIR}/agent-watch-test.XXXXXX")"

    export HOME="$FAKE_HOME"
    export PROJECTS_DIR="$HOME/.claude/projects"

    mkdir -p "$HOME/.claude/projects"
    mkdir -p "$HOME/.claude/.agent-pids"

    # Source agent-watch as a library (skip main execution)
    export AGENT_WATCH_SOURCED=1
    source "${BATS_TEST_DIRNAME}/../../agent-watch"

    # Reset shell options — agent-watch sets -euo pipefail which interferes with bats
    set +e +o pipefail

    # Recompute _HOME_PATTERN since HOME changed after initial source
    _HOME_PATTERN="${HOME//\//-}"
    _HOME_PATTERN="${_HOME_PATTERN#-}"

    # Reset globals to defaults
    DEBUG=0
    OFFSET=0
    LIMIT=0
    LAST=0
}

teardown() {
    rm -rf "$FAKE_HOME"
    export HOME="$ORIGINAL_HOME"
}
