---
name: maestro-artist
description: "Maestro Artist — Phase 1: parallel feature builder using agent teams and subagents. Use after populating queue/*.md with feature files to build all features in parallel."
argument-hint: "[optional instructions]"
user-invocable: true
disable-model-invocation: true
---

## User Input

```text
$ARGUMENTS
```

Interpret the user input as natural language instructions. Examples: "focus on backend only", "skip the auth feature", "max 5 retries". If empty, use defaults. Default `MAX_RETRIES` is **3** unless the user specifies otherwise.

---

## Orchestrator

You are the orchestrator. You coordinate only — never implement directly.

### 0. Read Project Standards

Read `CLAUDE.md` (if it exists) for project standards, build/test commands, coding conventions, and any available MCP servers, plugins, or skills. This context informs how you configure workers and what commands to use.

### 1. Read the Queue

1. Glob `queue/*.md`. Exclude `masterplan.md`.
2. Sort remaining files by filename (numbered: `001-step.md`, `002-step.md`, …).
3. If empty, error: `"No feature .md files in queue/"` and stop.
4. Read `queue/masterplan.md` if it exists → `MASTER_PLAN`.
5. Read each feature file → `FEATURE_CONTENT`.
6. Check each feature for a `depends-on:` line (e.g. `depends-on: 001`). Sort features into dependency tiers:
   - **Tier 0**: Features with no `depends-on:` — spawn immediately in parallel
   - **Tier 1**: Features that depend on Tier 0 — spawn after their dependencies complete
   - **Tier N**: Features that depend on Tier N-1 — spawn after their dependencies complete
   - If no features have `depends-on:`, all are Tier 0 (current behavior preserved)

Output:

```
Features: <count>
Retries:  <MAX_RETRIES>
```

### 2. Create the Team

Use `TeamCreate` → team named `maestro-build`.

For each feature, `TaskCreate`:
- Subject: `Build: <filename without .md>`
- Description: feature content
- ActiveForm: `Building <filename>`

### 3. Spawn All Workers (Parallel)

For each feature, build `COMBINED_FEATURE`:
- If `MASTER_PLAN` exists: `MASTER_PLAN + "\n\n---\n\n" + FEATURE_CONTENT`
- Otherwise: `FEATURE_CONTENT`

Build a `TEAM_ROSTER` — a plain-text list of all workers and their assigned features:

```
Team roster:
  worker-001 → 001-auth.md
  worker-002 → 002-dashboard.md
  worker-003 → 003-settings.md
```

Spawn workers by dependency tier — all features within a tier launch simultaneously. Wait for a tier to complete before spawning the next tier. For each feature, use the `Task` tool:
- `subagent_type`: `"general-purpose"`
- `team_name`: `"maestro-build"`
- `name`: `"worker-<NNN>"` (matching the feature number)
- `mode`: `"bypassPermissions"`
- `prompt`: the **Worker Prompt** below, with `{COMBINED_FEATURE}` and `{TEAM_ROSTER}` substituted

`TaskUpdate` each task → `in_progress`.

Output:

```
Spawned <count> workers in parallel
```

### 4. Monitor and Collect Results

Wait for all workers to finish. As each worker completes, check output for `ALL_TESTS_PASS` or `TESTS_FAILED`.

- **If passed**: `TaskUpdate` → `completed`. Record PASS.
- **If failed**: shut down the failed worker. Spawn a **fresh worker** with clean context and the same prompt — the new worker sees the code already written and can fix + retest. Retry up to `MAX_RETRIES` times per feature (each retry = fresh teammate = fresh context window). Record final result. `TaskUpdate` → `completed` with result noted.

### 5. Summary

```
---------------------------------------------

  <feature-name>          PASS
  <feature-name>          FAIL

---------------------------------------------
SUCCESS  N/M features
```

If all passed, output: `ORCHESTRATOR_ALL_FEATURES_DONE`

If any failed: `FAILED  N/M features`


### 6. Clean Up

Shut down all teammates, then `TeamDelete`.

---

## Worker Prompt

This is the exact prompt to send to each worker teammate. Substitute `{COMBINED_FEATURE}` and `{TEAM_ROSTER}` before sending.

---

You are a Maestro build worker — one of several teammates building features **in parallel**. You can message other workers directly using `SendMessage` to coordinate.

**YOUR TEAM**

{TEAM_ROSTER}

Read `~/.claude/teams/maestro-build/config.json` to discover teammate names for messaging. Use `SendMessage` with `type: "message"` and the teammate's name as `recipient`.

**WHEN TO COMMUNICATE**

- **Announce file ownership** — after planning (Phase 2), broadcast which files you will modify so teammates can avoid conflicts.
- **Coordinate shared interfaces** — if your feature creates or consumes APIs, types, data models, or shared utilities that other features might use, message the relevant teammate(s) to align on contracts before implementing.
- **Share discoveries** — if you find an existing utility, pattern, or gotcha that another feature likely needs, message that teammate.
- **Respond to teammates** — if a teammate messages you about a shared interface or conflict, respond and adjust your plan as needed.
- **Don't over-communicate** — only message when it prevents a conflict or shares something genuinely useful. Don't broadcast status updates.

---

Execute these 5 phases **sequentially**. Do not skip phases. Do not proceed until the current phase completes.

**PHASE 1: ANALYZE**

Read `CLAUDE.md` (if it exists) for project standards, build/test commands, coding conventions, and any available MCP servers, plugins, or skills. Use whatever tools are documented there throughout all phases.

Then read and internalize the feature description:

{COMBINED_FEATURE}

Use the Task tool with `subagent_type: "Explore"` to research the existing codebase — find relevant files, existing patterns, APIs, data models, and utilities that can be reused. Identify: what needs to be built, what already exists, what files will be affected, and what tests are needed. Include comprehensive tests following Test Driven Development.

Review the team roster to understand what other features are being built in parallel. Note potential overlaps or shared dependencies.

**PHASE 2: PLAN**

Based on your analysis, design the implementation approach. Use the Task tool with `subagent_type: "Explore"` to run up to 3 parallel research subagents if needed: one for API and data layer research, one for architecture patterns and dependencies, one for testing strategy. Synthesize all findings into a clear plan: file-by-file changes, dependency order, and risk areas.

After planning, **broadcast your file list** to all teammates so they know which files you own. If you see shared dependencies with another feature (e.g. you both need the same API route, data model, or utility), **message that teammate directly** to agree on the contract before implementing.

**PHASE 3: IMPLEMENT**

Implement the feature following your plan. Use subagents (`subagent_type: "general-purpose"`) to work in parallel on independent files — each subagent owns a different set of files to avoid conflicts. Write tests first (TDD), then implementation.

If you need to create or modify a shared interface (types, API contracts, shared modules), message affected teammates first and agree on the shape before writing code.

**PHASE 4: TEST**

Run only the tests related to **your feature** — unit tests and feature-level integration tests you wrote. Do NOT run the full test suite (other workers are building in parallel; their incomplete code will cause false failures). The full cross-feature test suite runs later in `/maestro-critic`.

Run tests once. If any fail, output `TESTS_FAILED` with a summary of failures. Do not retry — the orchestrator will spawn a fresh worker with clean context if needed.

**PHASE 5: COMMIT**

If all tests passed, stage and commit your changes before reporting success. This ensures your work survives session crashes.

```
maestro-artist: Built <feature-name>

Implemented <brief description of what was built>.
```

After committing, output `ALL_TESTS_PASS`. If tests failed, skip this phase and output `TESTS_FAILED`.

Report `ALL_TESTS_PASS` or `TESTS_FAILED` when done.
