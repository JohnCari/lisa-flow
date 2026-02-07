#!/bin/bash
# shellcheck shell=bash
# lisa.sh - Queue-based feature orchestrator for Lisa Flow
# Reads .md files from harness/, runs flow.sh for each, then integration test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly HARNESS_DIR="$SCRIPT_DIR/harness"
readonly MASTER_PLAN="$SCRIPT_DIR/harness/masterplan.md"

MAX_RETRIES="${1:-5}"

CONTEXT7="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."

if [ ! -d "$HARNESS_DIR" ]; then
    echo "Error: No harness/ directory found in lisa-flow/"
    echo ""
    echo "Create it with numbered .md files:"
    echo "  mkdir lisa-flow/harness"
    echo "  echo \"Build auth API\" > lisa-flow/harness/001-step.md"
    echo ""
    echo "Usage: lisa-flow/lisa.sh [retries]"
    exit 1
fi

[[ "$MAX_RETRIES" =~ ^[1-9][0-9]*$ ]] || { echo "Error: retries must be a positive integer"; exit 1; }

LISA_FLOW="$SCRIPT_DIR/flow.sh"
LOG_DIR="$SCRIPT_DIR/logs"
rm -f "$LOG_DIR/.gitkeep"
NEXT_NUM=$(printf '%03d' "$(( $(ls "$LOG_DIR"/orchestrator_*.log 2>/dev/null | wc -l) + 1 ))")
LOG_FILE="$LOG_DIR/orchestrator_${NEXT_NUM}.log"

log() { echo "$1" | tee -a "$LOG_FILE"; }

format_time() {
    local secs="${1:-0}"
    if [ "$secs" -ge 3600 ]; then
        printf "%dh %dm %ds" "$((secs / 3600))" "$((secs % 3600 / 60))" "$((secs % 60))"
    elif [ "$secs" -ge 60 ]; then
        printf "%dm %ds" "$((secs / 60))" "$((secs % 60))"
    else
        printf "%ds" "$secs"
    fi
}

trap 'echo "Interrupted"; exit 130' INT

# Collect features (exclude masterplan.md)
shopt -s nullglob
all_md=("$HARNESS_DIR"/*.md)
shopt -u nullglob

features=()
for f in "${all_md[@]}"; do
    [[ "$(basename "$f")" == "masterplan.md" ]] && continue
    features+=("$f")
done

if [ ${#features[@]} -eq 0 ]; then
    echo "Error: No feature .md files in lisa-flow/harness/"
    exit 1
fi

# Load master plan if it exists
MASTER_PLAN_CONTENT=""
if [ -f "$MASTER_PLAN" ]; then
    MASTER_PLAN_CONTENT=$(cat "$MASTER_PLAN")
fi

TOTAL=$((${#features[@]} + 1))  # +1 for integration pass
declare -a FEATURE_NAMES=()
declare -a FEATURE_RESULTS=()
declare -a FEATURE_TIMES=()

# Main
SECONDS=0

log "Features: ${#features[@]}"
log "Retries:  $MAX_RETRIES"
log "Log:      $LOG_FILE"
log ""

# Process each feature
current=0
pass_count=0
fail_count=0

for feature_file in "${features[@]}"; do
    current=$((current + 1))
    name=$(basename "$feature_file" .md)
    FEATURE_NAMES+=("$name")

    log "[$current/$TOTAL] $name"

    start=$SECONDS
    exit_code=0

    # Build combined input: master plan + feature
    if [ -n "$MASTER_PLAN_CONTENT" ]; then
        combined_file=$(mktemp)
        printf '%s\n\n---\n\n%s\n' "$MASTER_PLAN_CONTENT" "$(cat "$feature_file")" > "$combined_file"
        flow_input="@$combined_file"
    else
        flow_input="@$feature_file"
    fi

    # First attempt
    "$LISA_FLOW" "$flow_input" "$MAX_RETRIES" >> "$LOG_FILE" 2>&1 || exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        log "  Retrying $name"
        exit_code=0
        "$LISA_FLOW" "$flow_input" "$MAX_RETRIES" >> "$LOG_FILE" 2>&1 || exit_code=$?
    fi

    # Clean up temp file
    [ -n "${combined_file:-}" ] && rm -f "$combined_file"
    combined_file=""

    elapsed=$((SECONDS - start))
    FEATURE_TIMES+=("$elapsed")

    if [ "$exit_code" -eq 0 ]; then
        FEATURE_RESULTS+=("PASS")
        pass_count=$((pass_count + 1))
        log "  PASS ($( format_time "$elapsed" ))"
    else
        FEATURE_RESULTS+=("FAIL")
        fail_count=$((fail_count + 1))
        log "  FAIL ($( format_time "$elapsed" ))"
    fi
    log ""
done

# Final integration pass
log "[$TOTAL/$TOTAL] INTEGRATION"

INTEGRATION_PROMPT="You are running a final integration check across the entire project.
Multiple features were just built independently. Your job:
1. Run ALL tests across the entire project - fix failures in implementation (don't modify tests)
2. Check for cross-feature conflicts (duplicate routes, naming collisions, import errors)
3. Code quality - fix bugs, dead code, magic numbers, code smells
4. Security - check and fix OWASP vulnerabilities
5. Performance - fix inefficiencies
Output ALL_TESTS_PASS when everything works together or TESTS_FAILED if stuck. $CONTEXT7"

integration_start=$SECONDS
integration_result="FAIL"
iteration=0

while [ "$iteration" -lt "$MAX_RETRIES" ]; do
    iteration=$((iteration + 1))
    log "  Attempt $iteration/$MAX_RETRIES"
    RESULT=$(claude -p --dangerously-skip-permissions "$INTEGRATION_PROMPT" 2>&1)
    printf '%s\n' "$RESULT" >> "$LOG_FILE"
    if printf '%s' "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        integration_result="PASS"
        break
    fi
done

integration_elapsed=$((SECONDS - integration_start))
log "  $integration_result ($(format_time "$integration_elapsed"))"

# Summary
total_time=$SECONDS
log ""
log "---------------------------------------------"
log ""

for i in "${!FEATURE_NAMES[@]}"; do
    name="${FEATURE_NAMES[$i]}"
    result="${FEATURE_RESULTS[$i]}"
    time="${FEATURE_TIMES[$i]}"
    log "  $(printf '%-24s' "$name") $(printf '%6s' "$result") $(printf '%12s' "$(format_time "$time")")"
done

log "  $(printf '%-24s' "INTEGRATION") $(printf '%6s' "$integration_result") $(printf '%12s' "$(format_time "$integration_elapsed")")"

log ""
log "---------------------------------------------"

if [ "$fail_count" -eq 0 ] && [ "$integration_result" = "PASS" ]; then
    log "SUCCESS  ${pass_count}/${#features[@]} features  Total: $(format_time "$total_time")"
    log "Log: $LOG_FILE"
    log ""
    exit 0
else
    log "FAILED   ${pass_count}/${#features[@]} features  Total: $(format_time "$total_time")"
    log "Log: $LOG_FILE"
    log ""
    exit 1
fi
