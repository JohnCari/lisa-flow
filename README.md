# Maestro-Framework

> Agentic coding orchestrator — turns a feature queue into tested, reviewed, continuously improving code

Drop feature files in `queue/`, run `/maestro-artist`, walk away.

## Architecture

Maestro uses two Claude Code parallelism features:

- **[Agent teams](https://code.claude.com/docs/en/agent-teams)** — separate Claude Code instances that coordinate via shared task lists and messaging. Used for orchestrator↔worker coordination (artist), reviewer teams (critic), and assess/impl teams (virtuoso).
- **[Subagents](https://code.claude.com/docs/en/sub-agents)** — lightweight helpers that run within a single session and report results back. Used within workers for parallel codebase research (`Explore`) and parallel implementation (`general-purpose`).

```
   PHASE 1: CREATE        PHASE 2: CRITIQUE       PHASE 3: PERFECT
┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
│  /maestro-artist   │  │  /maestro-critic   │  │  /maestro-virtuoso │
│                    │  │   (ralph-loop)     │  │   (ralph-loop)     │
│  queue/ → team     │  │                    │  │                    │
│    ANALYZE         │  │  1. run tests      │  │  ORIENT            │
│    PLAN            │  │  2. spawn 2:       │  │  ASSESS (3)        │
│    IMPLEMENT       │  │     conflict ck.   │  │  SELECT            │
│    TEST            │  │     quality sweep  │  │  IMPLEMENT         │
│                    │  │       security     │  │  VALIDATE          │
│  1 worker/feature  │  │       quality      │  │  COMMIT            │
│  all in parallel   │  │       perf         │  │  UPDATE PLAN       │
│  workers talk ↔    │  │  3. validate       │  │  ↻ loops           │
└────────────────────┘  └────────────────────┘  └────────────────────┘

Agent teams: orchestrator ↔ workers, reviewer team, assess/impl teams
Subagents:   within workers for parallel research & implementation
```

## Quick Start

```bash
# 1. Set up CLAUDE.md with project principles, build/test commands, quality standards,
#    and any MCP servers, plugins, or skills available to the project

# 2. In Claude Code plan mode, create your plan and save as masterplan.md
#    Save to queue/masterplan.md

# 3. In the same session, ask Claude to break the masterplan into features
#    Creates NNN-name.md files in queue/
#    e.g. 001-auth.md, 002-dashboard.md, 003-settings.md

# 4. Build (autonomous — walk away)
/maestro-artist

# 5. Review (autonomous — cross-feature quality)
claude --dangerously-skip-permissions
/ralph-loop "/maestro-critic" --completion-promise "ALL_TESTS_PASS"

# 6. Refine (perpetual — runs for hours/days)
claude --dangerously-skip-permissions
/ralph-loop "/maestro-virtuoso" --completion-promise "ALL_IMPROVEMENTS_COMPLETE"
```

---

### Phase 1 — Artist

`/maestro-artist` reads `queue/*.md` files, creates a `maestro-build` **agent team**, and spawns all workers in parallel — one per feature. Workers communicate with each other via `SendMessage` to coordinate on shared interfaces, announce file ownership, and avoid conflicts. `masterplan.md` is prepended to every feature for shared context.

Each worker runs 4 phases natively, using **subagents** for parallel research and **teammate messaging** for cross-feature coordination:

1. **ANALYZE** — reads `CLAUDE.md` for project standards and available tools, uses `Explore` subagents to research the codebase, reviews the team roster for potential overlaps
2. **PLAN** — designs the implementation approach using parallel `Explore` subagents, then broadcasts file ownership and coordinates shared interfaces with relevant teammates
3. **IMPLEMENT** — builds the feature with parallel `general-purpose` subagents, each owning separate files. Messages teammates before creating shared interfaces. TDD: tests first, then implementation
4. **TEST** — runs feature-scoped tests once (not the full suite — other workers are mid-build)

If tests fail, the orchestrator spawns a fresh worker with clean context (up to 3 retries, configurable). Each retry sees the code already written and can fix + retest — same fresh-context philosophy as the virtuoso's Ralph Loop.

### Phase 2 — Critic

`/maestro-critic` runs inside a Ralph Loop for fresh-context retries. Each iteration reads `CLAUDE.md` for project standards, runs the **full test suite** to establish a clean baseline (this is the first time all features are validated together), then spawns a `reviewer` **agent team** with 2 teammates:

- **conflict-checker** — finds and fixes cross-feature conflicts:
  - Duplicate routes or API endpoints
  - Naming collisions (functions, variables, CSS classes)
  - Circular imports and import errors
  - Conflicting global state or shared resources
  - Inconsistent data models across features

- **quality-sweep** — sequential deep scan across the entire codebase:
  - **Security** — OWASP Top 10: injection, auth gaps, data exposure, CSRF
  - **Code quality** — bugs, dead code, unused imports, inconsistent error handling
  - **Performance** — N+1 queries, unnecessary re-renders, missing indexes, large imports

Both teammates fix issues they find. Final validation re-runs all tests. If validation fails, the iteration exits and the Ralph Loop restarts with fresh context — fixes from the previous iteration persist in the codebase.

### Phase 3 — Virtuoso

`/maestro-virtuoso` runs inside a Ralph Loop for continuous improvement. `IMPROVEMENT_PLAN.md` is shared state between iterations. Each iteration runs 8 phases:

| Phase | What it does |
|---|---|
| **ORIENT** | Reads CLAUDE.md, AGENTS.md, IMPROVEMENT_PLAN.md, git history. Uses `Explore` **subagents** to study the codebase |
| **ASSESS** | Spawns an **agent team** with 3 read-only analysts: code, test, quality. CLAUDE.md violations are auto-Critical |
| **SELECT** | Picks highest-priority parallel batch (up to 3-4 tasks) from the plan |
| **IMPLEMENT** | **Agent team** with file-ownership boundaries — no overlap between teammates |
| **VALIDATE** | Single-agent backpressure: full test suite, typecheck, lint, CLAUDE.md gates. Up to 3 self-healing attempts |
| **COMMIT** | One commit per logical change with clear "why" messages |
| **UPDATE PLAN** | Marks tasks done, updates affected feature files and masterplan in `queue/`, creates new feature files for discoveries |
| **EXIT** | Outputs `ALL_IMPROVEMENTS_COMPLETE` only when genuinely done, otherwise loops |

---

## Setup

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (native install) — includes built-in [subagents](https://code.claude.com/docs/en/sub-agents) (`Explore`, `general-purpose`, `Plan`) with no additional setup
2. Enable [agent teams](https://code.claude.com/docs/en/agent-teams) (experimental) in `~/.claude/settings.json`:
   ```json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```
3. [Ralph Loop plugin](https://marketplace.anthropic.com) (for Phases 2 & 3)
4. Install:
   ```bash
   git clone https://github.com/JohnCari/maestro-framework.git maestro
   cp -r maestro/skills/maestro-artist .claude/skills/maestro-artist
   cp -r maestro/skills/maestro-critic .claude/skills/maestro-critic
   cp -r maestro/skills/maestro-virtuoso .claude/skills/maestro-virtuoso
   ```

Any MCP servers, plugins, or skills should be configured in your project's `CLAUDE.md` — maestro will discover and use them automatically.

## License

CC0 — Public Domain
