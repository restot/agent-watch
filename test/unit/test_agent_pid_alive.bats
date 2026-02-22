#!/usr/bin/env bats
# Unit tests for agent_pid_alive

load '../test_helper/common'
load '../test_helper/fixtures'

@test "agent_pid_alive returns 1 when no PID file exists" {
    run agent_pid_alive "nonexistent-agent"
    [ "$status" -eq 1 ]
}

@test "agent_pid_alive returns 0 for live PID (self)" {
    create_pid_file "live-agent" "$$"
    run agent_pid_alive "live-agent"
    [ "$status" -eq 0 ]
}

@test "agent_pid_alive returns 1 for dead PID" {
    create_pid_file "dead-agent" 99999
    run agent_pid_alive "dead-agent"
    [ "$status" -eq 1 ]
}

@test "agent_pid_alive returns 1 for empty PID file" {
    local pid_file="$HOME/.claude/.agent-pids/empty-agent"
    : > "$pid_file"
    run agent_pid_alive "empty-agent"
    [ "$status" -eq 1 ]
}
