#!/bin/bash
# shellcheck shell=bash

# lisa-flow.sh
# Structured Spec Kit workflow + Ralph-style self-healing test loop
# Lisa Flow by JohnCari
# Test loop inspired by Ralph Wiggum Loop (Geoffrey Huntley) - https://ghuntley.com/loop/

set -euo pipefail

# Bash version check (requires 4.0+ for associative arrays and features)
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: This script requires bash 4.0 or later"
    exit 1
fi

# Configuration constants
readonly MIN_WIDTH=75
readonly MAX_FEATURE_LEN=50
readonly MAX_LOG_LEN=40
readonly PROGRESS_BAR_WIDTH=30
readonly LOG_RETENTION_DAYS=7

# Parse flags
NO_COLOR=false
for arg in "$@"; do
    case "$arg" in
        --no-color) NO_COLOR=true; shift ;;
    esac
done

FEATURE="${1:-}"
MAX_TEST_ITERATIONS="${2:-5}"

# Colors (disabled with --no-color or NO_COLOR env var)
if [[ "$NO_COLOR" == "true" ]] || [[ "${NO_COLOR:-}" == "1" ]] || [[ ! -t 1 ]]; then
    G='' R='' Y='' C='' W='' D='' N='' O=''
else
    G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' D='\033[2m' N='\033[0m'
    O='\033[38;5;202m'  # Orange-red for shadow (Lisa Simpson style)
fi

# Validate FEATURE is provided
if [ -z "$FEATURE" ]; then
    echo ""
    if [[ -z "$G" ]]; then
        # No color version
        echo "██╗     ██╗███████╗ █████╗       ███████╗██╗      ██████╗ ██╗    ██╗"
        echo "██║     ██║██╔════╝██╔══██╗      ██╔════╝██║     ██╔═══██╗██║    ██║"
        echo "██║     ██║███████╗███████║█████╗█████╗  ██║     ██║   ██║██║ █╗ ██║"
        echo "██║     ██║╚════██║██╔══██║╚════╝██╔══╝  ██║     ██║   ██║██║███╗██║"
        echo "███████╗██║███████║██║  ██║      ██║     ███████╗╚██████╔╝╚███╔███╔╝"
        echo "╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝"
    else
        echo -e "${Y}██${O}╗     ${Y}██${O}╗${Y}███████${O}╗ ${Y}█████${O}╗       ${Y}███████${O}╗${Y}██${O}╗      ${Y}██████${O}╗ ${Y}██${O}╗    ${Y}██${O}╗${N}"
        echo -e "${Y}██${O}║     ${Y}██${O}║${Y}██${O}╔════╝${Y}██${O}╔══${Y}██${O}╗      ${Y}██${O}╔════╝${Y}██${O}║     ${Y}██${O}╔═══${Y}██${O}╗${Y}██${O}║    ${Y}██${O}║${N}"
        echo -e "${Y}██${O}║     ${Y}██${O}║${Y}███████${O}╗${Y}███████${O}║${W}█████${O}╗${Y}█████${O}╗  ${Y}██${O}║     ${Y}██${O}║   ${Y}██${O}║${Y}██${O}║ ${Y}█${O}╗ ${Y}██${O}║${N}"
        echo -e "${Y}██${O}║     ${Y}██${O}║╚════${Y}██${O}║${Y}██${O}╔══${Y}██${O}║╚════╝${Y}██${O}╔══╝  ${Y}██${O}║     ${Y}██${O}║   ${Y}██${O}║${Y}██${O}║${Y}███${O}╗${Y}██${O}║${N}"
        echo -e "${Y}███████${O}╗${Y}██${O}║${Y}███████${O}║${Y}██${O}║  ${Y}██${O}║      ${Y}██${O}║     ${Y}███████${O}╗╚${Y}██████${O}╔╝╚${Y}███${O}╔${Y}███${O}╔╝${N}"
        echo -e "${O}╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝${N}"
    fi
    echo ""
    echo -e "  Usage: ./lisa-flow.sh ${Y}<feature>${N} ${D}[test_retries]${N} ${D}[--no-color]${N}"
    echo ""
    echo -e "  ${W}<feature>${N}        Feature description"
    echo -e "  ${D}[test_retries]${N}   Max test attempts ${D}(default: 5)${N}"
    echo -e "  ${D}[--no-color]${N}     Disable colored output"
    echo ""
    exit 1
fi

# Validate FEATURE - reject potentially dangerous characters
if [[ "$FEATURE" =~ [\;\|\&\$\`\\] ]]; then
    echo "Error: Feature description contains invalid characters (; | & \$ \` \\)"
    exit 1
fi

# Validate MAX_TEST_ITERATIONS is a positive integer
if ! [[ "$MAX_TEST_ITERATIONS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: test_retries must be a positive integer"
    exit 1
fi

# Logs - secure permissions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
umask 077
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/lisa-flow_$(date +%Y-%m-%d_%H-%M-%S).log"

# Log rotation - delete logs older than LOG_RETENTION_DAYS
find "$LOG_DIR" -name "lisa-flow_*.log" -type f -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true

# Timezone (change to your timezone)
TZ="${TZ:-America/New_York}"
export TZ

# Cleanup trap - ensure clean exit
cleanup() {
    local exit_code=$?
    # Add any cleanup tasks here (temp files, etc.)
    exit $exit_code
}
trap cleanup EXIT

# Terminal width check
check_terminal_width() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    if [ "$cols" -lt "$MIN_WIDTH" ]; then
        echo -e "${Y}⚠ Terminal too narrow ($cols < $MIN_WIDTH)${N}"
        echo ""
    fi
}

# Phase tracking
TOTAL_PHASES=7
declare -a PHASE_TIMES=()
declare -a PHASE_NAMES=("SPECIFY" "PLAN" "TASKS" "IMPLEMENT" "BEAUTIFY" "REVIEW" "TEST")

# Context7 instructions
CONTEXT7_FULL="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."
CONTEXT7_NONE=""

# Error handling with line number and logging
PHASE="INIT"
error_handler() {
    local line_no=$1
    echo -e "\n${R}✗ Failed at: $PHASE (line $line_no)${N}\n" | tee -a "$LOG_FILE"
}
trap 'error_handler $LINENO' ERR
trap 'echo -e "\n${Y}Interrupted${N}\n"; exit 130' INT

log() { echo -e "$1" | tee -a "$LOG_FILE"; }

format_time() {
    local secs="${1:-0}"
    if [ "$secs" -ge 60 ]; then
        printf "%dm %ds" "$((secs / 60))" "$((secs % 60))"
    else
        printf "%ds" "$secs"
    fi
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
        local idx=$((i + 1))
        local name="${PHASE_NAMES[$i]}"
        local time="${PHASE_TIMES[$idx]:-}"
        local icon="${G}✓${N}"
        local time_str=""
        if [ -n "$time" ]; then
            time_str="$(format_time "$time")"
        else
            icon="${D}○${N}"
            time_str="-"
        fi
        log "  $icon $(printf '%-12s' "$name") $(printf '%10s' "$time_str")"
    done

    log ""
    log "${D}─────────────────────────────────────────────${N}"
    if [ "$status" = "success" ]; then
        log "  ${G}SUCCESS${N}  Total: $(format_time "$total_time")"
    else
        log "  ${R}FAILED${N}   Total: $(format_time "$total_time")"
    fi
    log ""
}

show_banner() {
    echo ""
    if [[ -z "$G" ]]; then
        echo "██╗     ██╗███████╗ █████╗       ███████╗██╗      ██████╗ ██╗    ██╗"
        echo "██║     ██║██╔════╝██╔══██╗      ██╔════╝██║     ██╔═══██╗██║    ██║"
        echo "██║     ██║███████╗███████║█████╗█████╗  ██║     ██║   ██║██║ █╗ ██║"
        echo "██║     ██║╚════██║██╔══██║╚════╝██╔══╝  ██║     ██║   ██║██║███╗██║"
        echo "███████╗██║███████║██║  ██║      ██║     ███████╗╚██████╔╝╚███╔███╔╝"
        echo "╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝"
    else
        echo -e "${Y}██${O}╗     ${Y}██${O}╗${Y}███████${O}╗ ${Y}█████${O}╗       ${Y}███████${O}╗${Y}██${O}╗      ${Y}██████${O}╗ ${Y}██${O}╗    ${Y}██${O}╗${N}"
        echo -e "${Y}██${O}║     ${Y}██${O}║${Y}██${O}╔════╝${Y}██${O}╔══${Y}██${O}╗      ${Y}██${O}╔════╝${Y}██${O}║     ${Y}██${O}╔═══${Y}██${O}╗${Y}██${O}║    ${Y}██${O}║${N}"
        echo -e "${Y}██${O}║     ${Y}██${O}║${Y}███████${O}╗${Y}███████${O}║${W}█████${O}╗${Y}█████${O}╗  ${Y}██${O}║     ${Y}██${O}║   ${Y}██${O}║${Y}██${O}║ ${Y}█${O}╗ ${Y}██${O}║${N}"
        echo -e "${Y}██${O}║     ${Y}██${O}║╚════${Y}██${O}║${Y}██${O}╔══${Y}██${O}║╚════╝${Y}██${O}╔══╝  ${Y}██${O}║     ${Y}██${O}║   ${Y}██${O}║${Y}██${O}║${Y}███${O}╗${Y}██${O}║${N}"
        echo -e "${Y}███████${O}╗${Y}██${O}║${Y}███████${O}║${Y}██${O}║  ${Y}██${O}║      ${Y}██${O}║     ${Y}███████${O}╗╚${Y}██████${O}╔╝╚${Y}███${O}╔${Y}███${O}╔╝${N}"
        echo -e "${O}╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝${N}"
    fi
    echo ""
}

# Run a phase with array-based command execution (no eval)
# Usage: run_phase <num> <name> <command> [args...]
# Returns: 0 on success, non-zero on failure
run_phase() {
    local num="$1" name="$2"
    shift 2
    local -a cmd=("$@")
    PHASE="$name"
    local start=$SECONDS
    local exit_code=0

    log "${D}[${G}$(progress_bar "$num" "$TOTAL_PHASES")${D}]${N} ${num}/${TOTAL_PHASES} ${Y}$name${N}"

    # Run command, log output, only show on error
    local output
    output=$("${cmd[@]}" 2>&1) || exit_code=$?
    printf '%s\n' "$output" >> "$LOG_FILE"

    if [ "$exit_code" -ne 0 ]; then
        printf '%s\n' "$output"
        return "$exit_code"
    fi

    local elapsed=$((SECONDS - start))
    PHASE_TIMES[$num]=$elapsed

    log "${G}✓${N} $name ${D}($(format_time "$elapsed"))${N}"
    log ""
}

# Find the latest tasks.md file safely using glob
# Returns: Path to latest tasks.md or empty string if not found
find_tasks_file() {
    local spec_dir="${SCRIPT_DIR}/../specs"
    shopt -s nullglob
    local -a tasks_files=("$spec_dir"/*/tasks.md)
    shopt -u nullglob

    if [ ${#tasks_files[@]} -eq 0 ]; then
        echo ""
        return
    fi

    # Sort by modification time and get the latest
    local latest=""
    local latest_time=0
    for f in "${tasks_files[@]}"; do
        local mtime
        mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$latest_time" ]; then
            latest_time=$mtime
            latest="$f"
        fi
    done
    echo "$latest"
}

# ============================================================================
# PROMPT DEFINITIONS (heredocs for easy editing)
# ============================================================================

PROMPT_SPECIFY=$(cat <<EOF
/speckit.specify $FEATURE. Include comprehensive tests following Test Driven Development. $CONTEXT7_FULL
EOF
)

PROMPT_PLAN=$(cat <<EOF
/speckit.plan $CONTEXT7_FULL
EOF
)

PROMPT_TASKS=$(cat <<EOF
/speckit.tasks $CONTEXT7_NONE
EOF
)

PROMPT_IMPLEMENT=$(cat <<EOF
/speckit.implement $CONTEXT7_FULL
EOF
)

# TASKS_FILE will be set after TASKS phase, so BEAUTIFY/REVIEW/TEST prompts are defined later

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Use SECONDS builtin for timing
SECONDS=0
START_TOTAL=$SECONDS

show_banner
check_terminal_width

# Truncate feature if too long
display_feature="$FEATURE"
if [ "${#FEATURE}" -gt "$MAX_FEATURE_LEN" ]; then
    display_feature="${FEATURE:0:$MAX_FEATURE_LEN}..."
fi

# Truncate log path if too long
display_log="$LOG_FILE"
if [ "${#LOG_FILE}" -gt "$MAX_LOG_LEN" ]; then
    display_log="...${LOG_FILE: -$MAX_LOG_LEN}"
fi

log "  Feature        ${W}$display_feature${N}"
log "  Test Retries   ${W}$MAX_TEST_ITERATIONS${N}"
log "  Log            ${D}$display_log${N}"
log ""

# Phase 1-3: Specification workflow
run_phase 1 "SPECIFY" claude -p --dangerously-skip-permissions "$PROMPT_SPECIFY"
run_phase 2 "PLAN" claude -p --dangerously-skip-permissions "$PROMPT_PLAN"
run_phase 3 "TASKS" claude -p --dangerously-skip-permissions "$PROMPT_TASKS"

# Find tasks file once after TASKS phase
TASKS_FILE=$(find_tasks_file)
if [ -z "$TASKS_FILE" ]; then
    log "${R}✗ No tasks.md found after TASKS phase${N}"
    exit 1
fi
printf '%s\n' "Using tasks file: $TASKS_FILE" >> "$LOG_FILE"

# Define remaining prompts now that TASKS_FILE is available
PROMPT_BEAUTIFY=$(cat <<EOF
/frontend-design:frontend-design Read $TASKS_FILE to understand the feature requirements.
Then review all implemented code files to understand the current UI.
Improve the UI/UX applying best practices:
- Visual consistency
- Accessibility
- HCI principles
- Intuitive layouts
- Proper spacing
- Typography
- Smooth interactions
$CONTEXT7_FULL
EOF
)

PROMPT_REVIEW=$(cat <<EOF
Read $TASKS_FILE to understand the feature requirements.
Then use the Task tool to spawn a coderabbit:code-reviewer agent to perform a thorough code review of all implemented files.

The review must cover:
1) Code quality and bugs
2) Performance issues
3) Security vulnerabilities following OWASP guidelines

Apply all fixes recommended by the review.
EOF
)

PROMPT_TEST=$(cat <<EOF
Read $TASKS_FILE to understand the feature requirements.
Run all tests.
Fix failures in implementation code (don't modify tests).
Output ALL_TESTS_PASS when done or TESTS_FAILED if stuck.
$CONTEXT7_FULL
EOF
)

# Phase 4: Implementation
run_phase 4 "IMPLEMENT" claude -p --dangerously-skip-permissions "$PROMPT_IMPLEMENT"

# Phase 5: BEAUTIFY
run_phase 5 "BEAUTIFY" claude -p --dangerously-skip-permissions "$PROMPT_BEAUTIFY"

# Phase 6: REVIEW
run_phase 6 "REVIEW" claude -p --dangerously-skip-permissions "$PROMPT_REVIEW"

# Phase 7: TEST - Self-healing loop
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

# Show output if tests failed
printf '%s\n' "$RESULT"

elapsed_test=$((SECONDS - START_TEST))
PHASE_TIMES[7]=$elapsed_test
elapsed=$((SECONDS - START_TOTAL))
print_summary "failed" "$elapsed"
log "${D}Log: $LOG_FILE${N}"
log ""
exit 1
