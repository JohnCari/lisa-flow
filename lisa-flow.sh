#!/bin/bash
# shellcheck shell=bash
# lisa-flow.sh - Structured Spec Kit workflow + Ralph-style self-healing test loop

set -euo pipefail

readonly MAX_FEATURE_LEN=50
readonly MAX_LOG_LEN=40
readonly PROGRESS_BAR_WIDTH=30
readonly LOG_RETENTION_DAYS=7
readonly SPEC_DIR_REL="../specs"  # Relative to script directory

FEATURE_INPUT="${1:-}"
MAX_TEST_ITERATIONS="${2:-5}"

# Colors
GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' CYAN='\033[0;36m' WHITE='\033[1;37m' DIM='\033[2m' RESET='\033[0m'
ORANGE='\033[38;5;202m'

show_banner() {
    echo ""
    echo -e "${YELLOW}██${ORANGE}╗     ${YELLOW}██${ORANGE}╗${YELLOW}███████${ORANGE}╗ ${YELLOW}█████${ORANGE}╗       ${YELLOW}███████${ORANGE}╗${YELLOW}██${ORANGE}╗      ${YELLOW}██████${ORANGE}╗ ${YELLOW}██${ORANGE}╗    ${YELLOW}██${ORANGE}╗${RESET}"
    echo -e "${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}╔════╝${YELLOW}██${ORANGE}╔══${YELLOW}██${ORANGE}╗      ${YELLOW}██${ORANGE}╔════╝${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}╔═══${YELLOW}██${ORANGE}╗${YELLOW}██${ORANGE}║    ${YELLOW}██${ORANGE}║${RESET}"
    echo -e "${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║${YELLOW}███████${ORANGE}╗${YELLOW}███████${ORANGE}║${WHITE}█████${ORANGE}╗${YELLOW}█████${ORANGE}╗  ${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║   ${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}║ ${YELLOW}█${ORANGE}╗ ${YELLOW}██${ORANGE}║${RESET}"
    echo -e "${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║╚════${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}╔══${YELLOW}██${ORANGE}║╚════╝${YELLOW}██${ORANGE}╔══╝  ${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║   ${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}║${YELLOW}███${ORANGE}╗${YELLOW}██${ORANGE}║${RESET}"
    echo -e "${YELLOW}███████${ORANGE}╗${YELLOW}██${ORANGE}║${YELLOW}███████${ORANGE}║${YELLOW}██${ORANGE}║  ${YELLOW}██${ORANGE}║      ${YELLOW}██${ORANGE}║     ${YELLOW}███████${ORANGE}╗╚${YELLOW}██████${ORANGE}╔╝╚${YELLOW}███${ORANGE}╔${YELLOW}███${ORANGE}╔╝${RESET}"
    echo -e "${ORANGE}╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝${RESET}"
    echo ""
}

if [ -z "$FEATURE_INPUT" ]; then
    show_banner
    echo -e "  Usage: ./lisa-flow.sh ${YELLOW}<feature>${RESET} ${DIM}[retries]${RESET}"
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

TOTAL_PHASES=6
declare -a PHASE_TIMES=()
declare -a PHASE_NAMES=("SPECIFY" "PLAN" "TASKS" "IMPLEMENT" "BEAUTIFY" "TEST")

CONTEXT7="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."

PHASE="INIT"
error_handler() { echo -e "\n${RED}✗ Failed at: $PHASE (line $1)${RESET}\n" | tee -a "$LOG_FILE"; }
trap 'error_handler $LINENO' ERR
trap 'echo -e "\n${YELLOW}Interrupted${RESET}\n"; exit 130' INT  # 128 + SIGINT(2)

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
    log "${DIM}─────────────────────────────────────────────${RESET}"
    log ""
    for i in "${!PHASE_NAMES[@]}"; do
        local idx=$((i + 1)) name="${PHASE_NAMES[$i]}" time="${PHASE_TIMES[$idx]:-}"
        local icon="${GREEN}✓${RESET}" time_str=""
        if [ -n "$time" ]; then time_str="$(format_time "$time")"; else icon="${DIM}○${RESET}"; time_str="-"; fi
        log "  $icon $(printf '%-12s' "$name") $(printf '%10s' "$time_str")"
    done
    log ""
    log "${DIM}─────────────────────────────────────────────${RESET}"
    if [ "$status" = "success" ]; then log "  ${GREEN}SUCCESS${RESET}  Total: $(format_time "$total_time")"
    else log "  ${RED}FAILED${RESET}   Total: $(format_time "$total_time")"; fi
    log ""
}

run_phase() {
    local num="$1" name="$2"; shift 2
    local -a cmd=("$@")
    PHASE="$name"
    local start=$SECONDS exit_code=0
    log "${DIM}[${GREEN}$(progress_bar "$num" "$TOTAL_PHASES")${DIM}]${RESET} ${num}/${TOTAL_PHASES} ${YELLOW}$name${RESET}"
    local output
    output=$("${cmd[@]}" 2>&1) || exit_code=$?
    printf '%s\n' "$output" >> "$LOG_FILE"
    if [ "$exit_code" -ne 0 ]; then printf '%s\n' "$output"; return "$exit_code"; fi
    local elapsed=$((SECONDS - start))
    PHASE_TIMES[$num]=$elapsed
    log "${GREEN}✓${RESET} $name ${DIM}($(format_time "$elapsed"))${RESET}"
    log ""
}

find_tasks_file() {
    local spec_dir="${SCRIPT_DIR}/${SPEC_DIR_REL}"
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

show_banner

display_feature="$FEATURE"
[ "${#FEATURE}" -gt "$MAX_FEATURE_LEN" ] && display_feature="${FEATURE:0:$MAX_FEATURE_LEN}..."
display_log="$LOG_FILE"
[ "${#LOG_FILE}" -gt "$MAX_LOG_LEN" ] && display_log="...${LOG_FILE: -$MAX_LOG_LEN}"

log "  Feature        ${WHITE}$display_feature${RESET}"
log "  Test Retries   ${WHITE}$MAX_TEST_ITERATIONS${RESET}"
log "  Log            ${DIM}$display_log${RESET}"
log ""

run_phase 1 "SPECIFY" claude -p --dangerously-skip-permissions "$PROMPT_SPECIFY"
run_phase 2 "PLAN" claude -p --dangerously-skip-permissions "$PROMPT_PLAN"
run_phase 3 "TASKS" claude -p --dangerously-skip-permissions "$PROMPT_TASKS"

TASKS_FILE=$(find_tasks_file)
[ -z "$TASKS_FILE" ] && { log "${RED}✗ No tasks.md found after TASKS phase${RESET}"; exit 1; }
printf '%s\n' "Using tasks file: $TASKS_FILE" >> "$LOG_FILE"

PROMPT_TEST="Read $TASKS_FILE. Perform these checks and fix any issues:
1. Run all tests - fix failures in implementation (don't modify tests)
2. Code quality - fix bugs, dead code, magic numbers, code smells
3. Security - check and fix OWASP vulnerabilities
4. Performance - fix inefficiencies
Output ALL_TESTS_PASS when all checks pass or TESTS_FAILED if stuck. $CONTEXT7"

run_phase 4 "IMPLEMENT" claude -p --dangerously-skip-permissions "$PROMPT_IMPLEMENT"

# BEAUTIFY - only session's frontend files, but maintain design coherence
FRONTEND_PATTERNS=("*.tsx" "*.jsx" "*.ts" "*.js" "*.css" "*.html")
if [ -n "$START_COMMIT" ]; then
    CHANGED_FRONTEND=$(git diff --name-only "$START_COMMIT" -- "${FRONTEND_PATTERNS[@]}" 2>/dev/null | tr '\n' ' ')
else
    CHANGED_FRONTEND=""
fi

if [ -n "$CHANGED_FRONTEND" ]; then
    PROMPT_BEAUTIFY="/frontend-design:frontend-design MODIFY ONLY these files: $CHANGED_FRONTEND
But FIRST review existing app design (components, styles, tailwind config) to ensure coherence.
Improve UI/UX: visual consistency with existing design, accessibility, HCI, layouts, spacing, typography, interactions. $CONTEXT7"
    run_phase 5 "BEAUTIFY" claude -p --dangerously-skip-permissions "$PROMPT_BEAUTIFY"
else
    log "${DIM}○${RESET} BEAUTIFY ${DIM}(skipped - no frontend files)${RESET}"
    log ""
fi

# TEST - Self-healing loop with code quality review
PHASE="TEST"
START_TEST=$SECONDS
log "${DIM}[${GREEN}$(progress_bar "$TOTAL_PHASES" "$TOTAL_PHASES")${DIM}]${RESET} ${TOTAL_PHASES}/${TOTAL_PHASES} ${YELLOW}TEST${RESET}"

iteration=0
RESULT=""
while [ "$iteration" -lt "$MAX_TEST_ITERATIONS" ]; do
    iteration=$((iteration + 1))
    log "  ${CYAN}↻${RESET} Attempt $iteration/$MAX_TEST_ITERATIONS"
    RESULT=$(claude -p --dangerously-skip-permissions "$PROMPT_TEST" 2>&1)
    printf '%s\n' "$RESULT" >> "$LOG_FILE"
    if printf '%s' "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        elapsed_test=$((SECONDS - START_TEST))
        PHASE_TIMES[$TOTAL_PHASES]=$elapsed_test
        elapsed=$SECONDS
        log "${GREEN}✓${RESET} TEST ${DIM}($(format_time "$elapsed_test"))${RESET}"
        print_summary "success" "$elapsed"
        log "${DIM}Log: $LOG_FILE${RESET}"
        log ""
        exit 0
    fi
done

printf '%s\n' "$RESULT"
elapsed_test=$((SECONDS - START_TEST))
PHASE_TIMES[$TOTAL_PHASES]=$elapsed_test
elapsed=$SECONDS
print_summary "failed" "$elapsed"
log "${DIM}Log: $LOG_FILE${RESET}"
log ""
exit 1
