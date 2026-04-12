_resolve_id() {
    # Resolve an input (filepath, agent ID, or session ID) to a JSONL filepath.
    # Prints the resolved path. Dies if nothing found.
    local input="$1"

    if [[ -z "$input" ]]; then
        # Most recent agent, then most recent session
        local f
        f=$(get_agent_files | head -1)
        [[ -z "$f" ]] && f=$(get_session_files | head -1)
        [[ -z "$f" ]] && die "No agents or sessions found"
        echo "$f"
        return
    fi

    if [[ -f "$input" ]]; then
        echo "$input"
        return
    fi

    # Try agent ID first, then session ID
    local f
    f=$(find "$PROJECTS_DIR" -name "agent-${input}*.jsonl" -type f 2>/dev/null | head -1)
    [[ -z "$f" ]] && f=$(find "$PROJECTS_DIR" -maxdepth 2 -name "${input}*.jsonl" -type f 2>/dev/null | grep -v '/subagents/' | head -1)
    [[ -z "$f" ]] && die "No agent or session found matching '$input'"
    echo "$f"
}

cmd_view() {
    local filepath
    filepath=$(_resolve_id "${1:-}")
    view_agent "$filepath"
}

cmd_watch() {
    local filepath
    filepath=$(_resolve_id "${1:-}")
    watch_agent "$filepath"
}

agent_pid_alive() {
    # Check if the recorded PID for this agent is still running
    local agent_id="$1"
    local pid_file="$HOME/.claude/.agent-pids/$agent_id"

    if [[ ! -f "$pid_file" ]]; then
        return 1  # no PID file = not running (or pre-hook era agent)
    fi

    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    if [[ -z "$pid" ]]; then
        return 1
    fi

    kill -0 "$pid" 2>/dev/null
}

cmd_wait() {
    local agent_ids=("$@")
    local log_file="$HOME/.claude/subagent-tokens.log"
    local stale_threshold=${AGENT_WATCH_STALE_TIMEOUT:-300}

    if [[ ${#agent_ids[@]} -eq 0 ]]; then
        die "Usage: agent-watch wait <agent_id> [agent_id...]"
    fi

    echo "Waiting for ${#agent_ids[@]} agent(s): ${agent_ids[*]}"

    # Ensure log file exists
    touch "$log_file"

    # Check which agents are already done (in existing log)
    local pending=()
    for id in "${agent_ids[@]}"; do
        if ! grep -q "($id)" "$log_file" 2>/dev/null; then
            pending+=("$id")
        fi
    done

    if [[ ${#pending[@]} -eq 0 ]]; then
        echo "All agents completed."
        return 0
    fi

    echo "Pending: ${pending[*]}"

    # Poll for completions
    while true; do
        local remaining=0
        local now
        now=$(date +%s)

        for id in "${pending[@]}"; do
            # 1. Token log — hook-based completion signal
            if grep -q "($id)" "$log_file" 2>/dev/null; then
                continue
            fi

            # 2. Process check — is the claude process still alive?
            if agent_pid_alive "$id"; then
                ((remaining++)) || true
                continue
            fi

            # 3. No PID file (pre-hook agent or PID file already cleaned up)
            #    Fall back to JSONL staleness check
            local pid_file="$HOME/.claude/.agent-pids/$id"
            if [[ ! -f "$pid_file" ]]; then
                local agent_file
                agent_file=$(find "$PROJECTS_DIR" -name "agent-${id}*.jsonl" -type f 2>/dev/null | head -1)
                if [[ -z "$agent_file" ]]; then
                    continue  # no file at all
                fi
                local mod_epoch stale_secs
                mod_epoch=$(stat -f "%m" "$agent_file" 2>/dev/null || stat -c "%Y" "$agent_file" 2>/dev/null)
                stale_secs=$((now - mod_epoch))
                if [[ $stale_secs -gt $stale_threshold ]]; then
                    echo "Agent $id: no PID file, no activity for ${stale_secs}s, presuming dead."
                    continue
                fi
                # Recently modified but no PID file — could be in-flight, keep waiting
                ((remaining++)) || true
                continue
            fi

            # PID file exists but process is dead — agent crashed
            echo "Agent $id: process exited (hook may have failed)."
            rm -f "$pid_file"
        done

        if [[ $remaining -eq 0 ]]; then
            echo "All agents completed."
            break
        fi

        sleep 2
    done

    return 0
}

