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

# create_session_with_compaction "project-name" "session-id"
# Creates a session with pre-compaction messages, compact_boundary, summary, and post-compaction messages.
# Echoes the filepath.
create_session_with_compaction() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    # Pre-compaction user message
    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.81","gitBranch":"main","timestamp":"2026-03-23T18:00:00.000Z","message":{"role":"user","content":"pre-compaction message"},"uuid":"aaa-111"}' >> "$filepath"

    # Pre-compaction assistant
    echo '{"type":"assistant","timestamp":"2026-03-23T18:00:01.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"pre-compaction response"}],"usage":{"input_tokens":100,"output_tokens":50}},"uuid":"aaa-222"}' >> "$filepath"

    # Compact boundary
    echo '{"parentUuid":null,"logicalParentUuid":"aaa-222","type":"system","subtype":"compact_boundary","content":"Conversation compacted","timestamp":"2026-03-23T18:55:36.927Z","uuid":"compact-001","level":"info","compactMetadata":{"trigger":"auto","preTokens":168134},"sessionId":"'"${session_id}"'","version":"2.1.81"}' >> "$filepath"

    # Compaction summary
    echo '{"parentUuid":"compact-001","type":"user","isCompactSummary":true,"isVisibleInTranscriptOnly":true,"message":{"role":"user","content":"This session is being continued from a previous conversation. Summary: the user was working on a CLI tool."},"uuid":"summary-001","timestamp":"2026-03-23T18:55:36.927Z","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.81","gitBranch":"main"}' >> "$filepath"

    # Post-compaction user message
    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.81","gitBranch":"main","timestamp":"2026-03-23T19:00:00.000Z","message":{"role":"user","content":"post-compaction message"},"uuid":"post-001"}' >> "$filepath"

    # Post-compaction assistant
    echo '{"type":"assistant","timestamp":"2026-03-23T19:00:01.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"post-compaction response"}],"usage":{"input_tokens":100,"output_tokens":50}},"uuid":"post-002"}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_microcompact "project-name" "session-id"
# Creates a session with a microcompact_boundary entry.
# Echoes the filepath.
create_session_with_microcompact() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    # User message
    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.81","gitBranch":"main","timestamp":"2026-03-23T18:00:00.000Z","message":{"role":"user","content":"hello"}}' >> "$filepath"

    # Microcompact boundary
    echo '{"parentUuid":"prev-uuid","type":"system","subtype":"microcompact_boundary","content":"Context microcompacted","timestamp":"2026-03-23T18:15:00.000Z","uuid":"micro-001","level":"info","microcompactMetadata":{"trigger":"auto","preTokens":60114,"tokensSaved":21368,"compactedToolIds":["toolu_1","toolu_2"]}}' >> "$filepath"

    # Post-microcompact assistant
    echo '{"type":"assistant","timestamp":"2026-03-23T18:15:01.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"continuing after microcompact"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_hooks "project-name" "session-id"
# Creates a session with hook_progress entries and a stop_hook_summary.
# Echoes the filepath.
create_session_with_hooks() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    # User message
    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.81","gitBranch":"main","timestamp":"2026-03-23T18:00:00.000Z","message":{"role":"user","content":"hello"}}' >> "$filepath"

    # SessionStart hook
    echo '{"parentUuid":null,"type":"progress","data":{"type":"hook_progress","hookEvent":"SessionStart","hookName":"SessionStart:startup","command":"/home/user/.claude/hooks/session-start.sh"},"toolUseID":"hook-001","parentToolUseID":"hook-001","timestamp":"2026-03-23T18:00:01.000Z","uuid":"hook-uuid-001","sessionId":"'"${session_id}"'"}' >> "$filepath"

    # PreToolUse hook
    echo '{"parentUuid":"hook-uuid-001","type":"progress","data":{"type":"hook_progress","hookEvent":"PreToolUse","hookName":"PreToolUse:Read","command":"/home/user/.claude/hooks/pre-tool-use.sh"},"toolUseID":"toolu_123","parentToolUseID":"toolu_123","timestamp":"2026-03-23T18:00:02.000Z","uuid":"hook-uuid-002","sessionId":"'"${session_id}"'"}' >> "$filepath"

    # PostToolUse callback (should be filtered out)
    echo '{"parentUuid":"hook-uuid-002","type":"progress","data":{"type":"hook_progress","hookEvent":"PostToolUse","hookName":"PostToolUse:Read","command":"callback"},"toolUseID":"toolu_123","parentToolUseID":"toolu_123","timestamp":"2026-03-23T18:00:03.000Z","uuid":"hook-uuid-003","sessionId":"'"${session_id}"'"}' >> "$filepath"

    # Stop hook summary
    echo '{"parentUuid":"hook-uuid-003","type":"system","subtype":"stop_hook_summary","hookCount":2,"hookInfos":[{"command":"/home/user/.claude/hooks/stop.sh","durationMs":150}],"hookErrors":[],"preventedContinuation":false,"timestamp":"2026-03-23T18:00:04.000Z","uuid":"hook-uuid-004","sessionId":"'"${session_id}"'"}' >> "$filepath"

    # Assistant response
    echo '{"type":"assistant","timestamp":"2026-03-23T18:00:05.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"done"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_hook_errors "project-name" "session-id"
