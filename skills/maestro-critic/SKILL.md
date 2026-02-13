---
name: maestro-critic
description: "Maestro Critic — cross-feature conflict resolution + full quality sweep using an agent team (Phase 2)"
user-invocable: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

Run the reviewer: a comprehensive pass across the entire project using 3 agents — the lead runs tests, then spawns 2 teammates working in parallel. This is designed to run in an interactive Claude Code session after all features have been implemented by Maestro.

### Steps

1. **Read `CLAUDE.md`** for project standards, build/test commands, quality requirements, and any available MCP servers, plugins, or skills. Then **run all tests.** Before spawning the team, run the full test suite. If tests fail, fix the implementation (never modify tests) and re-run until they pass. This gives the teammates a clean baseline.

2. **Create an agent team** named `reviewer` with 2 teammates:

   - **conflict-checker**: Find and fix cross-feature conflicts across the codebase:
     - Duplicate routes or API endpoints
     - Naming collisions (functions, variables, CSS classes, IDs)
     - Import errors and circular dependencies
     - Conflicting global state or shared resource access
     - Inconsistent data models or schemas across features
     - Report all conflicts found and how they were resolved.

   - **quality-sweep**: Run a sequential deep scan across the entire codebase covering:
     1. **Security** — OWASP Top 10: injection, auth gaps, sensitive data exposure, CSRF, cross-feature data leakage
     2. **Code quality** — bugs, dead code, unused imports, magic numbers, code smells, inconsistent error handling
     3. **Performance** — N+1 queries, unnecessary re-renders, missing indexes, unoptimized loops, large bundle imports
     - Fix all issues found in each category before moving to the next. Report a summary per category.

3. **Wait for both teammates to finish.** Synthesize their results into a single reviewer report.

4. **Validate**: Run the full test suite one final time to ensure no fixes broke anything.

5. **Result**:
   - If all tests pass and all checks are resolved: output `<promise>ALL_TESTS_PASS</promise>`
   - If issues remain: output `TESTS_FAILED` with a summary of remaining issues

6. **Clean up the team** when done.

### Fresh-Context Retries

Run the critic inside a Ralph Loop for automatic fresh-context retries:

```bash
claude --dangerously-skip-permissions
/ralph-loop "/maestro-critic" --completion-promise "ALL_TESTS_PASS"
```

Each iteration gets a fresh context window. If validation fails, exit with `TESTS_FAILED` — the Ralph Loop will restart with clean context, re-read the codebase (including any fixes from the previous iteration), and try again.

### Notes

- The conflict-checker is the highest-value teammate — cross-feature conflicts are invisible to per-feature testing
- The quality-sweep handles security, quality, and perf sequentially in one context window — no file conflicts, no overlap
- You can message either teammate directly using Shift+Up/Down to redirect their approach
