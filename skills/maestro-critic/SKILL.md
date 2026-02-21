---
name: maestro-critic
description: "Maestro Critic — Phase 2: cross-feature conflict resolution and full quality sweep using agent teams and subagents. Use after /maestro-artist to review and fix cross-feature issues."
argument-hint: "[max-retries]"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

If a number is provided, use it as `MAX_RETRIES`. Default is **3**.

You **MUST** consider any other user input before proceeding (if not empty).

---

## Orchestrator

You are the orchestrator. You coordinate the retry loop and delegate work to agent teams — never implement fixes directly. You use **agent teams** for parallel cross-feature work and **subagents** for focused research and isolated operations within a single session.

### 0. Read Project Context

1. **Read `CLAUDE.md`** for project standards, build/test commands, quality requirements, and any available MCP servers, plugins, or skills.
2. **Read `queue/masterplan.md`** and **`queue/*.md` feature files** (excluding `masterplan.md`) to understand what each feature is supposed to do.
3. **Research the codebase** — use the Task tool with `subagent_type: "Explore"` to launch up to 3 parallel subagents to scan the project structure:
   - One subagent maps the project layout: directories, entry points, config files, and tech stack
   - One subagent identifies cross-feature touchpoints: shared modules, common utilities, API routes, data models
   - One subagent reviews recent git history to understand what was built and in what order

   Synthesize findings into a brief context summary. This keeps heavy exploration output out of your main context and gives you a clear map before spawning the team. Pass relevant findings to teammates when you create them.

### 1. Retry Loop

Run the following steps in a loop, up to `MAX_RETRIES` attempts. Each attempt spawns a **fresh agent team** — fresh teammates = fresh context windows.

---

#### Step 1: Run Tests (Baseline)

Run the full test suite. If tests fail, fix the implementation yourself (never modify tests) and re-run until they pass. This gives the teammates a clean baseline.

#### Step 2: Create the Agent Team

Create an agent team named `reviewer` with 2 teammates:

- **conflict-checker**: Find and fix cross-feature conflicts across the codebase:
  - Duplicate routes or API endpoints
  - Naming collisions (functions, variables, CSS classes, IDs)
  - Import errors and circular dependencies
  - Conflicting global state or shared resource access
  - Inconsistent data models or schemas across features

  **Use subagents for scanning**: Before making fixes, use the Task tool with `subagent_type: "Explore"` to launch parallel subagents — one per major directory or module — to map all routes, exports, shared state, and data models across the codebase. This gives you a complete cross-feature map before you start fixing conflicts. Report all conflicts found and how they were resolved.

- **quality-sweep**: Run a sequential deep scan across the entire codebase covering:
  1. **Security** — OWASP Top 10: injection, auth gaps, sensitive data exposure, CSRF, cross-feature data leakage
  2. **Code quality** — bugs, dead code, unused imports, magic numbers, code smells, inconsistent error handling
  3. **Performance** — N+1 queries, unnecessary re-renders, missing indexes, unoptimized loops, large bundle imports

  **Use subagents for each category**: For each category above, use the Task tool with `subagent_type: "Explore"` to scan the codebase for issues in that category before fixing them. This keeps verbose scan output isolated and preserves your context for implementing fixes. Fix all issues found in each category before moving to the next. Report a summary per category.

Give both teammates the `CLAUDE.md` rules, the feature file context, and the codebase research from Step 0 so they understand what was intended and where things are.

#### Step 3: Wait and Synthesize

Wait for both teammates to finish. Synthesize their results into a single reviewer report.

#### Step 4: Clean Up the Team

Shut down both teammates and delete the `reviewer` team. This is required before a potential retry can create a new team.

#### Step 5: Validate

Run the full test suite one final time to ensure no fixes broke anything. Use the Task tool with `subagent_type: "general-purpose"` to run the test suite in a subagent — this isolates verbose test output from your main context. The subagent should return only the pass/fail result and any failure details.

- **If all tests pass** → proceed to Step 6 (Commit).
- **If tests fail** → log the failures. If retries remain, go back to Step 1 (the next iteration spawns a fresh team with fresh context). If no retries remain, proceed to Result.

#### Step 6: Commit

Stage and commit all changes:

```
maestro-critic: resolve cross-feature conflicts and quality issues

<Brief summary of what was fixed by each teammate.>
```

---

### 2. Result

- **If all tests pass**: output `ALL_TESTS_PASS`
- **If retries exhausted**: output `TESTS_FAILED` with a summary of remaining issues

### Notes

- **Agent teams** handle the heavy parallel work — conflict-checker and quality-sweep run as independent teammates with their own context windows
- **Subagents** handle focused research and isolation — `Explore` subagents scan the codebase, `general-purpose` subagents run tests, keeping verbose output out of the lead's and teammates' main contexts
- The conflict-checker is the highest-value teammate — cross-feature conflicts are invisible to per-feature testing
- The quality-sweep handles security, quality, and perf sequentially in one context window — no file conflicts, no overlap
- Each retry spawns a **fresh agent team** — teammates get clean context windows automatically, so they see the codebase as-is (including any fixes from previous attempts)
- You can message either teammate directly using Shift+Up/Down to redirect their approach
