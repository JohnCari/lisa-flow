---
name: maestro-virtuoso
description: "Maestro Virtuoso — Phase 3: perpetual improvement engine using agent teams and subagents. Use after /maestro-critic to continuously improve code quality, coverage, and architecture."
argument-hint: "[optional instructions]"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

Interpret the user input as natural language instructions. Examples: "focus on security", "max 5 iterations", "skip test coverage, prioritize performance". If empty, use defaults. Default `MAX_ITERATIONS` is **10** unless the user specifies otherwise.

---

## Orchestrator

You are the orchestrator — a lightweight loop controller. You coordinate iterations and delegate heavy work to **agent teams** and **subagents**. Agent teams handle parallel multi-session coordination (assessment, implementation). Subagents handle focused research and isolated operations within a single session (codebase exploration, test running). Each team you spawn gets fresh context windows automatically. `IMPROVEMENT_PLAN.md` is your shared state between iterations.

**Loop structure:** Repeat iterations until all improvements are complete or `MAX_ITERATIONS` is reached. Each iteration: ORIENT → ASSESS → SELECT → IMPLEMENT → VALIDATE → COMMIT → UPDATE PLAN → check if done.

---

### Iteration Loop

For each iteration (1 to `MAX_ITERATIONS`):

---

#### Phase 1: ORIENT

Study the project before doing anything. Read governance files yourself, then delegate heavy codebase exploration to subagents.

1. **Read `CLAUDE.md` FIRST** — project governing document. Rules defined here are non-negotiable hard constraints. Use whatever tools are documented there throughout all phases.

2. **Read `AGENTS.md`** (if it exists) — additional operational guidance, agent-specific instructions, or codebase patterns.

3. **Read `IMPROVEMENT_PLAN.md`** (if it exists) — shared state from previous iterations. If it exists and has uncompleted tasks, you are resuming. If not, this is the first iteration.

4. **Run `git log --oneline -50`** to discover what features have been built, what's been committed, and the project's trajectory.

5. **Read `queue/masterplan.md`** (if it exists) — the original project vision and current documented state.

6. **Read `queue/*.md` feature files** (excluding `masterplan.md`) — the original feature specs and any `## Implementation Updates` sections from previous iterations.

7. **Study the codebase with subagents** — use the Task tool with `subagent_type: "Explore"` to launch up to 3 parallel subagents:
   - One subagent scans `src/` for code patterns, architecture, and module structure
   - One subagent scans `tests/` for test patterns, coverage shape, and test utilities
   - One subagent scans config files, build setup, and dependency structure

   Synthesize their findings into a brief orientation summary. This keeps heavy exploration output out of your main context while giving you a complete picture of the project's current state.

---

#### Phase 2: ASSESS (first iteration only, or when IMPROVEMENT_PLAN.md doesn't exist)

**Skip this phase if `IMPROVEMENT_PLAN.md` already exists and has uncompleted tasks** — unless the plan feels stale or the codebase has diverged from what the plan describes. Plans are disposable; if the plan is wrong, delete it and reassess. Regeneration is cheap.

Create an agent team named `virtuoso-assess` with 3 teammates. **Give every teammate the `CLAUDE.md` rules** and the orientation summary from Phase 1 so they can flag violations:

- **code-analyst**: Scan the entire codebase for:
  - **CLAUDE.md rule violations** — any code that breaks a rule or principle defined in CLAUDE.md (these are automatically Critical)
  - Architecture gaps and structural issues
  - Dead code and unused imports
  - Missing error handling
  - DRY violations and code duplication
  - Inconsistent patterns across features

  **Use subagents for parallel scanning**: Use the Task tool with `subagent_type: "Explore"` to launch parallel subagents — one per major directory or module — to scan for issues across the codebase simultaneously. Synthesize their findings into a single report with file paths and line numbers.

