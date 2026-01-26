#!/bin/bash

# lisa-flow.sh
# Sequential Spec Kit workflow with fresh Claude sessions
# Named after Lisa Simpson - methodical, planned, structured
# Inspired by Ralph Loop (https://ghuntley.com/loop/)

set -e  # Exit on any error

FEATURE="$1"

if [ -z "$FEATURE" ]; then
    echo "Usage: ./lisa-flow.sh \"your feature description\""
    echo ""
    echo "Example:"
    echo "  ./lisa-flow.sh \"Build user authentication with OAuth support\""
    exit 1
fi

echo "=== SPECIFY ==="
claude -p --dangerously-skip-permissions "/speckit.specify $FEATURE"

echo "=== PLAN ==="
claude -p --dangerously-skip-permissions "/speckit.plan"

echo "=== TASKS ==="
claude -p --dangerously-skip-permissions "/speckit.tasks"

echo "=== IMPLEMENT ==="
claude -p --dangerously-skip-permissions "/speckit.implement"

echo "=== COMPLETE ==="
echo "Lisa has finished implementing: $FEATURE"
