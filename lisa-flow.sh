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

# === PHASE 5: TEST LOOP (Ralph Wiggum Style) ===
# Inspired by Geoffrey Huntley's Ralph Loop - self-healing until tests pass
# https://ghuntley.com/loop/

echo ""
echo "============================================"
echo "  RALPH TEST LOOP - Self-Healing Tests"
echo "============================================"

# Auto-detect test command
detect_test_command() {
    if [ -f "package.json" ]; then
        echo "npm test"
    elif [ -f "Cargo.toml" ]; then
        echo "cargo test"
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -d "tests" ]; then
        echo "pytest"
    elif [ -f "go.mod" ]; then
        echo "go test ./..."
    else
        echo ""
    fi
}

TEST_CMD=$(detect_test_command)

if [ -z "$TEST_CMD" ]; then
    echo "No test framework detected. Skipping test loop."
    echo ""
    echo "=== COMPLETE ==="
    echo "Lisa has finished implementing: $FEATURE"
    exit 0
fi

echo "Detected test command: $TEST_CMD"
echo "Max iterations: $MAX_TEST_ITERATIONS"
echo ""

iteration=0

while [ $iteration -lt $MAX_TEST_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo "--- Test iteration $iteration of $MAX_TEST_ITERATIONS ---"

    # Run tests and capture output
    set +e
    TEST_OUTPUT=$($TEST_CMD 2>&1)
    TEST_EXIT_CODE=$?
    set -e

    if [ $TEST_EXIT_CODE -eq 0 ]; then
        echo ""
        echo "=== ALL TESTS PASSED ==="
        echo "Lisa completed successfully after $iteration iteration(s)."
        echo "Feature implemented: $FEATURE"
        exit 0
    fi

    echo "Tests failed. Invoking Claude to fix..."
    echo ""

    # Claude fixes the code (fresh session each time)
    claude -p --dangerously-skip-permissions "The tests are failing. Here is the test output:

$TEST_OUTPUT

Analyze the failures and fix the implementation code to make all tests pass.
IMPORTANT:
- Do NOT modify the test files
- Only fix the implementation/source code
- Focus on the root cause of each failure
- After fixing, the tests should pass"

done

echo ""
echo "=== WARNING: Max iterations ($MAX_TEST_ITERATIONS) reached ==="
echo "Tests may still be failing. Review manually or increase max iterations."
echo "Feature: $FEATURE"
exit 1
