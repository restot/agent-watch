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

@test "show_usage contains update command" {
    run show_usage
    [[ "$output" == *"update"* ]]
}

@test "show_usage contains sessions command" {
    run show_usage
    [[ "$output" == *"sessions"* ]]
}

@test "show_usage contains watch command" {
    run show_usage
    [[ "$output" == *"watch"* ]]
}

@test "show_usage contains AGENT_WATCH_STALE_TIMEOUT" {
    run show_usage
    [[ "$output" == *"AGENT_WATCH_STALE_TIMEOUT"* ]]
}

@test "show_usage contains --no-color" {
    run show_usage
    [[ "$output" == *"--no-color"* ]]
}

@test "show_usage contains NO_COLOR env var" {
    run show_usage
    [[ "$output" == *"NO_COLOR"* ]]
}

@test "show_usage contains --skip-tool-output" {
    run show_usage
    [[ "$output" == *"--skip-tool-output"* ]]
}

# --- NO_COLOR support ---

@test "NO_COLOR env var disables color variables" {
    _COLOR=0
    _setup_colors
    [[ -z "$RED" ]]
    [[ -z "$GREEN" ]]
    [[ -z "$BLUE" ]]
    [[ -z "$NC" ]]
    [[ -z "$DIM" ]]
}

@test "colors are populated when _COLOR=1" {
    _COLOR=1
    _setup_colors
    [[ -n "$RED" ]]
    [[ -n "$GREEN" ]]
    [[ -n "$NC" ]]
    [[ -n "$DIM" ]]
}

@test "_color_sed renders plain text markers when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@USER@@ hello" | _color_sed)
    [[ "$result" == "[USER] hello" ]]
}

@test "_color_sed renders TOOL plain text when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@TOOL@@ Bash @@TOOLEND@@ ls" | _color_sed)
    [[ "$result" == "[TOOL] Bash ls" ]]
}

@test "_color_sed renders RESULT plain text when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@RESULT@@ some output" | _color_sed)
    [[ "$result" == "[RESULT] some output" ]]
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

# --- _color_sed: new tags (COMPACT, HOOK, SUMMARY) ---

@test "_color_sed renders COMPACT plain text when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@COMPACT@@ Conversation compacted (auto, 168134 tokens before)" | _color_sed)
    [[ "$result" == "[COMPACT] Conversation compacted (auto, 168134 tokens before)" ]]
}

@test "_color_sed renders HOOK plain text when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@HOOK@@ SessionStart:startup → session-start.sh" | _color_sed)
    [[ "$result" == "[HOOK] SessionStart:startup → session-start.sh" ]]
}

@test "_color_sed renders SUMMARY plain text when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@SUMMARY@@ This session is being continued" | _color_sed)
    [[ "$result" == "[SUMMARY] This session is being continued" ]]
}

@test "_color_sed renders COMPACT with ANSI when _COLOR=1" {
    _COLOR=1
    result=$(echo "@@COMPACT@@ compacted" | _color_sed)
    [[ "$result" == *"[COMPACT]"* ]]
    [[ "$result" == *$'\033['* ]]
}

@test "_color_sed renders HOOK with ANSI when _COLOR=1" {
    _COLOR=1
    result=$(echo "@@HOOK@@ hook info" | _color_sed)
    [[ "$result" == *"[HOOK]"* ]]
    [[ "$result" == *$'\033['* ]]
}

@test "_color_sed renders SUMMARY with ANSI when _COLOR=1" {
    _COLOR=1
    result=$(echo "@@SUMMARY@@ summary text" | _color_sed)
    [[ "$result" == *"[SUMMARY]"* ]]
    [[ "$result" == *$'\033['* ]]
}

@test "_color_sed renders SYSTEM plain text when _COLOR=0" {
    _COLOR=0
    result=$(echo "@@SYSTEM@@ turn_duration: Turn took 5s" | _color_sed)
    [[ "$result" == "[SYSTEM] turn_duration: Turn took 5s" ]]
}

@test "_color_sed renders SYSTEM with ANSI when _COLOR=1" {
    _COLOR=1
    result=$(echo "@@SYSTEM@@ turn_duration" | _color_sed)
    [[ "$result" == *"[SYSTEM]"* ]]
    [[ "$result" == *$'\033['* ]]
}
