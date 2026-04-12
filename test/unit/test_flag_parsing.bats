#!/usr/bin/env bats
# Tests for flag parsing (runs agent-watch as a subprocess, not sourced)

load '../test_helper/common'

AW="$BATS_TEST_DIRNAME/../../agent-watch"

# --- --help ---

@test "--help exits 0 and output contains Usage: agent-watch" {
    run "$AW" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage: agent-watch"* ]]
}

# --- --version ---

@test "--version output contains agent-watch" {
    run "$AW" --version
    [[ "$output" == *"agent-watch"* ]]
}

# --- -v ---

@test "-v output contains agent-watch" {
    run "$AW" -v
    [[ "$output" == *"agent-watch"* ]]
}

# --- --limit without value ---

@test "--limit without value exits non-zero" {
    run "$AW" --limit
    [[ "$status" -ne 0 ]]
}

# --- --offset without value ---

@test "--offset without value exits non-zero" {
    run "$AW" --offset
    [[ "$status" -ne 0 ]]
}

# --- --last --help ---

@test "--last --help still reaches help" {
    run "$AW" --last --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage: agent-watch"* ]]
}

# --- --last 5000 --help ---

@test "--last 5000 --help still reaches help" {
    run "$AW" --last 5000 --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage: agent-watch"* ]]
}

# --- --skip-tool-output ---

@test "--skip-tool-output --help still reaches help" {
    run "$AW" --skip-tool-output --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage: agent-watch"* ]]
}
