# Maestro

> Agentic coding orchestrator — turns a feature queue into tested, reviewed, continuously improving code

Drop feature files in `queue/`, run `/maestro.artist`, walk away.

## Architecture

```
   PHASE 0: SETUP        PHASE 1: CREATE        PHASE 2: CRITIQUE       PHASE 3: PERFECT
┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
│  /maestro.tuner    │  │  /maestro.artist   │  │  /maestro.critic   │  │  /maestro.virtuoso │
│                    │  │                    │  │                    │  │   (ralph-loop)     │
│  1. COMPOSE        │  │  queue/ → team     │  │  1. run tests      │  │                    │
│     constitution   │  │    SPECIFY         │  │  2. spawn 2:       │  │  ORIENT            │
│     principles     │  │    PLAN            │  │     conflict ck.   │  │  ASSESS (3)        │
│     standards      │  │    TASKS           │  │     quality sweep  │  │  SELECT            │
│                    │  │    IMPLEMENT       │  │       security     │  │  IMPLEMENT         │
│  2. TUNE           │  │    TEST (3x)       │  │       quality      │  │  VALIDATE          │
│     install deps   │  │                    │  │       perf         │  │  COMMIT            │
│     folder struct  │  │  1 worker/feature  │  │  3. validate       │  │  UPDATE PLAN       │
│     configure      │  │  sequential        │  │  self-heals (3x)   │  │  ↻ loops           │
└────────────────────┘  └────────────────────┘  └────────────────────┘  └────────────────────┘
```

## Quick Start

```bash
# 1. Foundation (constitution + project setup)
/maestro.tuner "Next.js 15, TypeScript, Tailwind, Prisma, PostgreSQL"

# 2. In Claude Code plan mode, create your plan and save as masterplan.md
#    Save to queue/masterplan.md

# 3. In the same session, ask Claude to break the masterplan into features
#    Creates NNN-name.md files in queue/
#    e.g. 001-auth.md, 002-dashboard.md, 003-settings.md

# 4. Build (autonomous — walk away)
/maestro.artist

# 5. Review (interactive — cross-feature quality)
/maestro.critic

# 6. Refine (perpetual — runs for hours/days)
claude --dangerously-skip-permissions
/ralph-loop "/maestro.virtuoso" --completion-promise "ALL_IMPROVEMENTS_COMPLETE"
```

---

### Phase 0 — Tuner

`/maestro.tuner` sets up the project foundation before any features are built. Takes an optional setup prompt describing your stack.

Two internal phases:

1. **COMPOSE** — invokes `speckit.constitution` to define the project's governing document: principles, tools, dependencies, languages, design patterns, testing standards, security requirements, and quality gates
2. **TUNE** — spawns a worker agent that reads the constitution and setup prompt, then:
   - Installs all dependencies
   - Creates the folder structure per architecture standards
   - Configures linting, formatting, and testing tools
   - Creates `CLAUDE.md` with build/test/lint commands
   - Validates the setup (build, lint, and test runner all pass)

The worker self-heals internally — if validation fails, it fixes the issue and re-runs before reporting.

### Phase 1 — Artist

`/maestro.artist` reads `queue/*.md` files in order, creates a `maestro-build` agent team, and spawns one worker per feature. `masterplan.md` is prepended to every feature for shared context.

Each worker runs 5 Spec Kit phases sequentially:

1. **SPECIFY** — `speckit.specify` generates a full feature spec
2. **PLAN** — `speckit.plan` with parallel research subagents (API/data, architecture, testing)
3. **TASKS** — `speckit.tasks` produces dependency-ordered tasks
4. **IMPLEMENT** — `speckit.implement` with parallel subagents, each owning separate files
5. **TEST** — runs all tests, retries up to 3 times (configurable), fixes implementation only

Workers use Context7 MCP for accurate library docs. If a feature fails after retries, a fresh worker is spawned for one more attempt.

### Phase 2 — Critic

`/maestro.critic` runs the full test suite first to establish a clean baseline, then spawns a `reviewer` agent team with 2 teammates:

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

Both teammates fix issues they find. Final validation re-runs all tests. Self-healing: if validation fails, the entire team is recreated — up to 3 total attempts.

### Phase 3 — Virtuoso

`/maestro.virtuoso` runs inside a Ralph Loop for continuous improvement. `IMPROVEMENT_PLAN.md` is shared state between iterations. Each iteration runs 8 phases:

| Phase | What it does |
|---|---|
| **ORIENT** | Reads constitution, CLAUDE.md, IMPROVEMENT_PLAN.md, speckit artifacts, git history, codebase |
| **ASSESS** | Spawns 3 read-only agents: code-analyst, test-analyst, quality-analyst. Constitution violations are auto-Critical |
| **SELECT** | Picks highest-priority parallel batch (up to 3-4 tasks) from the plan |
| **IMPLEMENT** | Agent team with file-ownership boundaries — no overlap between teammates |
| **VALIDATE** | Single-agent backpressure: full test suite, typecheck, lint, constitution gates. Up to 3 self-healing attempts |
| **COMMIT** | One commit per logical change with clear "why" messages |
| **UPDATE PLAN** | Marks tasks done, adds newly discovered improvements |
| **EXIT** | Outputs `ALL_IMPROVEMENTS_COMPLETE` only when genuinely done, otherwise loops |

---

## Setup

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (native install)
2. [Spec Kit](https://github.com/github/spec-kit#installation)
3. [Context7 MCP](https://github.com/upstash/context7#claude-code)
4. [Ralph Loop plugin](https://marketplace.anthropic.com) (for Phase 3)
5. `/frontend-design` skill from [Anthropic Marketplace](https://marketplace.anthropic.com)
6. Enable agent teams in `~/.claude/settings.json`:
   ```json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```
7. Install:
   ```bash
   git clone https://github.com/JohnCari/maestro-framework.git maestro
   cp maestro/maestro.tuner.md .claude/commands/maestro.tuner.md
   cp maestro/maestro.artist.md .claude/commands/maestro.artist.md
   cp maestro/maestro.critic.md .claude/commands/maestro.critic.md
   cp maestro/maestro.virtuoso.md .claude/commands/maestro.virtuoso.md
   ```

## License

CC0 — Public Domain
