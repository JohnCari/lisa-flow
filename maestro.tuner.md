---
description: "Maestro Tuner — project foundation: constitution + environment setup (Phase 0)"
argument-hint: "[setup prompt]"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user input is the setup prompt describing what to install and configure.

## Context7

When using any library or framework, use Context7 MCP for accurate docs. Pass this instruction to the worker as `{CONTEXT7}`.

---

## Tuner

You are the tuner. You set the project's foundation before any features are built.

### 1. COMPOSE

Run `speckit.constitution` to define the project's governing document.

1. Use the Skill tool to invoke `speckit.constitution` with args: `$ARGUMENTS` (pass the user's setup prompt so the constitution is seeded with their stack preferences). If `$ARGUMENTS` is empty, invoke with no args.
2. This is interactive — the user defines principles, tools, dependencies, languages, design patterns, testing standards, security requirements, performance standards, and quality gates.
3. Wait for it to complete. The result is `.specify/memory/constitution.md`.

### 2. TUNE

Set up the project environment based on the constitution and the user's setup prompt.

1. Read `.specify/memory/constitution.md` — extract all tools, dependencies, languages, frameworks, testing tools, linting/formatting standards, and folder structure requirements.

2. Read `$ARGUMENTS` as the setup prompt. If empty, derive everything from the constitution alone.

3. Spawn a worker using the `Task` tool:
   - `subagent_type`: `"general-purpose"`
   - `name`: `"tuner-worker"`
   - `mode`: `"bypassPermissions"`
   - `prompt`: the **Worker Prompt** below, with `{CONSTITUTION}` (full text of constitution.md), `{SETUP_PROMPT}` (user's $ARGUMENTS), and `{CONTEXT7}` substituted

4. Wait for the worker to finish. Check output for `SETUP_PASS` or `SETUP_FAILED`.

5. **If failed**: spawn a fresh retry worker with the same prompt. Maximum **2 retries**.

6. Shut down the worker.

### 3. RESULT

Output a summary:

```
TUNER COMPLETE
  Constitution: .specify/memory/constitution.md
  Setup prompt: <what the user asked for>
  Status:       PASS or FAIL
```

If passed: `TUNER_COMPLETE`
If failed after retries: `TUNER_FAILED` with a summary of what went wrong.

---

## Worker Prompt

This is the exact prompt to send to the worker. Substitute `{CONSTITUTION}`, `{SETUP_PROMPT}`, and `{CONTEXT7}` before sending.

---

You are a Maestro tuner worker. Set up the project environment based on the constitution and setup prompt below. Execute these steps **sequentially**.

**CONSTITUTION:**

{CONSTITUTION}

**SETUP PROMPT:**

{SETUP_PROMPT}

**STEPS:**

1. **Study the constitution and setup prompt** above. Extract every tool, dependency, language, framework, testing tool, linter, formatter, and architectural pattern they define. These are your requirements.

2. **Install dependencies.** Initialize the project (npm init, pip init, etc.) and install all required packages. Use exact versions where the constitution specifies them. {CONTEXT7}

3. **Create folder structure.** Set up the directory layout per the architecture standards in the constitution. If the constitution doesn't specify structure, use the conventions of the primary framework.

4. **Configure tooling.** Create config files for:
   - TypeScript / language compiler (tsconfig.json, etc.)
   - Linting (eslint, ruff, etc.)
   - Formatting (prettier, black, etc.)
   - Testing (jest, vitest, pytest, etc.)
   - Any other tools the constitution requires
   All configs must match the standards defined in the constitution.

5. **Create `CLAUDE.md`** at the project root with:
   - Build command
   - Test command (single test + full suite)
   - Lint command
   - Typecheck command
   - Any other commands needed for development
   This file tells future agents how to validate their work.

6. **Validate the setup:**
   - Run the build (should succeed with no source files or a minimal placeholder)
   - Run the linter (should pass on empty/minimal project)
   - Run the test runner (should execute with 0 tests or a placeholder test)
   - If any validation fails, fix the issue and re-run.

Report `SETUP_PASS` when everything works or `SETUP_FAILED` if stuck after fixing.