- **test-analyst**: Scan all tests and test configuration for:
  - **CLAUDE.md rule violations** — missing test coverage required by standards in CLAUDE.md
  - Coverage holes (untested functions, branches, edge cases)
  - Missing edge case tests
  - Flaky or brittle test patterns
  - Integration test gaps between features
  - Missing test utilities or fixtures

  **Use subagents for parallel scanning**: Use the Task tool with `subagent_type: "Explore"` to launch parallel subagents — one scanning test files, one scanning source files for untested exports, one checking test configuration. Report all findings with file paths and line numbers.

- **quality-analyst**: Scan the entire codebase for:
  - **CLAUDE.md rule violations** — security, performance, or quality gate breaches defined in CLAUDE.md
  - Security issues (OWASP Top 10: injection, auth gaps, data exposure, CSRF)
  - Performance problems (N+1 queries, unnecessary re-renders, missing indexes, large imports)
  - Accessibility gaps
  - UX inconsistencies

  **Use subagents for parallel scanning**: Use the Task tool with `subagent_type: "Explore"` to launch parallel subagents — one for security scanning, one for performance analysis, one for accessibility/UX review. Report all findings with file paths and severity.

Wait for all 3 teammates to finish. Shut down all teammates and delete the `virtuoso-assess` team. Synthesize their findings into `IMPROVEMENT_PLAN.md`. **Any CLAUDE.md rule violation is automatically Priority 1: Critical** — these must be fixed before anything else.

```markdown
# Improvement Plan

Generated: <timestamp>
Last updated: <timestamp> (iteration 1)

## Priority 1: Critical (includes all CLAUDE.md rule violations)
- [ ] [ID-001] CLAUDE.MD: Description | files: path/to/file.ts | verify: how to confirm it's done [parallel]
- [ ] [ID-002] Description | files: path/to/other.ts | verify: acceptance criteria

## Priority 2: High
- [ ] [ID-003] Description | files: src/auth/ | verify: tests pass [parallel]
- [ ] [ID-004] Description | files: src/api/routes.ts | verify: no N+1 queries

## Priority 3: Medium
- [ ] [ID-005] Description | files: src/utils/ | verify: no duplicated code [parallel]

## Discoveries
- Notes found during analysis
```

