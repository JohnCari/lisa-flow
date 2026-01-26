#!/bin/bash

# lisa-flow.sh
# Structured Spec Kit workflow + Ralph-style self-healing test loop
# Lisa Flow by JohnCari
# Test loop inspired by Ralph Wiggum Loop (Geoffrey Huntley) - https://ghuntley.com/loop/

set -e

FEATURE="$1"
MAX_TEST_ITERATIONS="${2:-5}"

if [ -z "$FEATURE" ]; then
    echo "Usage: ./lisa-flow.sh \"your feature description\" [max_test_iterations]"
    echo ""
    echo "Example:"
    echo "  ./lisa-flow.sh \"Build user authentication with OAuth\" 10"
    exit 1
fi

echo "============================================"
echo "  LISA FLOW - Structured AI Development"
echo "============================================"

# === PHASE 1: SPECIFY ===
echo ""
echo "=== SPECIFY ==="
claude -p --dangerously-skip-permissions "/speckit.specify $FEATURE"

# === PHASE 2: PLAN ===
echo ""
echo "=== PLAN ==="
claude -p --dangerously-skip-permissions "/speckit.plan"

# === PHASE 3: TASKS ===
echo ""
echo "=== TASKS ==="
claude -p --dangerously-skip-permissions "/speckit.tasks"

# === PHASE 4: IMPLEMENT ===
echo ""
echo "=== IMPLEMENT ==="
claude -p --dangerously-skip-permissions "/speckit.implement"

# === PHASE 5: TEST & VERIFY (Ralph Style) ===
# Reads tasks.md to know what to test
# Inspired by Geoffrey Huntley's Ralph Loop - self-healing until tests pass

echo ""
echo "============================================"
echo "  RALPH TEST LOOP - Self-Healing Tests"
echo "============================================"
echo "Max iterations: $MAX_TEST_ITERATIONS"
echo ""

iteration=0

while [ $iteration -lt $MAX_TEST_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo "--- Test iteration $iteration of $MAX_TEST_ITERATIONS ---"

    # Claude reads tasks.md, runs tests, fixes if needed
    RESULT=$(claude -p --dangerously-skip-permissions "Read the tasks.md file in the specs directory.
Run all tests defined in the tasks to verify the implementation.
If any tests fail:
1. Analyze the failure
2. Fix the implementation code (do NOT modify tests)
3. Re-run the tests

When ALL tests pass, output exactly: ALL_TESTS_PASS
If you cannot fix after trying, output exactly: TESTS_FAILED")

    if echo "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        echo ""
        echo "=== ALL TESTS PASSED ==="
        echo "Lisa completed successfully after $iteration iteration(s)."
        echo "Feature implemented: $FEATURE"
        exit 0
    fi

    echo "Tests not passing yet, continuing..."
    echo ""
done

echo ""
echo "=== WARNING: Max iterations ($MAX_TEST_ITERATIONS) reached ==="
echo "Tests may still be failing. Review manually or increase max iterations."
echo "Feature: $FEATURE"
exit 1
