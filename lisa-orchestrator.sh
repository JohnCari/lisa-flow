#!/bin/bash
# shellcheck shell=bash
# lisa-orchestrator.sh - Queue-based feature orchestrator for Lisa Flow
# Reads .md files from harness/, runs lisa-flow.sh for each, then integration test

set -euo pipefail

readonly HARNESS_DIR="harness"
readonly MASTER_PLAN="harness/masterplan.md"
readonly MAX_FEATURE_LEN=50
readonly MAX_LOG_LEN=40
readonly PROGRESS_BAR_WIDTH=30

MAX_RETRIES="${1:-5}"

# Colors
GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' CYAN='\033[0;36m' WHITE='\033[1;37m' DIM='\033[2m' RESET='\033[0m'
ORANGE='\033[38;5;202m'

CONTEXT7="When using any library or framework, use Context7 MCP to get accurate docs: 1) mcp__context7__resolve-library-id with library name. 2) mcp__context7__query-docs with the ID and your specific question."

show_banner() {
    echo ""
    echo -e "${YELLOW}██${ORANGE}╗     ${YELLOW}██${ORANGE}╗${YELLOW}███████${ORANGE}╗ ${YELLOW}█████${ORANGE}╗       ${YELLOW}███████${ORANGE}╗${YELLOW}██${ORANGE}╗      ${YELLOW}██████${ORANGE}╗ ${YELLOW}██${ORANGE}╗    ${YELLOW}██${ORANGE}╗${RESET}"
    echo -e "${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}╔════╝${YELLOW}██${ORANGE}╔══${YELLOW}██${ORANGE}╗      ${YELLOW}██${ORANGE}╔════╝${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}╔═══${YELLOW}██${ORANGE}╗${YELLOW}██${ORANGE}║    ${YELLOW}██${ORANGE}║${RESET}"
    echo -e "${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║${YELLOW}███████${ORANGE}╗${YELLOW}███████${ORANGE}║${WHITE}█████${ORANGE}╗${YELLOW}█████${ORANGE}╗  ${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║   ${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}║ ${YELLOW}█${ORANGE}╗ ${YELLOW}██${ORANGE}║${RESET}"
    echo -e "${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║╚════${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}╔══${YELLOW}██${ORANGE}║╚════╝${YELLOW}██${ORANGE}╔══╝  ${YELLOW}██${ORANGE}║     ${YELLOW}██${ORANGE}║   ${YELLOW}██${ORANGE}║${YELLOW}██${ORANGE}║${YELLOW}███${ORANGE}╗${YELLOW}██${ORANGE}║${RESET}"
    echo -e "${YELLOW}███████${ORANGE}╗${YELLOW}██${ORANGE}║${YELLOW}███████${ORANGE}║${YELLOW}██${ORANGE}║  ${YELLOW}██${ORANGE}║      ${YELLOW}██${ORANGE}║     ${YELLOW}███████${ORANGE}╗╚${YELLOW}██████${ORANGE}╔╝╚${YELLOW}███${ORANGE}╔${YELLOW}███${ORANGE}╔╝${RESET}"
    echo -e "${ORANGE}╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝${RESET}"
    echo -e "                         ${DIM}ORCHESTRATOR${RESET}"
    echo ""
}

if [ ! -d "$HARNESS_DIR" ]; then
    show_banner
    echo -e "  ${RED}✗${RESET} No ${WHITE}${HARNESS_DIR}/${RESET} directory found"
    echo ""
    echo -e "  Create it with numbered .md files:"
    echo -e "    ${DIM}mkdir harness${RESET}"
    echo -e "    ${DIM}echo \"Build auth API\" > harness/001-auth.md${RESET}"
    echo -e "    ${DIM}echo \"Build dashboard\" > harness/002-dashboard.md${RESET}"
    echo ""
    echo -e "  Usage: lisa-flow/lisa-orchestrator.sh ${DIM}[retries]${RESET}"
    echo ""
    exit 1
fi

[[ "$MAX_RETRIES" =~ ^[1-9][0-9]*$ ]] || { echo "Error: retries must be a positive integer"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_FLOW="$SCRIPT_DIR/lisa-flow.sh"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/orchestrator_$(date +%Y-%m-%d_%H-%M-%S).log"

TZ="${TZ:-America/New_York}"
export TZ

log() { echo -e "$1" | tee -a "$LOG_FILE"; }

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

progress_bar() {
    local current="$1" total="$2"
    local filled=$((current * PROGRESS_BAR_WIDTH / total))
    local empty=$((PROGRESS_BAR_WIDTH - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "%s" "$bar"
}

trap 'echo -e "\n${YELLOW}Interrupted${RESET}\n"; exit 130' INT

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
    show_banner
    echo -e "  ${RED}✗${RESET} No feature .md files in ${WHITE}${HARNESS_DIR}/${RESET}"
    echo ""
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

show_banner

display_log="$LOG_FILE"
[ "${#LOG_FILE}" -gt "$MAX_LOG_LEN" ] && display_log="...${LOG_FILE: -$MAX_LOG_LEN}"

log "  Features       ${WHITE}${#features[@]}${RESET}"
log "  Test Retries   ${WHITE}$MAX_RETRIES${RESET}"
log "  Log            ${DIM}$display_log${RESET}"
log ""

# Process each feature
current=0
pass_count=0
fail_count=0

for feature_file in "${features[@]}"; do
    current=$((current + 1))
    name=$(basename "$feature_file" .md)
    FEATURE_NAMES+=("$name")

    display_name="$name"
    [ "${#name}" -gt "$MAX_FEATURE_LEN" ] && display_name="${name:0:$MAX_FEATURE_LEN}..."

    log "${DIM}[${GREEN}$(progress_bar "$current" "$TOTAL")${DIM}]${RESET} ${current}/${TOTAL} ${YELLOW}$display_name${RESET}"

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
        log "  ${CYAN}↻${RESET} Retrying $display_name"
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
        log "${GREEN}✓${RESET} $display_name ${DIM}($(format_time "$elapsed"))${RESET}"
    else
        FEATURE_RESULTS+=("FAIL")
        fail_count=$((fail_count + 1))
        log "${RED}✗${RESET} $display_name ${DIM}($(format_time "$elapsed"))${RESET}"
    fi
    log ""
done

# Final integration pass
log "${DIM}[${GREEN}$(progress_bar "$TOTAL" "$TOTAL")${DIM}]${RESET} ${TOTAL}/${TOTAL} ${YELLOW}INTEGRATION${RESET}"

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
    log "  ${CYAN}↻${RESET} Attempt $iteration/$MAX_RETRIES"
    RESULT=$(claude -p --dangerously-skip-permissions "$INTEGRATION_PROMPT" 2>&1)
    printf '%s\n' "$RESULT" >> "$LOG_FILE"
    if printf '%s' "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        integration_result="PASS"
        break
    fi
done

integration_elapsed=$((SECONDS - integration_start))

if [ "$integration_result" = "PASS" ]; then
    log "${GREEN}✓${RESET} INTEGRATION ${DIM}($(format_time "$integration_elapsed"))${RESET}"
else
    log "${RED}✗${RESET} INTEGRATION ${DIM}($(format_time "$integration_elapsed"))${RESET}"
fi

# Summary
total_time=$SECONDS
log ""
log "${DIM}─────────────────────────────────────────────${RESET}"
log ""

for i in "${!FEATURE_NAMES[@]}"; do
    name="${FEATURE_NAMES[$i]}"
    result="${FEATURE_RESULTS[$i]}"
    time="${FEATURE_TIMES[$i]}"
    display_name="$name"
    [ "${#name}" -gt 20 ] && display_name="${name:0:20}..."

    if [ "$result" = "PASS" ]; then
        icon="${GREEN}✓${RESET}"
    else
        icon="${RED}✗${RESET}"
    fi
    log "  $icon $(printf '%-24s' "$display_name") $(printf '%6s' "$result") $(printf '%12s' "$(format_time "$time")")"
done

# Integration row
if [ "$integration_result" = "PASS" ]; then
    icon="${GREEN}✓${RESET}"
else
    icon="${RED}✗${RESET}"
fi
log "  $icon $(printf '%-24s' "INTEGRATION") $(printf '%6s' "$integration_result") $(printf '%12s' "$(format_time "$integration_elapsed")")"

log ""
log "${DIM}─────────────────────────────────────────────${RESET}"

if [ "$fail_count" -eq 0 ] && [ "$integration_result" = "PASS" ]; then
    log "  ${GREEN}SUCCESS${RESET}  ${pass_count}/${#features[@]} features  Total: $(format_time "$total_time")"
    log ""
    log "${DIM}Log: $LOG_FILE${RESET}"
    log ""
    exit 0
else
    log "  ${RED}FAILED${RESET}   ${pass_count}/${#features[@]} features  Total: $(format_time "$total_time")"
    log ""
    log "${DIM}Log: $LOG_FILE${RESET}"
    log ""
    exit 1
fi
