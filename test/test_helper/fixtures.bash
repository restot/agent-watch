# fixtures.bash — helper functions to create synthetic test data
# Relies on PROJECTS_DIR and _HOME_PATTERN from common.bash

# create_session "project-name" "session-id" [num_messages]
# Creates a session JSONL file with alternating user/assistant messages.
# Echoes the filepath.
create_session() {
    local project="$1"
    local session_id="$2"
    local num_messages="${3:-4}"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    local i=0
    while [[ $i -lt $num_messages ]]; do
        if (( i % 2 == 0 )); then
            echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.44","gitBranch":"main","timestamp":"2026-02-17T07:49:25.485Z","message":{"role":"user","content":"hello world"}}' >> "$filepath"
        else
            echo '{"type":"assistant","timestamp":"2026-02-17T07:49:26.000Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","content":[{"type":"text","text":"response here"}],"usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":80,"cache_creation_input_tokens":20}}}' >> "$filepath"
        fi
        (( i++ )) || true
    done

    echo "$filepath"
}

# create_agent "project-name" "session-id" "agent-id" [num_messages]
# Creates an agent JSONL file with alternating user/assistant messages.
# Echoes the filepath.
create_agent() {
    local project="$1"
    local session_id="$2"
    local agent_id="$3"
    local num_messages="${4:-4}"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}/${session_id}/subagents"
    mkdir -p "$dir"

    local filepath="${dir}/agent-${agent_id}.jsonl"
    : > "$filepath"

    local i=0
    while [[ $i -lt $num_messages ]]; do
        if (( i % 2 == 0 )); then
            echo '{"type":"user","sessionId":"'"${session_id}"'","agentId":"'"${agent_id}"'","slug":"test-task","isSidechain":true,"permissionMode":"default","cwd":"'"${HOME}/${project}"'","version":"2.1.44","gitBranch":"main","timestamp":"2026-02-17T07:49:25.485Z","message":{"role":"user","content":"hello world"}}' >> "$filepath"
        else
            echo '{"type":"assistant","timestamp":"2026-02-17T07:49:26.000Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","content":[{"type":"text","text":"response here"}],"usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":80,"cache_creation_input_tokens":20}}}' >> "$filepath"
        fi
        (( i++ )) || true
    done

    echo "$filepath"
}

# create_agent_with_tools "project-name" "session-id" "agent-id"
# Creates an agent JSONL with tool_use and tool_result messages for testing colorized output.
# Echoes the filepath.
create_agent_with_tools() {
    local project="$1"
    local session_id="$2"
    local agent_id="$3"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}/${session_id}/subagents"
    mkdir -p "$dir"

    local filepath="${dir}/agent-${agent_id}.jsonl"
    : > "$filepath"

    # User message
    echo '{"type":"user","sessionId":"'"${session_id}"'","agentId":"'"${agent_id}"'","slug":"test-task","isSidechain":true,"permissionMode":"default","cwd":"'"${HOME}/${project}"'","version":"2.1.44","gitBranch":"main","timestamp":"2026-02-17T07:49:25.485Z","message":{"role":"user","content":"list files"}}' >> "$filepath"

    # Assistant with tool_use
    echo '{"type":"assistant","timestamp":"2026-02-17T07:49:26.000Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}],"usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":80,"cache_creation_input_tokens":20}}}' >> "$filepath"

    # Tool result
    echo '{"type":"tool_result","timestamp":"2026-02-17T07:49:27.000Z","message":{"role":"user","content":[{"type":"tool_result","content":[{"text":"file1.txt"}]}]}}' >> "$filepath"

    # Assistant text response
    echo '{"type":"assistant","timestamp":"2026-02-17T07:49:28.000Z","message":{"role":"assistant","model":"claude-sonnet-4-20250514","content":[{"type":"text","text":"I found file1.txt in the directory."}],"usage":{"input_tokens":150,"output_tokens":30,"cache_read_input_tokens":100,"cache_creation_input_tokens":10}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_index "project-name" "id:prompt" ...
# Creates a sessions-index.json in the project directory.
create_session_index() {
    local project="$1"
    shift

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local entries=""
    for pair in "$@"; do
        local id="${pair%%:*}"
        local prompt="${pair#*:}"
        [[ -n "$entries" ]] && entries="${entries},"
        entries="${entries}{\"sessionId\":\"${id}\",\"firstPrompt\":\"${prompt}\"}"
    done

    echo "{\"entries\":[${entries}]}" > "${dir}/sessions-index.json"
}

# create_pid_file "agent-id" [pid]
# Creates a PID file for the given agent.
create_pid_file() {
    local agent_id="$1"
    local pid="${2:-99999}"

    echo "$pid" > "$HOME/.claude/.agent-pids/${agent_id}"
}

# create_token_log "agent-id"
# Appends a token log entry for the given agent.
create_token_log() {
    local agent_id="$1"

    echo "[12:00:00] general-purpose (${agent_id}): 500 tokens (in:300 out:200 cache:100)" >> "$HOME/.claude/subagent-tokens.log"
}
