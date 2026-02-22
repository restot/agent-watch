#!/usr/bin/env bats
# Lint tests — shellcheck and bash syntax validation

AW="$BATS_TEST_DIRNAME/../../agent-watch"

@test "shellcheck passes" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    run shellcheck -s bash --severity=warning -e SC2034,SC2155,SC2295,SC2038,SC2064 "$AW"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "bash -n syntax check passes" {
    run bash -n "$AW"
    [ "$status" -eq 0 ]
}