# Creates a session with a stop_hook_summary that has errors.
# Echoes the filepath.
create_session_with_hook_errors() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.81","gitBranch":"main","timestamp":"2026-03-23T18:00:00.000Z","message":{"role":"user","content":"hello"}}' >> "$filepath"

    echo '{"parentUuid":null,"type":"system","subtype":"stop_hook_summary","hookCount":1,"hookInfos":[{"command":"/home/user/.claude/hooks/stop.sh","durationMs":150}],"hookErrors":["hook failed: exit 1"],"preventedContinuation":false,"timestamp":"2026-03-23T18:00:01.000Z","uuid":"hook-err-001","sessionId":"'"${session_id}"'"}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_system_entries "project-name" "session-id"
# Creates a session with generic system entries (turn_duration, etc.).
# Echoes the filepath.
create_session_with_system_entries() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.86","gitBranch":"main","timestamp":"2026-03-28T18:00:00.000Z","message":{"role":"user","content":"hello"}}' >> "$filepath"

    echo '{"type":"system","subtype":"turn_duration","content":"Turn took 5.2s","timestamp":"2026-03-28T18:00:01.000Z","uuid":"td-001"}' >> "$filepath"

    echo '{"type":"assistant","timestamp":"2026-03-28T18:00:02.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_queue_ops "project-name" "session-id"
# Creates a session with queue-operation enqueue/dequeue entries (FileChanged hooks).
# Echoes the filepath.
create_session_with_queue_ops() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    echo '{"type":"queue-operation","operation":"enqueue","timestamp":"2026-03-28T23:41:28.000Z","sessionId":"'"${session_id}"'","content":"<system-reminder>\nFileChanged hook triggered\n</system-reminder>"}' >> "$filepath"

    echo '{"type":"queue-operation","operation":"dequeue","timestamp":"2026-03-28T23:41:28.100Z","sessionId":"'"${session_id}"'"}' >> "$filepath"

    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.86","gitBranch":"main","timestamp":"2026-03-28T23:41:29.000Z","message":{"role":"user","content":"<system-reminder>\nFileChanged hook triggered\n</system-reminder>"}}' >> "$filepath"

    echo '{"type":"assistant","timestamp":"2026-03-28T23:41:30.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"acknowledged"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_task_enqueue "project-name" "session-id"
# Creates a session with a task-notification enqueue entry.
# Echoes the filepath.
create_session_with_task_enqueue() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    echo '{"type":"queue-operation","operation":"enqueue","timestamp":"2026-03-28T23:50:00.000Z","sessionId":"'"${session_id}"'","content":"<task-notification>\n<task-id>abc123</task-id>\n<status>completed</status>\n<summary>Agent \"Code review\" completed</summary>\n<result>All good</result>\n</task-notification>"}' >> "$filepath"

    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.86","gitBranch":"main","timestamp":"2026-03-28T23:50:01.000Z","message":{"role":"user","content":"hello"}}' >> "$filepath"

    echo '{"type":"assistant","timestamp":"2026-03-28T23:50:02.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_teammate_enqueue "project-name" "session-id"
# Creates a session with a teammate-message enqueue entry.
# Echoes the filepath.
create_session_with_teammate_enqueue() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    echo '{"type":"queue-operation","operation":"enqueue","timestamp":"2026-03-28T23:55:00.000Z","sessionId":"'"${session_id}"'","content":"<system-reminder>\nStop hook blocking error from command \"FileChanged\": <teammate-message teammate_id=\"agent1\" summary=\"build finished\"> </teammate-message>\n</system-reminder>"}' >> "$filepath"

    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.86","gitBranch":"main","timestamp":"2026-03-28T23:55:01.000Z","message":{"role":"user","content":"hello"}}' >> "$filepath"

    echo '{"type":"assistant","timestamp":"2026-03-28T23:55:02.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}

# create_session_with_plain_enqueue "project-name" "session-id"
# Creates a session with a plain-text enqueue entry (user queued input).
# Echoes the filepath.
create_session_with_plain_enqueue() {
    local project="$1"
    local session_id="$2"

    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}-${project}"
    mkdir -p "$dir"

    local filepath="${dir}/${session_id}.jsonl"
    : > "$filepath"

    echo '{"type":"queue-operation","operation":"enqueue","timestamp":"2026-03-28T23:58:00.000Z","sessionId":"'"${session_id}"'","content":"run the tests please"}' >> "$filepath"

    echo '{"type":"user","sessionId":"'"${session_id}"'","cwd":"'"${HOME}/${project}"'","version":"2.1.86","gitBranch":"main","timestamp":"2026-03-28T23:58:01.000Z","message":{"role":"user","content":"run the tests please"}}' >> "$filepath"

    echo '{"type":"assistant","timestamp":"2026-03-28T23:58:02.000Z","message":{"role":"assistant","model":"claude-opus-4-6","content":[{"type":"text","text":"ok"}],"usage":{"input_tokens":100,"output_tokens":50}}}' >> "$filepath"

    echo "$filepath"
}
