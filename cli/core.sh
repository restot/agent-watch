
_setup_colors() {
    if (( _COLOR )); then
        RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
        BLUE='\033[0;34m' MAGENTA='\033[0;35m' CYAN='\033[0;36m'
        NC='\033[0m' DIM='\033[2m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' NC='' DIM=''
    fi
}
_setup_colors

# Colorize @@TAG@@ markers in render pipeline; plain text when NO_COLOR
_color_sed() {
    if (( _COLOR )); then
        sed $'s/@@USER@@/\033[0;32m[USER]\033[0m/g' | \
        sed $'s/@@ASST@@/\033[0;35m[ASST]\033[0m/g' | \
        sed $'s/@@TOOL@@ \\([^ ]*\\) @@TOOLEND@@/\033[0;34m[TOOL]\033[0m \033[0;33m\\1\033[0m/g' | \
        sed $'s/@@RESULT@@/\033[2m[RESULT]/g' | \
        sed $'s/@@COMPACT@@/\033[1;36m[COMPACT]\033[0m/g' | \
        sed $'s/@@HOOK@@/\033[2;33m[HOOK]\033[0m/g' | \
        sed $'s/@@SUMMARY@@/\033[2;36m[SUMMARY]\033[0m/g' | \
        sed $'s/@@SYSTEM@@/\033[2m[SYSTEM]\033[0m/g'
    else
        sed 's/@@USER@@/[USER]/g' | \
        sed 's/@@ASST@@/[ASST]/g' | \
        sed 's/@@TOOL@@ \([^ ]*\) @@TOOLEND@@/[TOOL] \1/g' | \
        sed 's/@@RESULT@@/[RESULT]/g' | \
        sed 's/@@COMPACT@@/[COMPACT]/g' | \
        sed 's/@@HOOK@@/[HOOK]/g' | \
        sed 's/@@SUMMARY@@/[SUMMARY]/g' | \
        sed 's/@@SYSTEM@@/[SYSTEM]/g'
    fi
}

# Unbuffered variant for watch/tail -f
_color_sed_u() {
    if (( _COLOR )); then
        sed -u $'s/@@USER@@/\033[0;32m[USER]\033[0m/g' | \
        sed -u $'s/@@ASST@@/\033[0;35m[ASST]\033[0m/g' | \
        sed -u $'s/@@TOOL@@ \\([^ ]*\\) @@TOOLEND@@/\033[0;34m[TOOL]\033[0m \033[0;33m\\1\033[0m/g' | \
        sed -u $'s/@@RESULT@@/\033[2m[RESULT]\033[0m/g' | \
        sed -u $'s/@@COMPACT@@/\033[1;36m[COMPACT]\033[0m/g' | \
        sed -u $'s/@@HOOK@@/\033[2;33m[HOOK]\033[0m/g' | \
        sed -u $'s/@@SUMMARY@@/\033[2;36m[SUMMARY]\033[0m/g' | \
        sed -u $'s/@@SYSTEM@@/\033[2m[SYSTEM]\033[0m/g'
    else
        sed -u 's/@@USER@@/[USER]/g' | \
        sed -u 's/@@ASST@@/[ASST]/g' | \
        sed -u 's/@@TOOL@@ \([^ ]*\) @@TOOLEND@@/[TOOL] \1/g' | \
        sed -u 's/@@RESULT@@/[RESULT]/g' | \
        sed -u 's/@@COMPACT@@/[COMPACT]/g' | \
        sed -u 's/@@HOOK@@/[HOOK]/g' | \
        sed -u 's/@@SUMMARY@@/[SUMMARY]/g' | \
        sed -u 's/@@SYSTEM@@/[SYSTEM]/g'
    fi
}

die() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

debug() {
    [[ "$DEBUG" == "1" ]] && echo -e "${DIM}DEBUG: $1${NC}" || true
}

info() {
    echo -e "${BLUE}→${NC} $1"
}

# Format token counts: 1234 → 1.2k
_fmt_tokens() {
    local n="$1"
    if [[ $n -ge 1000000 ]]; then
        awk "BEGIN { printf \"%.1fM\", $n / 1000000 }"
    elif [[ $n -ge 1000 ]]; then
        awk "BEGIN { printf \"%.1fk\", $n / 1000 }"
    else
        echo "$n"
    fi
}
