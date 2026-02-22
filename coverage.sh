#!/usr/bin/env bash
# Simple bash coverage tool for agent-watch
# Injects tracing into agent-watch via BASH_XTRACEFD, runs tests, analyzes results
#
# Usage: bash coverage.sh [--html]

set -uo pipefail  # no -e: bash arithmetic returns 1 for zero values
cd "$(dirname "$0")"

SCRIPT="$(pwd)/agent-watch"
TRACE_DIR="$(mktemp -d)"
TRACE_FILE="$TRACE_DIR/trace.log"
COVERAGE_DIR="$(pwd)/coverage"
HTML_MODE=0

[[ "${1:-}" == "--html" ]] && HTML_MODE=1

# Save original agent-watch
cp "$SCRIPT" "$TRACE_DIR/agent-watch.bak"

restore() {
    cp "$TRACE_DIR/agent-watch.bak" "$SCRIPT"
    rm -rf "$TRACE_DIR"
}
trap restore EXIT

# Write the coverage injection snippet
cat > "$TRACE_DIR/inject.txt" <<'INJECT'
# --- coverage tracing (injected by coverage.sh) ---
if [[ -n "${_COV_TRACE_FILE:-}" ]]; then
    exec 7>>"$_COV_TRACE_FILE"
    BASH_XTRACEFD=7
    PS4='+COV:${BASH_SOURCE[0]:-}:${LINENO}: '
    set -x
fi
# --- end coverage tracing ---
INJECT

# Number of lines injected
INJECT_LINES=$(wc -l < "$TRACE_DIR/inject.txt" | tr -d ' ')

# Insert after "set -euo pipefail" line
INJECT_AFTER=$(grep -n '^set -euo pipefail$' "$TRACE_DIR/agent-watch.bak" | head -1 | cut -d: -f1)
{
    head -n "$INJECT_AFTER" "$TRACE_DIR/agent-watch.bak"
    cat "$TRACE_DIR/inject.txt"
    tail -n +"$((INJECT_AFTER + 1))" "$TRACE_DIR/agent-watch.bak"
} > "$SCRIPT"
chmod +x "$SCRIPT"

echo "=== agent-watch coverage ==="
echo "  injection: ${INJECT_LINES} lines after line ${INJECT_AFTER}"
echo ""

touch "$TRACE_FILE"

# Run all test suites with _COV_TRACE_FILE exported
export _COV_TRACE_FILE="$TRACE_FILE"

echo "--- unit tests ---"
bats test/unit/ || true

echo ""
echo "--- integration tests ---"
bats test/integration/ || true

echo ""
echo "--- e2e tests ---"
bats test/e2e/ || true

unset _COV_TRACE_FILE

echo ""

# Check trace file
TRACE_SIZE=$(wc -c < "$TRACE_FILE" | tr -d ' ')
TRACE_LINES=$(wc -l < "$TRACE_FILE" | tr -d ' ')
echo "Trace: ${TRACE_SIZE} bytes, ${TRACE_LINES} lines"
echo ""

echo "=== Coverage Analysis ==="
echo ""

ORIG="$TRACE_DIR/agent-watch.bak"