Each task must include: **files** it touches (for ownership boundaries) and **verify** criteria (how to confirm it's done — this is backpressure). Mark tasks with `[parallel]` if they touch independent files and can be worked on simultaneously.

---

#### Phase 3: SELECT

1. Read `IMPROVEMENT_PLAN.md`
2. Pick the highest-priority batch of `[parallel]` tasks (up to 3-4 tasks)
3. If no parallel tasks remain, pick the single highest-priority uncompleted task
4. If all tasks are `[DONE]`, go back to Phase 2 to reassess

---

#### Phase 4: IMPLEMENT (agent team)

Create an agent team named `virtuoso-impl` with one teammate per selected task:

- Each teammate owns specific files — **no overlap between teammates**. Use the `files:` field from `IMPROVEMENT_PLAN.md` to enforce boundaries. Same boundary-setting you'd do with a human team to avoid merge conflicts.
- Give each teammate clear instructions: which task ID, which files to modify, the `verify:` criteria, the **CLAUDE.md rules** they must not violate, and any MCP servers, plugins, or skills documented in CLAUDE.md.
- **Teammates should use subagents for parallel work within their task**: each teammate can use the Task tool with `subagent_type: "Explore"` to research before implementing, and `subagent_type: "general-purpose"` to work on independent files in parallel — each subagent owns a different set of files to avoid conflicts.
- The lead (you) stays in delegate mode — coordinate only, do not implement directly.

Wait for all teammates to finish. Shut down all teammates and delete the `virtuoso-impl` team.

---

#### Phase 5: VALIDATE (backpressure — single agent, NOT parallel)

Run validation yourself — do NOT delegate this to teammates. This is deliberate backpressure: one agent, sequential, full suite. It prevents incomplete work from slipping through.

1. **Discover the correct commands** from `CLAUDE.md` or `AGENTS.md`. Look for test commands, build commands, typecheck/lint commands. If none are documented, discover them from `package.json`, `Makefile`, or equivalent.
2. **Run the full test suite in a subagent** — use the Task tool with `subagent_type: "general-purpose"` to run all tests. This isolates verbose test output from your main context. The subagent returns only the pass/fail result and any failure details.
3. If tests fail: fix the implementation (never modify tests), re-run
4. Run typecheck/lint if available
5. **CLAUDE.md compliance check** — verify the changes don't violate any rule or principle from CLAUDE.md. If CLAUDE.md defines quality gates (e.g. test coverage thresholds, required documentation, security scans), run those gates now. CLAUDE.md violations are blockers — fix them before proceeding.
6. Self-healing loop: up to 3 attempts. If still failing after 3, note the failures in the improvement plan and move on.

---

#### Phase 6: COMMIT

1. Stage all changes
2. Commit with a clear message that captures the **why**, not just the what:
   ```
   virtuoso: [ID-XXX] Why this improvement matters

   What changed and how it was verified.
   ```
   Bad: `virtuoso: [ID-003] Add tests`. Good: `virtuoso: [ID-003] Cover auth token refresh to prevent silent session expiry`
3. If multiple tasks were completed, make one commit per logical change

---

#### Phase 7: UPDATE PLAN

##### 7a. Update `IMPROVEMENT_PLAN.md`

1. Mark completed tasks as `[DONE]` in `IMPROVEMENT_PLAN.md`
2. Update the `Last updated` timestamp and iteration number
3. Add any newly discovered improvements found during implementation to the appropriate priority section
4. Note any blocked tasks or dependencies

##### 7b. Update affected feature files in `queue/`

For each feature file in `queue/` whose behavior was changed by this iteration's improvements:

1. Read the feature file
2. If it does not already have an `## Implementation Updates` section, append one
3. Append an entry under `## Implementation Updates` documenting what changed:

```markdown
## Implementation Updates

### Iteration N — <timestamp>
- **[ID-XXX]** What changed and why
- **[ID-YYY]** What changed and why
```

**Rules:**
- Never modify the original spec content above `## Implementation Updates` — append only
- Only update feature files whose behavior was actually affected by changes in this iteration
- Each entry references the task ID from `IMPROVEMENT_PLAN.md` for traceability
- If no feature files were affected (e.g. the improvements were purely structural or test-only), skip this step

##### 7c. Update `queue/masterplan.md`

Update `masterplan.md` to reflect the current state of the project. This is not a task list — it is a concise project overview that the artist uses as shared context for all workers.

Format:

```markdown
# <Project Name>

> <One-line project description>

## Current State

<2-5 sentences describing what exists today: which features are built, what works, what the architecture looks like. State facts, not aspirations.>

## Architecture

<Brief description of the tech stack, project structure, and key patterns. Only include what actually exists in the codebase.>

## Features

- **<feature-name>**: <one-line status — what it does, whether it's complete>
- **<feature-name>**: <one-line status>

## Standards

<Reference to CLAUDE.md for coding standards. Note any project-specific conventions that emerged during implementation.>

Last updated: <timestamp> (virtuoso iteration N)
```

**Rules:**
- Reflect reality, not aspirations — only document what actually exists in the codebase
- Keep it concise — this gets prepended to every feature file for artist workers
- If `masterplan.md` currently contains only "Template" or is empty, replace the entire content
- If `masterplan.md` already has structured content, update it in place (preserve the format, update the facts)
- Always update the `Last updated` timestamp

##### 7d. Create new feature files for discovered features

If during this iteration you discovered that **new features** (not just improvements to existing code) are needed:

1. Glob `queue/*.md` (excluding `masterplan.md`) to find the highest existing number
2. Create new files starting from the next available number: `queue/<NNN>-<name>.md`
3. Each new feature file must start with a virtuoso-origin marker and contain a clear spec:

```markdown
<!-- virtuoso-generated: iteration N, <timestamp> -->
# <Feature Name>

<Clear description of what this feature should do and why it's needed.>

## Context

Discovered during virtuoso iteration N while working on [ID-XXX].
<Why this feature is needed — what gap or opportunity was identified.>

## Acceptance Criteria

- <Concrete, testable criterion>
- <Concrete, testable criterion>
```

**Rules:**
- Only create feature files for genuinely new features — not for bug fixes, refactors, or improvements to existing features (those belong in `IMPROVEMENT_PLAN.md`)
- New feature files are NOT implemented in the current iteration — they are queued for a future `/maestro-artist` run or a subsequent virtuoso iteration. This respects the "one batch per iteration" rule
- The `<!-- virtuoso-generated -->` comment distinguishes these from user-created feature files
- Also add a note in `IMPROVEMENT_PLAN.md` under a new `## Queued Features` section referencing the new file(s)

##### 7e. Commit plan and queue updates

Stage and commit all changes to `IMPROVEMENT_PLAN.md`, `queue/masterplan.md`, and any `queue/*.md` files modified or created in this phase:

```
virtuoso: update project state (iteration N)

Updated IMPROVEMENT_PLAN.md, masterplan.md, and affected feature files.
```

This is a separate commit from the code changes in Phase 6 — it keeps implementation commits clean and plan updates traceable.

---

#### Phase 8: CHECK COMPLETION

Check if the work is done:

- **If ALL tasks in `IMPROVEMENT_PLAN.md` are `[DONE]`** and no new improvements were discovered during this iteration and no new feature files were created in `queue/` during this iteration:
  Output `ALL_IMPROVEMENTS_COMPLETE` and stop.

- **Otherwise**: Continue to the next iteration. You will spawn fresh agent teams with fresh context windows — teammates never carry stale context between iterations.

---

### End of Loop

If `MAX_ITERATIONS` is reached before all improvements are complete, output:

```
ITERATIONS_EXHAUSTED — <N> iterations completed, <M> tasks remaining in IMPROVEMENT_PLAN.md
```

---

### Critical Rules

1. **Study, don't assume.** Always read existing code before proposing changes. Never assume something isn't implemented — search first. Existing code patterns guide what you generate.
2. **One batch per iteration.** Don't try to do everything in one pass. Pick a focused batch (3-4 tasks max), implement, validate, commit, check. Fresh teams next iteration. This keeps teammates in the smart zone (~20-40% context utilization).
3. **Never modify tests to make them pass.** Fix the implementation instead. Tests are backpressure — they define what "done" means.
4. **Only 1 agent for validation.** Tests run sequentially in one context — this is deliberate backpressure. Incomplete work fails automatically.
5. **Keep the plan updated.** `IMPROVEMENT_PLAN.md` is the bridge between iterations. If you don't update it, the next iteration starts blind.
6. **Plans are disposable.** If the plan has drifted from reality (code changed, tasks no longer make sense), delete it and re-assess. Regeneration is cheap. Don't force-fit work into a stale plan.
7. **CLAUDE.md is supreme.** `CLAUDE.md` is the project's governing document. Rules and principles defined there are non-negotiable — violations are automatically Critical. CLAUDE.md supersedes all other practices. If CLAUDE.md itself needs changing, that's a manual edit, not something the virtuoso overrides.
8. **Do not lie to exit.** Only output `ALL_IMPROVEMENTS_COMPLETE` when ALL improvements are genuinely done. The loop is designed to continue until true completion.
9. **Append only to feature files.** Never modify the original spec content in `queue/*.md` files. The original spec is the source of truth for what was requested. Implementation updates go below `## Implementation Updates` only.
10. **Masterplan reflects reality.** `queue/masterplan.md` documents what exists, not what you hope to build. Every statement in masterplan.md must be verifiable by reading the current codebase. If a feature is partially built, say so.
11. **New features are queued, not implemented.** When you create a new `queue/NNN-name.md` file, do NOT implement it in the same iteration. It waits for a future run. This preserves the "one batch per iteration" rule and prevents scope creep within a single iteration.
12. **Clean up teams between iterations.** Always shut down teammates and delete the team before starting the next phase or iteration. This ensures the next team spawns with completely fresh context.
13. **Use subagents to preserve context.** Delegate heavy codebase scanning to `Explore` subagents and verbose operations (test suites, linting) to `general-purpose` subagents. This keeps your main context and your teammates' contexts clean for decision-making and implementation.
