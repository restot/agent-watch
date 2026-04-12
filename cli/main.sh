
# Allow sourcing for tests: source all functions without running arg parsing
[[ "${AGENT_WATCH_SOURCED:-}" == "1" ]] && return 0 2>/dev/null || true

# Parse all flags from any position, collect positional args
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)   DEBUG=1; shift ;;
        --no-color) _COLOR=0; _setup_colors; shift ;;
        --skip-tool-output) SKIP_TOOL_OUTPUT=1; shift ;;
        --help)    show_usage; exit 0 ;;
        -v|-V|--version) ARGS+=("version"); shift ;;
        --offset)  OFFSET="${2:?--offset requires a value}"; shift 2 ;;
        --limit)   LIMIT="${2:?--limit requires a value}"; shift 2 ;;
        --last)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                LAST="$2"; shift 2
            else
                LAST=1; shift
            fi
            ;;
        *)         ARGS+=("$1"); shift ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "${1:-}" in
    session|sessions)
        cmd_sessions "${2:-}"
        ;;
    list-sessions)
        shift
        cmd_list_sessions "$@"
        ;;
    list)
        shift
        cmd_list "$@"
        ;;
    view)
        cmd_view "${2:-}"
        ;;
    watch)
        cmd_watch "${2:-}"
        ;;
    wait)
        shift
        cmd_wait "$@"
        ;;
    update)
        self=$(command -v agent-watch 2>/dev/null || echo "$0")
        latest=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/restot/agent-watch/releases/latest 2>/dev/null | grep -oE '[^/]+$')
        if [[ -z "$latest" ]]; then
            die "Could not check for updates"
        fi
        if [[ "$latest" == "v$VERSION" ]]; then
            echo "Already up to date (v$VERSION)"
            exit 0
        fi
        echo "Updating: v$VERSION -> $latest"
        tmpfile=$(mktemp) || die "Could not create temp file"
        curl -fsSL "https://github.com/restot/agent-watch/releases/latest/download/agent-watch" -o "$tmpfile" || { rm -f "$tmpfile"; die "Download failed"; }
        chmod +x "$tmpfile"
        mv -f "$tmpfile" "$self"
        echo "Done."
        ;;
    -v|-V|--version|version)
        echo "agent-watch $VERSION"
        latest=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/restot/agent-watch/releases/latest 2>/dev/null | grep -oE '[^/]+$')
        if [[ -n "$latest" && "$latest" != "v$VERSION" ]]; then
            echo -e "${YELLOW}Update available: ${latest}${NC}  (current: v${VERSION})"
            echo "  agent-watch update"
        fi
        exit 0
        ;;
    -h|--help|help)
        show_usage
        ;;
    "")
        cmd_interactive
        ;;
    *)
        # Try as agent ID first, then session ID
        if find "$PROJECTS_DIR" -name "agent-${1}*.jsonl" -type f 2>/dev/null | grep -q .; then
            cmd_view "$1"
        elif find "$PROJECTS_DIR" -maxdepth 2 -name "${1}*.jsonl" -type f 2>/dev/null | grep -v '/subagents/' | grep -q .; then
            cmd_sessions "$1"
        else
            die "No agent or session found matching '$1'"
        fi
        ;;
esac