# Determine if a line is non-code (structural only)
is_nocode() {
    local s="$1"
    [[ -z "$s" ]] && return 0
    [[ "$s" == \#* ]] && return 0
    case "$s" in
        "}"|"{"|";;"|esac|fi|done|else|then|do|")") return 0 ;;
    esac
    return 1
}

# Pre-classify every line: 1 = executable bash, 0 = non-code
# State machine tracks heredoc bodies and multi-line single-quoted strings
# (jq/awk programs) so their interior lines aren't counted as bash.
declare -a LINE_CLASS=()
_heredoc_delim=""
_in_squote=0
_total_lines=0

while IFS= read -r _line; do
    _total_lines=$((_total_lines + 1))
    _stripped="${_line#"${_line%%[![:space:]]*}"}"

    # --- Inside heredoc body ---
    if [[ -n "$_heredoc_delim" ]]; then
        if [[ "$_stripped" == "$_heredoc_delim" ]]; then
            _heredoc_delim=""
        fi
        LINE_CLASS[$_total_lines]=0
        continue
    fi

    # --- Inside multi-line single-quoted string (jq/awk program) ---
    if (( _in_squote )); then
        _tmp="${_line//[^\']/}"
        if (( ${#_tmp} % 2 == 1 )); then
            # Odd quotes: closing quote on this line — line IS bash
            _in_squote=0
            LINE_CLASS[$_total_lines]=1
        else
            LINE_CLASS[$_total_lines]=0
        fi
        continue
    fi

    # --- Normal state ---
    if is_nocode "$_stripped"; then
        LINE_CLASS[$_total_lines]=0
        continue
    fi

    # Detect heredoc opening: <<[-] 'DELIM' or <<[-] "DELIM" or <<[-] DELIM
    if [[ "$_line" =~ \<\<-?[[:space:]]*\'([A-Za-z_][A-Za-z0-9_]*)\' ]]; then
        _heredoc_delim="${BASH_REMATCH[1]}"
        LINE_CLASS[$_total_lines]=1
        continue
    elif [[ "$_line" =~ \<\<-?[[:space:]]*\"([A-Za-z_][A-Za-z0-9_]*)\" ]]; then
        _heredoc_delim="${BASH_REMATCH[1]}"
        LINE_CLASS[$_total_lines]=1
        continue
    elif [[ "$_line" =~ \<\<-?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*$ ]]; then
        _heredoc_delim="${BASH_REMATCH[1]}"
        LINE_CLASS[$_total_lines]=1
        continue
    fi

    # Count single quotes — odd means a multi-line string opens here
    _tmp="${_line//[^\']/}"
    if (( ${#_tmp} % 2 == 1 )); then
        _in_squote=1
        LINE_CLASS[$_total_lines]=1  # opening-quote line is bash
        continue
    fi

    LINE_CLASS[$_total_lines]=1
done < "$ORIG"

# Sum executable lines from classification
TOTAL_EXECUTABLE=0
for (( _i = 1; _i <= _total_lines; _i++ )); do
    (( TOTAL_EXECUTABLE += LINE_CLASS[_i] )) || true
done

# Extract unique hit line numbers, adjusted for injection offset
declare -A HIT_LINES=()
if [[ -s "$TRACE_FILE" ]]; then
    grep '+COV:.*agent-watch:' "$TRACE_FILE" 2>/dev/null \
    | sed -n 's/.*agent-watch:\([0-9][0-9]*\):.*/\1/p' \
    | sort -un > "$TRACE_DIR/raw_hits.txt"

    RAW_HIT_COUNT=$(wc -l < "$TRACE_DIR/raw_hits.txt" | tr -d ' ')
    echo "Raw hit lines (instrumented): $RAW_HIT_COUNT"

    while IFS= read -r num; do
        if (( num > INJECT_AFTER + INJECT_LINES )); then
            orig_num=$(( num - INJECT_LINES ))
        elif (( num <= INJECT_AFTER )); then
            orig_num=$num
        else
            continue  # line is inside the injected block
        fi
        HIT_LINES[$orig_num]=1
    done < "$TRACE_DIR/raw_hits.txt"
fi

TOTAL_HIT=${#HIT_LINES[@]}

if (( TOTAL_EXECUTABLE > 0 )); then
    PCT=$(( TOTAL_HIT * 100 / TOTAL_EXECUTABLE ))
else
    PCT=0
fi

echo ""
echo "Executable lines: $TOTAL_EXECUTABLE"
echo "Lines hit:        $TOTAL_HIT"
echo "Coverage:         ${PCT}%"
echo ""

# Show uncovered regions
echo "--- Uncovered regions ---"
IN_UNCOVERED=0
UNCOV_START=0
for (( LN = 1; LN <= _total_lines; LN++ )); do
    (( LINE_CLASS[LN] == 0 )) && continue

    if [[ -z "${HIT_LINES[$LN]:-}" ]]; then
        if (( ! IN_UNCOVERED )); then
            IN_UNCOVERED=1
            UNCOV_START=$LN
        fi
    else
        if (( IN_UNCOVERED )); then
            if (( LN > UNCOV_START + 1 )); then
                echo "  Lines ${UNCOV_START}-$((LN - 1))"
            else
                echo "  Line ${UNCOV_START}"
            fi
            IN_UNCOVERED=0
        fi
    fi
done
if (( IN_UNCOVERED )); then
    echo "  Lines ${UNCOV_START}-${LN}"
fi

# Generate HTML report
if (( HTML_MODE )); then
    mkdir -p "$COVERAGE_DIR"
    HTML="$COVERAGE_DIR/index.html"

    if (( PCT >= 75 )); then PCT_CLASS="high"
    elif (( PCT >= 50 )); then PCT_CLASS="med"
    else PCT_CLASS="low"
    fi

    {
        cat <<'HEADER'
<!DOCTYPE html><html><head><title>agent-watch coverage</title>
<style>
body{font-family:monospace;margin:20px;background:#1e1e1e;color:#d4d4d4}
h1{color:#dcdcaa}.summary{font-size:1.2em;margin:10px 0 20px}
.hit{background:#1e3a1e}.miss{background:#3a1e1e}.nocode{color:#666}
table{border-collapse:collapse;width:100%}
td{padding:1px 8px;white-space:pre}
td.ln{color:#888;text-align:right;border-right:1px solid #444;user-select:none;width:1%}
.pct{font-size:2em;font-weight:bold}
.pct.high{color:#4ec94e}.pct.med{color:#dcdcaa}.pct.low{color:#f44747}
</style></head><body>
HEADER
        echo "<h1>agent-watch coverage</h1>"
        echo "<div class=\"summary\"><span class=\"pct ${PCT_CLASS}\">${PCT}%</span> &mdash; ${TOTAL_HIT}/${TOTAL_EXECUTABLE} lines</div>"
        echo "<table>"

        LN=0
        while IFS= read -r line; do
            LN=$((LN + 1))
            esc="${line//&/&amp;}"
            esc="${esc//</&lt;}"
            esc="${esc//>/&gt;}"

            if (( LINE_CLASS[LN] == 0 )); then
                cls="nocode"
            elif [[ -n "${HIT_LINES[$LN]:-}" ]]; then
                cls="hit"
            else
                cls="miss"
            fi
            echo "<tr class=\"${cls}\"><td class=\"ln\">${LN}</td><td>${esc}</td></tr>"
        done < "$ORIG"

        echo "</table></body></html>"
    } > "$HTML"

    echo ""
    echo "HTML report: $COVERAGE_DIR/index.html"
fi

# Generate coverage badge SVG
_badge_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
_badge_text="${PCT}% @ ${_badge_sha}"
_badge_text_len=$(( ${#_badge_text} * 62 ))
_badge_text_x=$(( 630 + _badge_text_len / 2 ))
_badge_right_w=$(( _badge_text_len / 10 + 10 ))
_badge_w=$(( 63 + _badge_right_w ))

if (( PCT >= 80 )); then _badge_color="#4c1"
elif (( PCT >= 60 )); then _badge_color="#97ca00"
elif (( PCT >= 40 )); then _badge_color="#dfb317"
else _badge_color="#e05d44"
fi

cat > "coverage-badge.svg" <<BADGE_EOF
<svg xmlns="http://www.w3.org/2000/svg" width="${_badge_w}" height="20" role="img" aria-label="coverage: ${_badge_text}">
  <title>coverage: ${_badge_text}</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r"><rect width="${_badge_w}" height="20" rx="3" fill="#fff"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="63" height="20" fill="#555"/>
    <rect x="63" width="${_badge_right_w}" height="20" fill="${_badge_color}"/>
    <rect width="${_badge_w}" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text aria-hidden="true" x="325" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="530">coverage</text>
    <text x="325" y="140" transform="scale(.1)" fill="#fff" textLength="530">coverage</text>
    <text aria-hidden="true" x="${_badge_text_x}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="${_badge_text_len}">${_badge_text}</text>
    <text x="${_badge_text_x}" y="140" transform="scale(.1)" fill="#fff" textLength="${_badge_text_len}">${_badge_text}</text>
  </g>
</svg>
BADGE_EOF
echo "Badge: coverage-badge.svg (${PCT}% @ ${_badge_sha})"
