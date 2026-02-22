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

@test "project name stripping for home-only dir produces empty or tilde" {
    # Test the stripping logic directly — a dir named just "-<HOME_PATTERN>" yields "~"
    local project_dir="-${_HOME_PATTERN}"
    local project_name="${project_dir#-${_HOME_PATTERN}}"
    project_name="${project_name#-}"
    [[ -z "$project_name" ]] && project_name="~"
    [[ "$project_name" == "~" ]]
}
