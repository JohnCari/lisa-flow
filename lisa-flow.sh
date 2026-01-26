#!/bin/bash

# lisa-flow.sh
# Structured Spec Kit workflow + Ralph-style self-healing test loop
# Lisa Flow by JohnCari
# Test loop inspired by Ralph Wiggum Loop (Geoffrey Huntley) - https://ghuntley.com/loop/

set -e

FEATURE="$1"
MAX_TEST_ITERATIONS="${2:-5}"

if [ -z "$FEATURE" ]; then
    echo "Usage: ./lisa-flow.sh \"feature description\" [max_iterations]"
    echo ""
    echo "Example: ./lisa-flow.sh \"Build user auth API\" 10"
    exit 1
fi

echo "============================================"
echo "  LISA FLOW - Structured AI Development"
echo "============================================"

echo ""
echo "=== SPECIFY ==="
claude -p --dangerously-skip-permissions "/speckit.specify $FEATURE. Include comprehensive tests following TDD."

echo ""
echo "=== PLAN ==="
claude -p --dangerously-skip-permissions "/speckit.plan"

echo ""
echo "=== TASKS ==="
claude -p --dangerously-skip-permissions "/speckit.tasks"

echo ""
echo "=== IMPLEMENT ==="
claude -p --dangerously-skip-permissions "/speckit.implement"

echo ""
echo "=== TEST (Ralph Style) ==="

LATEST_TASKS=$(find specs .specify/specs -name "tasks.md" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)

if [ -z "$LATEST_TASKS" ]; then
    echo "No tasks.md found."
    exit 0
fi

echo "Using: $LATEST_TASKS"

iteration=0
while [ $iteration -lt $MAX_TEST_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo "--- Iteration $iteration/$MAX_TEST_ITERATIONS ---"

    RESULT=$(claude -p --dangerously-skip-permissions "Read $LATEST_TASKS. Run all tests. Fix failures (don't modify tests). Output ALL_TESTS_PASS when done or TESTS_FAILED if stuck.")

    if echo "$RESULT" | grep -q "ALL_TESTS_PASS"; then
        echo "=== TESTS PASSED ==="
        exit 0
    fi
done

echo "=== MAX ITERATIONS REACHED ==="
exit 1
