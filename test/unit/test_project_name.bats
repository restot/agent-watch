#!/usr/bin/env bats
# Tests for project name display (regression tests)

load '../test_helper/common'
load '../test_helper/fixtures'

# --- format_agent_line strips HOME prefix ---

@test "format_agent_line strips HOME prefix from agent project dir" {
    local f
    f=$(create_agent "Documents-projects-cool-app" "sess1" "proj111")

    run format_agent_line "$f"
    [[ "$status" -eq 0 ]]
    # Output is pipe-delimited; project is field 6
    local project
    project=$(echo "$output" | cut -d'|' -f6)
    [[ "$project" == "Documents-projects-cool-app" ]]
}

# --- dashes preserved, not converted to slashes (regression) ---

@test "dashes in project dir names are preserved, not converted to slashes" {
    local f
    f=$(create_agent "Documents-projects-ai-voice" "sess1" "dashtest1")

    run format_agent_line "$f"
    [[ "$status" -eq 0 ]]

    local project
    project=$(echo "$output" | cut -d'|' -f6)
    [[ "$project" == "Documents-projects-ai-voice" ]]
    [[ "$project" != *"ai/voice"* ]]
}

@test "format_agent_line for ai-voice project contains correct name and not ai/voice" {
    local f
    f=$(create_agent "Documents-projects-ai-voice" "sess1" "voicetest1")

    run format_agent_line "$f"
    [[ "$status" -eq 0 ]]

    [[ "$output" == *"Documents-projects-ai-voice"* ]]
    # Ensure no slash conversion
    [[ "$output" != *"ai/voice"* ]]
}

# --- cmd_list_sessions with home-only project shows ~ ---

@test "cmd_list_sessions with home-only project shows tilde as project name" {
    # A project dir that is just the HOME pattern (no extra path after stripping)
    local dir="$PROJECTS_DIR/-${_HOME_PATTERN}"
    mkdir -p "$dir"

    local session_id="homesess-abc12345"
    cat > "$dir/${session_id}.jsonl" <<JSONL
{"type":"user","version":"1.0","cwd":"$HOME","gitBranch":"main","timestamp":"2026-02-17T10:00:00.000Z","message":{"content":"test"}}
{"type":"assistant","timestamp":"2026-02-17T10:00:01.000Z","message":{"model":"claude-sonnet-4-20250514","content":[{"type":"text","text":"ok"}],"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
JSONL

    # Create a sessions-index so _preload_session_data can find the prompt
    create_session_index "$(basename "$dir" | sed "s/^-${_HOME_PATTERN}-//")" "${session_id}:home test"  2>/dev/null || true
    # Also create the index directly in the right directory
    echo '{"entries":[{"sessionId":"'"$session_id"'","firstPrompt":"home test"}]}' > "$dir/sessions-index.json"

    run cmd_list_sessions
    [[ "$status" -eq 0 ]]
    # The project column for a home-only path should show "~"
    [[ "$output" == *"~"* ]]
}
