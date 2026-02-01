#!/bin/bash

# lisa-flow.sh
# Structured Spec Kit workflow + Ralph-style self-healing test loop
# Lisa Flow by JohnCari
# Test loop inspired by Ralph Wiggum Loop (Geoffrey Huntley) - https://ghuntley.com/loop/

set -e

FEATURE="$1"
MAX_TEST_ITERATIONS="${2:-5}"

# Logs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/lisa-flow_$(date +%m-%d-%Y_%-I-%M-%S%p).log"

# Timezone (change to your timezone)
TZ="${TZ:-America/New_York}"
export TZ

# Colors
G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' D='\033[2m' N='\033[0m'
O='\033[38;5;202m'  # Orange-red for shadow (Lisa Simpson style)

# Terminal width check
MIN_WIDTH=75
check_terminal_width() {
    local cols=$(tput cols 2>/dev/null || echo 80)
    if [ "$cols" -lt "$MIN_WIDTH" ]; then
        echo -e "${Y}⚠ Terminal too narrow ($cols < $MIN_WIDTH)${N}"
        echo ""
    fi
}

# Phase tracking
TOTAL_PHASES=7
declare -a PHASE_TIMES=()
declare -a PHASE_NAMES=("SPECIFY" "PLAN" "TASKS" "IMPLEMENT" "BEAUTIFY" "SECURITY" "TEST")

# Context7 instructions - phase-specific
CONTEXT7_FULL="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."
CONTEXT7_NONE=""

# Error handling
PHASE="INIT"
trap 'echo -e "\n${R}✗ Failed at: $PHASE${N}\n"' ERR
trap 'echo -e "\n${Y}Interrupted${N}\n"; exit 130' INT

log() { echo -e "$1" | tee -a "$LOG_FILE"; }

format_time() {
    local secs=$1
    if [ $secs -ge 60 ]; then
        printf "%dm %ds" $((secs / 60)) $((secs % 60))
    else
        printf "%ds" $secs
    fi
}

progress_bar() {
    local current=$1 total=$2
    local width=30
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "%s" "$bar"
}

print_summary() {
    local status=$1 total_time=$2
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
            time_str="$(format_time $time)"
        else
            icon="${D}○${N}"
            time_str="-"
        fi
        log "  $icon $(printf '%-12s' "$name") $(printf '%10s' "$time_str")"
    done

    log ""
    log "${D}─────────────────────────────────────────────${N}"
    if [ "$status" = "success" ]; then
        log "  ${G}SUCCESS${N}  Total: $(format_time $total_time)"
    else
        log "  ${R}FAILED${N}   Total: $(format_time $total_time)"
    fi
    log ""
}

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

if [ -z "$FEATURE" ]; then
    show_banner
    echo -e "  Usage: ./lisa-flow.sh ${Y}<feature>${N} ${D}[test_retries]${N}"
    echo ""
    echo -e "  ${W}<feature>${N}        Feature description"
    echo -e "  ${D}[test_retries]${N}   Max test attempts ${D}(default: 5)${N}"
    echo ""
    exit 1
fi

START_TOTAL=$(date +%s)

show_banner
check_terminal_width

# Truncate feature if too long
display_feature="$FEATURE"
max_feature_len=50
if [ ${#FEATURE} -gt $max_feature_len ]; then
    display_feature="${FEATURE:0:$max_feature_len}..."
fi

# Truncate log path if too long
display_log="$LOG_FILE"
max_log_len=40
if [ ${#LOG_FILE} -gt $max_log_len ]; then
    display_log="...${LOG_FILE: -$max_log_len}"
fi

log "  Feature        ${W}$display_feature${N}"
log "  Test Retries   ${W}$MAX_TEST_ITERATIONS${N}"
log "  Log            ${D}$display_log${N}"
log ""

run_phase() {
    local num=$1 name=$2 cmd=$3
    PHASE="$name"
    local start=$(date +%s)
    local exit_code=0

    log "${D}[${G}$(progress_bar $num $TOTAL_PHASES)${D}]${N} ${num}/${TOTAL_PHASES} ${Y}$name${N}"

    # Run command, log output, only show on error
    local output
    output=$(eval "$cmd" 2>&1) || exit_code=$?
    echo "$output" >> "$LOG_FILE"

    if [ "$exit_code" -ne 0 ]; then
        echo "$output"
        return $exit_code
    fi

    local elapsed=$(($(date +%s) - start))
    PHASE_TIMES[$num]=$elapsed

    log "${G}✓${N} $name ${D}($(format_time $elapsed))${N}"
    log ""
}

run_phase 1 "SPECIFY" "claude -p --dangerously-skip-permissions \"/speckit.specify $FEATURE. Include comprehensive tests following Test Driven Development. $CONTEXT7_FULL\""
run_phase 2 "PLAN" "claude -p --dangerously-skip-permissions \"/speckit.plan $CONTEXT7_FULL\""
run_phase 3 "TASKS" "claude -p --dangerously-skip-permissions \"/speckit.tasks $CONTEXT7_NONE\""
run_phase 4 "IMPLEMENT" "claude -p --dangerously-skip-permissions \"/speckit.implement $CONTEXT7_FULL\""

# BEAUTIFY phase
PHASE="BEAUTIFY"
START=$(date +%s)
exit_code=0
log "${D}[${G}$(progress_bar 5 $TOTAL_PHASES)${D}]${N} 5/${TOTAL_PHASES} ${Y}BEAUTIFY${N}"

LATEST_TASKS=$(ls -t specs/*/tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_TASKS" ]; then
    log "${R}✗ No tasks.md found${N}"
    exit 0
fi
echo "Using: $LATEST_TASKS" >> "$LOG_FILE"

output=$(claude -p --dangerously-skip-permissions "/frontend-design:frontend-design Read $LATEST_TASKS to understand the feature requirements. Then review all implemented code files to understand the current UI. Improve the UI/UX applying best practices: visual consistency, accessibility, HCI principles, intuitive layouts, proper spacing, typography, and smooth interactions. $CONTEXT7_FULL" 2>&1) || exit_code=$?
echo "$output" >> "$LOG_FILE"
if [ "$exit_code" -ne 0 ]; then
    echo "$output"
    exit $exit_code
fi

elapsed=$(($(date +%s) - START))
PHASE_TIMES[5]=$elapsed
log "${G}✓${N} BEAUTIFY ${D}($(format_time $elapsed))${N}"
log ""

# SECURITY phase
PHASE="SECURITY"
START=$(date +%s)
exit_code=0
log "${D}[${G}$(progress_bar 6 $TOTAL_PHASES)${D}]${N} 6/${TOTAL_PHASES} ${Y}SECURITY${N}"

LATEST_TASKS=$(ls -t specs/*/tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_TASKS" ]; then
    log "${R}✗ No tasks.md found${N}"
    exit 0
fi
echo "Using: $LATEST_TASKS" >> "$LOG_FILE"

output=$(claude -p --dangerously-skip-permissions "Read $LATEST_TASKS to understand the feature requirements. Then review all implemented code files applying OWASP Secure Coding Practices: input validation, output encoding, authentication and password management, session management, access control, cryptographic practices, error handling and logging, data protection, communication security, system configuration, database security, file management, memory management, and general secure coding practices. Fix any issues found. $CONTEXT7_NONE" 2>&1) || exit_code=$?
echo "$output" >> "$LOG_FILE"
if [ "$exit_code" -ne 0 ]; then
    echo "$output"
    exit $exit_code
fi

elapsed=$(($(date +%s) - START))
PHASE_TIMES[6]=$elapsed
log "${G}✓${N} SECURITY ${D}($(format_time $elapsed))${N}"
log ""

# TEST phase
PHASE="TEST"
START_TEST=$(date +%s)
log "${D}[${G}$(progress_bar 7 $TOTAL_PHASES)${D}]${N} 7/${TOTAL_PHASES} ${Y}TEST${N}"

LATEST_TASKS=$(ls -t specs/*/tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_TASKS" ]; then
    log "${R}✗ No tasks.md found${N}"
    exit 0
fi
echo "Using: $LATEST_TASKS" >> "$LOG_FILE"

iteration=0
while [ $iteration -lt $MAX_TEST_ITERATIONS ]; do
    iteration=$((iteration + 1))
    log "  ${C}↻${N} Retry $iteration/$MAX_TEST_ITERATIONS"

    RESULT=$(claude -p --dangerously-skip-permissions "Read $LATEST_TASKS to understand the feature requirements. Run all tests. Fix failures in implementation code (don't modify tests). Output ALL_TESTS_PASS when done or TESTS_FAILED if stuck. $CONTEXT7_FULL" 2>&1)
    echo "$RESULT" >> "$LOG_FILE"

    if echo "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        elapsed_test=$(($(date +%s) - START_TEST))
        PHASE_TIMES[7]=$elapsed_test
        elapsed=$(($(date +%s) - START_TOTAL))
        log "${G}✓${N} TEST ${D}($(format_time $elapsed_test))${N}"
        print_summary "success" $elapsed
        log "${D}Log: $LOG_FILE${N}"
        log ""
        exit 0
    fi
done

# Show output if tests failed
echo "$RESULT"

elapsed_test=$(($(date +%s) - START_TEST))
PHASE_TIMES[7]=$elapsed_test
elapsed=$(($(date +%s) - START_TOTAL))
print_summary "failed" $elapsed
log "${D}Log: $LOG_FILE${N}"
log ""
exit 1
