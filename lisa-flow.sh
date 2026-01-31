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

# Colors
G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' D='\033[2m' N='\033[0m'
M='\033[0;35m'  # Magenta for SECURITY phase

# Terminal width check
MIN_WIDTH=75  # Banner is 68 chars + some padding
check_terminal_width() {
    local cols=$(tput cols 2>/dev/null || echo 80)
    if [ "$cols" -lt "$MIN_WIDTH" ]; then
        echo -e "${Y}⚠ Terminal width ($cols) is below recommended ($MIN_WIDTH)${N}"
        echo -e "${D}  Resize your terminal for best display${N}"
        echo ""
    fi
}

# Phase tracking
declare -a PHASE_TIMES=()
declare -a PHASE_NAMES=("SPECIFY" "PLAN" "TASKS" "DESIGN" "IMPLEMENT" "SECURITY" "TEST")

# Context7 instructions for headless prompts
CONTEXT7="Use Context7 MCP to fetch up-to-date docs. Workflow: 1) mcp__plugin_context7_context7__resolve-library-id with library name to get ID. 2) mcp__plugin_context7_context7__query-docs with ID and query."

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
    local width=20
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "${G}%s${N}" "$bar"
}

print_summary() {
    local status=$1 total_time=$2
    log ""
    log "${D}╔══════════════════════════════════════════════════════════════════════╗${N}"
    log "${D}║${N}  ${W}SUMMARY${N}                                                            ${D}║${N}"
    log "${D}╠══════════════════════════════════════════════════════════════════════╣${N}"

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
        log "${D}║${N}  $icon $(printf '%-12s' "$name") $(printf '%50s' "$time_str") ${D}║${N}"
    done

    log "${D}╠══════════════════════════════════════════════════════════════════════╣${N}"
    if [ "$status" = "success" ]; then
        log "${D}║${N}  ${G}SUCCESS${N}                                          Total: $(printf '%8s' "$(format_time $total_time)") ${D}║${N}"
    else
        log "${D}║${N}  ${R}FAILED${N}                                           Total: $(printf '%8s' "$(format_time $total_time)") ${D}║${N}"
    fi
    log "${D}╚══════════════════════════════════════════════════════════════════════╝${N}"
}

show_banner() {
    echo ""
    echo -e "${C}██╗     ██╗███████╗ █████╗       ███████╗██╗      ██████╗ ██╗    ██╗${N}"
    echo -e "${C}██║     ██║██╔════╝██╔══██╗      ██╔════╝██║     ██╔═══██╗██║    ██║${N}"
    echo -e "${C}██║     ██║███████╗███████║█████╗█████╗  ██║     ██║   ██║██║ █╗ ██║${N}"
    echo -e "${C}██║     ██║╚════██║██╔══██║╚════╝██╔══╝  ██║     ██║   ██║██║███╗██║${N}"
    echo -e "${C}███████╗██║███████║██║  ██║      ██║     ███████╗╚██████╔╝╚███╔███╔╝${N}"
    echo -e "${C}╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝${N}"
    echo ""
}

if [ -z "$FEATURE" ]; then
    show_banner
    echo -e "${D}╔══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${N}  Usage: ./lisa-flow.sh ${C}<feature>${N} ${D}[test_retries]${N}"
    echo -e "${D}║${N}"
    echo -e "${D}║${N}  ${W}<feature>${N}       Feature description to implement"
    echo -e "${D}║${N}  ${D}[test_retries]${N}  Max test fix attempts ${D}(default: 5)${N}"
    echo -e "${D}╚══════════════════════════════════════════════════════════════════════╝${N}"
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
max_log_len=45
if [ ${#LOG_FILE} -gt $max_log_len ]; then
    display_log="...${LOG_FILE: -$max_log_len}"
fi

log "${D}╔══════════════════════════════════════════════════════════════════════╗${N}"
log "${D}║${N}  Feature:        ${W}$display_feature${N}"
log "${D}║${N}  Test Retries:   ${W}$MAX_TEST_ITERATIONS${N}"
log "${D}║${N}  Log:            ${D}$display_log${N}"
log "${D}╚══════════════════════════════════════════════════════════════════════╝${N}"
log ""

run_phase() {
    local num=$1 name=$2 cmd=$3
    PHASE="$name"
    local start=$(date +%s)
    local exit_code=0

    log "${D}[${N}$(progress_bar $num 7)${D}]${N} ${W}$name${N} ${D}...${N}"

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

run_phase 1 "SPECIFY" "claude -p --dangerously-skip-permissions \"/speckit.specify $FEATURE. Include comprehensive tests following Test Driven Development. $CONTEXT7\""
run_phase 2 "PLAN" "claude -p --dangerously-skip-permissions \"/speckit.plan $CONTEXT7\""
run_phase 3 "TASKS" "claude -p --dangerously-skip-permissions \"/speckit.tasks $CONTEXT7\""

# DESIGN phase
PHASE="DESIGN"
START=$(date +%s)
exit_code=0
log "${D}[${N}$(progress_bar 4 7)${D}]${N} ${W}DESIGN${N} ${D}...${N}"

LATEST_TASKS=$(ls -t specs/*/tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_TASKS" ]; then
    log "${R}✗ No tasks.md found${N}"
    exit 0
fi
echo "Using: $LATEST_TASKS" >> "$LOG_FILE"

output=$(claude -p --dangerously-skip-permissions "/frontend-design:frontend-design Read $LATEST_TASKS and create the frontend design. $CONTEXT7" 2>&1) || exit_code=$?
echo "$output" >> "$LOG_FILE"
if [ "$exit_code" -ne 0 ]; then
    echo "$output"
    exit $exit_code
fi

elapsed=$(($(date +%s) - START))
PHASE_TIMES[4]=$elapsed
log "${G}✓${N} DESIGN ${D}($(format_time $elapsed))${N}"
log ""

run_phase 5 "IMPLEMENT" "claude -p --dangerously-skip-permissions \"/speckit.implement $CONTEXT7\""

# SECURITY phase
PHASE="SECURITY"
START=$(date +%s)
exit_code=0
log "${D}[${N}$(progress_bar 6 7)${D}]${N} ${M}SECURITY${N} ${D}...${N}"

LATEST_TASKS=$(ls -t specs/*/tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_TASKS" ]; then
    log "${R}✗ No tasks.md found${N}"
    exit 0
fi
echo "Using: $LATEST_TASKS" >> "$LOG_FILE"

output=$(claude -p --dangerously-skip-permissions "Read $LATEST_TASKS. Review all implemented code for security vulnerabilities. Check for OWASP Top 10 issues: injection, XSS, broken auth, sensitive data exposure, XXE, broken access control, security misconfigs, insecure deserialization, vulnerable components, insufficient logging. Fix any issues found. $CONTEXT7" 2>&1) || exit_code=$?
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
log "${D}[${N}$(progress_bar 7 7)${D}]${N} ${W}TEST${N} ${D}...${N}"

LATEST_TASKS=$(ls -t specs/*/tasks.md 2>/dev/null | head -1)
if [ -z "$LATEST_TASKS" ]; then
    log "${R}✗ No tasks.md found${N}"
    exit 0
fi
echo "Using: $LATEST_TASKS" >> "$LOG_FILE"

iteration=0
while [ $iteration -lt $MAX_TEST_ITERATIONS ]; do
    iteration=$((iteration + 1))
    log "${C}↻ Test Retry $iteration/$MAX_TEST_ITERATIONS${N}"

    RESULT=$(claude -p --dangerously-skip-permissions "Read $LATEST_TASKS. Run all tests. Fix failures (don't modify tests). Output ALL_TESTS_PASS when done or TESTS_FAILED if stuck. $CONTEXT7" 2>&1)
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

    # Show output if tests failed on last iteration
    if [ $iteration -eq $MAX_TEST_ITERATIONS ]; then
        echo "$RESULT"
    fi
    log ""
done

elapsed_test=$(($(date +%s) - START_TEST))
PHASE_TIMES[7]=$elapsed_test
elapsed=$(($(date +%s) - START_TOTAL))
print_summary "failed" $elapsed
log "${D}Log: $LOG_FILE${N}"
log ""
exit 1
