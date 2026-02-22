#!/usr/bin/env bats
# Tests for helper functions: die, debug, info, show_usage, _fmt_tokens

load '../test_helper/common'

# --- die ---

@test "die prints Error: plus message and exits 1" {
    run die "something broke"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Error:"* ]]
    [[ "$output" == *"something broke"* ]]
}

# --- debug ---

@test "debug is silent when DEBUG=0" {
    DEBUG=0
    run debug "should not appear"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "debug prints DEBUG: message when DEBUG=1" {
    DEBUG=1
    run debug "trace info"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"DEBUG:"* ]]
    [[ "$output" == *"trace info"* ]]
}

# --- info ---

@test "info prints message" {
    run info "hello world"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"hello world"* ]]
}

# --- show_usage ---

@test "show_usage contains list [count]" {
    run show_usage
    [[ "$output" == *"list [count]"* ]]
}

@test "show_usage contains list-sessions" {
    run show_usage
    [[ "$output" == *"list-sessions"* ]]
}

@test "show_usage contains view [id]" {
    run show_usage
    [[ "$output" == *"view [id]"* ]]
}

@test "show_usage contains session <id>" {
    run show_usage
    [[ "$output" == *"session <id>"* ]]
}

@test "show_usage contains wait <id>" {
    run show_usage
    [[ "$output" == *"wait <id>"* ]]
}

@test "show_usage contains --limit N" {
    run show_usage
    [[ "$output" == *"--limit N"* ]]
}

@test "show_usage contains --offset N" {
    run show_usage
    [[ "$output" == *"--offset N"* ]]
}

@test "show_usage contains --last" {
    run show_usage
    [[ "$output" == *"--last"* ]]
}

@test "show_usage contains --debug" {
    run show_usage
    [[ "$output" == *"--debug"* ]]
}

@test "show_usage contains AGENT_WATCH_STALE_TIMEOUT" {
    run show_usage
    [[ "$output" == *"AGENT_WATCH_STALE_TIMEOUT"* ]]
}

# --- _fmt_tokens ---

@test "_fmt_tokens 500 returns 500" {
    run _fmt_tokens 500
    [[ "$output" == "500" ]]
}

@test "_fmt_tokens 1500 returns 1.5k" {
    run _fmt_tokens 1500
    [[ "$output" == "1.5k" ]]
}

@test "_fmt_tokens 2500000 returns 2.5M" {
    run _fmt_tokens 2500000
    [[ "$output" == "2.5M" ]]
}

@test "_fmt_tokens 1000 returns 1.0k" {
    run _fmt_tokens 1000
    [[ "$output" == "1.0k" ]]
}
