#!/bin/bash
# shellcheck shell=bash
# lisa-flow.sh - Structured Spec Kit workflow + Ralph-style self-healing test loop

set -euo pipefail

readonly MAX_FEATURE_LEN=50
readonly MAX_LOG_LEN=40
readonly PROGRESS_BAR_WIDTH=30
readonly LOG_RETENTION_DAYS=7

FEATURE_INPUT="${1:-}"
MAX_TEST_ITERATIONS="${2:-5}"

# Colors
G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' D='\033[2m' N='\033[0m'
O='\033[38;5;202m'

show_banner() {
    echo ""
    echo -e "${Y}██${O}╗     ${Y}██${O}╗${Y}███████${O}╗ ${Y}█████${O}╗       ${Y}███████${O}╗${Y}██${O}╗      ${Y}██████${O}╗ ${Y}██${O}╗    ${Y}██${O}╗${N}"
    echo -e "${Y}██${O}║     ${Y}██${O}║${Y}██${O}╔════╝${Y}██${O}╔══${Y}██${O}╗      ${Y}██${O}╔════╝${Y}██${O}║     ${Y}██${O}╔═══${Y}██${O}╗${Y}██${O}║    ${Y}██${O}║${N}"
    echo -e "${Y}██${O}║     ${Y}██${O}║${Y}███████${O}╗${Y}███████${O}║${W}█████${O}╗${Y}█████${O}╗  ${Y}██${O}║     ${Y}██${O}║   ${Y}██${O}║${Y}██${O}║ ${Y}█${O}╗ ${Y}██${O}║${N}"
    echo -e "${Y}██${O}║     ${Y}██${O}║╚════${Y}██${O}║${Y}██${O}╔══${Y}██${O}║╚════╝${Y}██${O}╔══╝  ${Y}██${O}║     ${Y}██${O}║   ${Y}██${O}║${Y}██${O}║${Y}███${O}╗${Y}██${O}║${N}"
    echo -e "${Y}███████${O}╗${Y}██${O}║${Y}███████${O}║${Y}██${O}║  ${Y}██${O}║      ${Y}██${O}║     ${Y}███████${O}╗╚${Y}██████${O}╔╝╚${Y}███${O}╔${Y}███${O}╔╝${N}"
    echo -e "${O}╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝${N}"
    echo ""
}

if [ -z "$FEATURE_INPUT" ]; then
    show_banner
    echo -e "  Usage: ./lisa-flow.sh ${Y}<feature>${N} ${D}[retries]${N}"
    echo -e "         feature: text or @file"
    echo ""
    exit 1
fi

resolve_feature_input() {
    local input="$1"
    if [[ "$input" == @* ]]; then
        local file="${input:1}"
        [[ -f "$file" ]] || { echo "Error: File not found: $file" >&2; return 1; }
        cat "$file"
    else
        printf '%s' "$input"
    fi
}

FEATURE=$(resolve_feature_input "$FEATURE_INPUT") || exit 1

[[ "$MAX_TEST_ITERATIONS" =~ ^[1-9][0-9]*$ ]] || { echo "Error: retries must be a positive integer"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/lisa-flow_$(date +%Y-%m-%d_%H-%M-%S).log"

find "$LOG_DIR" -name "lisa-flow_*.log" -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true

TZ="${TZ:-America/New_York}"
export TZ

# Capture git state for scoped BEAUTIFY
START_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")

TOTAL_PHASES=7
declare -a PHASE_TIMES=()
declare -a PHASE_NAMES=("SPECIFY" "PLAN" "TASKS" "IMPLEMENT" "BEAUTIFY" "REVIEW" "TEST")

CONTEXT7="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."

PHASE="INIT"
error_handler() { echo -e "\n${R}✗ Failed at: $PHASE (line $1)${N}\n" | tee -a "$LOG_FILE"; }
trap 'error_handler $LINENO' ERR
trap 'echo -e "\n${Y}Interrupted${N}\n"; exit 130' INT

log() { echo -e "$1" | tee -a "$LOG_FILE"; }

format_time() {
    local secs="${1:-0}"
    if [ "$secs" -ge 60 ]; then printf "%dm %ds" "$((secs / 60))" "$((secs % 60))"; else printf "%ds" "$secs"; fi
}

progress_bar() {
    local current="$1" total="$2"
    local filled=$((current * PROGRESS_BAR_WIDTH / total))
    local empty=$((PROGRESS_BAR_WIDTH - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "%s" "$bar"
}

print_summary() {
    local status="$1" total_time="$2"
    log ""
    log "${D}─────────────────────────────────────────────${N}"
    log ""
    for i in "${!PHASE_NAMES[@]}"; do
        local idx=$((i + 1)) name="${PHASE_NAMES[$i]}" time="${PHASE_TIMES[$idx]:-}"
        local icon="${G}✓${N}" time_str=""
        if [ -n "$time" ]; then time_str="$(format_time "$time")"; else icon="${D}○${N}"; time_str="-"; fi
        log "  $icon $(printf '%-12s' "$name") $(printf '%10s' "$time_str")"
    done
    log ""
    log "${D}─────────────────────────────────────────────${N}"
    if [ "$status" = "success" ]; then log "  ${G}SUCCESS${N}  Total: $(format_time "$total_time")"
    else log "  ${R}FAILED${N}   Total: $(format_time "$total_time")"; fi
    log ""
}

run_phase() {
    local num="$1" name="$2"; shift 2
    local -a cmd=("$@")
    PHASE="$name"
    local start=$SECONDS exit_code=0
    log "${D}[${G}$(progress_bar "$num" "$TOTAL_PHASES")${D}]${N} ${num}/${TOTAL_PHASES} ${Y}$name${N}"
    local output
    output=$("${cmd[@]}" 2>&1) || exit_code=$?
    printf '%s\n' "$output" >> "$LOG_FILE"
    if [ "$exit_code" -ne 0 ]; then printf '%s\n' "$output"; return "$exit_code"; fi
    local elapsed=$((SECONDS - start))
    PHASE_TIMES[$num]=$elapsed
    log "${G}✓${N} $name ${D}($(format_time "$elapsed"))${N}"
    log ""
}

find_tasks_file() {
    local spec_dir="${SCRIPT_DIR}/../specs"
    shopt -s nullglob
    local -a tasks_files=("$spec_dir"/*/tasks.md)
    shopt -u nullglob
    [ ${#tasks_files[@]} -eq 0 ] && { echo ""; return; }
    local latest="" latest_time=0
    for f in "${tasks_files[@]}"; do
        local mtime; mtime=$(stat -c %Y "$f")
        [ "$mtime" -gt "$latest_time" ] && { latest_time=$mtime; latest="$f"; }
    done
    echo "$latest"
}

# Prompts
PROMPT_SPECIFY="/speckit.specify $FEATURE. Include comprehensive tests following Test Driven Development. $CONTEXT7"
PROMPT_PLAN="/speckit.plan $CONTEXT7"
PROMPT_TASKS="/speckit.tasks"
PROMPT_IMPLEMENT="/speckit.implement $CONTEXT7"

# Main
SECONDS=0
START_TOTAL=$SECONDS

show_banner

display_feature="$FEATURE"
[ "${#FEATURE}" -gt "$MAX_FEATURE_LEN" ] && display_feature="${FEATURE:0:$MAX_FEATURE_LEN}..."
display_log="$LOG_FILE"
[ "${#LOG_FILE}" -gt "$MAX_LOG_LEN" ] && display_log="...${LOG_FILE: -$MAX_LOG_LEN}"

log "  Feature        ${W}$display_feature${N}"
log "  Test Retries   ${W}$MAX_TEST_ITERATIONS${N}"
log "  Log            ${D}$display_log${N}"
log ""

run_phase 1 "SPECIFY" claude -p --dangerously-skip-permissions "$PROMPT_SPECIFY"
run_phase 2 "PLAN" claude -p --dangerously-skip-permissions "$PROMPT_PLAN"
run_phase 3 "TASKS" claude -p --dangerously-skip-permissions "$PROMPT_TASKS"

TASKS_FILE=$(find_tasks_file)
[ -z "$TASKS_FILE" ] && { log "${R}✗ No tasks.md found after TASKS phase${N}"; exit 1; }
printf '%s\n' "Using tasks file: $TASKS_FILE" >> "$LOG_FILE"

PROMPT_REVIEW="Read $TASKS_FILE. Use Task tool to spawn coderabbit:code-reviewer agent for code review covering: 1) Code quality/bugs 2) Performance 3) Security (OWASP). Apply all fixes."
PROMPT_TEST="Read $TASKS_FILE. Run all tests. Fix failures in implementation (don't modify tests). Output ALL_TESTS_PASS when done or TESTS_FAILED if stuck. $CONTEXT7"

run_phase 4 "IMPLEMENT" claude -p --dangerously-skip-permissions "$PROMPT_IMPLEMENT"

# BEAUTIFY - only session's frontend files, but maintain design coherence
FRONTEND_PATTERNS="*.tsx *.jsx *.ts *.js *.css *.html"
if [ -n "$START_COMMIT" ]; then
    CHANGED_FRONTEND=$(git diff --name-only "$START_COMMIT" -- $FRONTEND_PATTERNS 2>/dev/null | tr '\n' ' ')
else
    CHANGED_FRONTEND=""
fi

if [ -n "$CHANGED_FRONTEND" ]; then
    PROMPT_BEAUTIFY="/frontend-design:frontend-design MODIFY ONLY these files: $CHANGED_FRONTEND
But FIRST review existing app design (components, styles, tailwind config) to ensure coherence.
Improve UI/UX: visual consistency with existing design, accessibility, HCI, layouts, spacing, typography, interactions. $CONTEXT7"
    run_phase 5 "BEAUTIFY" claude -p --dangerously-skip-permissions "$PROMPT_BEAUTIFY"
else
    log "${D}○${N} BEAUTIFY ${D}(skipped - no frontend files)${N}"
    log ""
fi

run_phase 6 "REVIEW" claude -p --dangerously-skip-permissions "$PROMPT_REVIEW"

# TEST - Self-healing loop
PHASE="TEST"
START_TEST=$SECONDS
log "${D}[${G}$(progress_bar 7 "$TOTAL_PHASES")${D}]${N} 7/${TOTAL_PHASES} ${Y}TEST${N}"

iteration=0
RESULT=""
while [ "$iteration" -lt "$MAX_TEST_ITERATIONS" ]; do
    iteration=$((iteration + 1))
    log "  ${C}↻${N} Attempt $iteration/$MAX_TEST_ITERATIONS"
    RESULT=$(claude -p --dangerously-skip-permissions "$PROMPT_TEST" 2>&1)
    printf '%s\n' "$RESULT" >> "$LOG_FILE"
    if printf '%s' "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        elapsed_test=$((SECONDS - START_TEST))
        PHASE_TIMES[7]=$elapsed_test
        elapsed=$((SECONDS - START_TOTAL))
        log "${G}✓${N} TEST ${D}($(format_time "$elapsed_test"))${N}"
        print_summary "success" "$elapsed"
        log "${D}Log: $LOG_FILE${N}"
        log ""
        exit 0
    fi
done

printf '%s\n' "$RESULT"
elapsed_test=$((SECONDS - START_TEST))
PHASE_TIMES[7]=$elapsed_test
elapsed=$((SECONDS - START_TOTAL))
print_summary "failed" "$elapsed"
log "${D}Log: $LOG_FILE${N}"
log ""
exit 1
