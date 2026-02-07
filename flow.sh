#!/bin/bash
# shellcheck shell=bash
# flow.sh - Worker: Structured Spec Kit workflow + Ralph-style self-healing test loop

set -euo pipefail

readonly SPEC_DIR_REL="../specs"  # Relative to script directory

FEATURE_INPUT="${1:-}"
MAX_TEST_ITERATIONS="${2:-3}"

if [ -z "$FEATURE_INPUT" ]; then
    echo "Error: FEATURE_INPUT is required" >&2
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
LAST_NUM=$(ls "$LOG_DIR"/lisa-flow_*.log 2>/dev/null | sed 's/.*lisa-flow_\([0-9]*\)\.log/\1/' | sort -n | tail -1)
NEXT_NUM=$(printf '%03d' "$(( ${LAST_NUM:-0} + 1 ))")
LOG_FILE="$LOG_DIR/lisa-flow_${NEXT_NUM}.log"

TOTAL_PHASES=5
declare -a PHASE_TIMES=()
declare -a PHASE_NAMES=("SPECIFY" "PLAN" "TASKS" "IMPLEMENT" "TEST")

CONTEXT7="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."

PHASE="INIT"
error_handler() { echo "Failed at: $PHASE (line $1)" | tee -a "$LOG_FILE"; }
trap 'error_handler $LINENO' ERR
trap 'echo "Interrupted"; exit 130' INT  # 128 + SIGINT(2)

log() { echo "$1" | tee -a "$LOG_FILE"; }

format_time() {
    local secs="${1:-0}"
    if [ "$secs" -ge 60 ]; then printf "%dm %ds" "$((secs / 60))" "$((secs % 60))"; else printf "%ds" "$secs"; fi
}

print_summary() {
    local status="$1" total_time="$2"
    log ""
    log "---------------------------------------------"
    log ""
    for i in "${!PHASE_NAMES[@]}"; do
        local idx=$((i + 1)) name="${PHASE_NAMES[$i]}"
        local time="" icon="" time_str=""
        if [[ -v "PHASE_TIMES[$idx]" ]]; then
            time="${PHASE_TIMES[$idx]}"
            icon="ok"
            time_str="$(format_time "$time")"
        else
            icon="--"
            time_str="-"
        fi
        log "  $icon $(printf '%-12s' "$name") $(printf '%10s' "$time_str")"
    done
    log ""
    log "---------------------------------------------"
    if [ "$status" = "success" ]; then log "SUCCESS  Total: $(format_time "$total_time")"
    else log "FAILED   Total: $(format_time "$total_time")"; fi
    log ""
}

run_phase() {
    local num="$1" name="$2"; shift 2
    local -a cmd=("$@")
    PHASE="$name"
    local start=$SECONDS exit_code=0
    log "[$num/$TOTAL_PHASES] $name"
    local output
    output=$("${cmd[@]}" 2>&1) || exit_code=$?
    printf '%s\n' "$output" >> "$LOG_FILE"
    if [ "$exit_code" -ne 0 ]; then printf '%s\n' "$output"; return "$exit_code"; fi
    local elapsed=$((SECONDS - start))
    PHASE_TIMES[$num]=$elapsed
    log "  ok $(format_time "$elapsed")"
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
PROMPT_PLAN="/speckit.plan Use subagents to research this feature in parallel: one for API and data layer research, one for architecture patterns and dependencies, one for testing strategy. Synthesize all findings into the plan. $CONTEXT7"
PROMPT_TASKS="/speckit.tasks"
PROMPT_IMPLEMENT="/speckit.implement Create an agent team to implement this feature. Break the work into independent tasks and spawn teammates, each owning a different set of files to avoid conflicts. Aim for 5-6 tasks per teammate. For frontend/UI components, use /frontend-design to ensure high design quality. Wait for all teammates to finish before proceeding. Clean up the team when done. $CONTEXT7"

# Main
SECONDS=0

run_phase 1 "SPECIFY" claude -p --dangerously-skip-permissions "$PROMPT_SPECIFY"
run_phase 2 "PLAN" claude -p --dangerously-skip-permissions "$PROMPT_PLAN"
run_phase 3 "TASKS" claude -p --dangerously-skip-permissions "$PROMPT_TASKS"

TASKS_FILE=$(find_tasks_file)
[ -z "$TASKS_FILE" ] && { log "Error: No tasks.md found after TASKS phase"; exit 1; }
printf '%s\n' "Using tasks file: $TASKS_FILE" >> "$LOG_FILE"

PROMPT_TEST="Read $TASKS_FILE. Use subagents to validate this feature in parallel:
1. Run all tests, fix failures in implementation only (don't modify tests)
2. Fix bugs, dead code, magic numbers, code smells
3. Check and fix OWASP vulnerabilities
4. Fix performance inefficiencies
Synthesize all results and output ALL_TESTS_PASS when all checks pass or TESTS_FAILED if stuck. $CONTEXT7"

run_phase 4 "IMPLEMENT" claude -p --dangerously-skip-permissions "$PROMPT_IMPLEMENT"

# TEST - Self-healing loop with code quality review
PHASE="TEST"
START_TEST=$SECONDS
log "[$TOTAL_PHASES/$TOTAL_PHASES] TEST"

iteration=0
RESULT=""
while [ "$iteration" -lt "$MAX_TEST_ITERATIONS" ]; do
    iteration=$((iteration + 1))
    log "  Attempt $iteration/$MAX_TEST_ITERATIONS"
    RESULT=$(claude -p --dangerously-skip-permissions "$PROMPT_TEST" 2>&1)
    printf '%s\n' "$RESULT" >> "$LOG_FILE"
    if printf '%s' "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        elapsed_test=$((SECONDS - START_TEST))
        PHASE_TIMES[$TOTAL_PHASES]=$elapsed_test
        elapsed=$SECONDS
        log "  ok $(format_time "$elapsed_test")"
        print_summary "success" "$elapsed"
        log "Log: $LOG_FILE"
        log ""
        exit 0
    fi
done

printf '%s\n' "$RESULT"
elapsed_test=$((SECONDS - START_TEST))
PHASE_TIMES[$TOTAL_PHASES]=$elapsed_test
elapsed=$SECONDS
print_summary "failed" "$elapsed"
log "Log: $LOG_FILE"
log ""
exit 1
