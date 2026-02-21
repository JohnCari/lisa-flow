# Maestro Framework

> Agentic coding orchestrator — turns a feature queue into tested, reviewed, continuously improving code.

Drop feature files in `queue/`, run `/maestro-artist`, walk away.

---

## Architecture

Maestro runs three phases sequentially. Every phase uses both [agent teams](https://code.claude.com/docs/en/agent-teams) and [subagents](https://code.claude.com/docs/en/sub-agents). Agent teams coordinate parallel multi-session work (teammates with independent context windows). Subagents handle focused research and isolated operations within a single session (codebase exploration, test running). Fresh context comes from spawning fresh teammates — no external plugins required.

All three skills are [Claude Code skills](https://code.claude.com/docs/en/skills) with `disable-model-invocation: true` — they only run when you explicitly invoke them via `/maestro-artist`, `/maestro-critic`, or `/maestro-virtuoso`.

```
  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                       MAESTRO PIPELINE                                       │
  └──────────────────────────────────────────────────────────────────────────────────────────────┘

  ┌─ PHASE 1 ──────────────────┐   ┌─ PHASE 2 ──────────────────┐   ┌─ PHASE 3 ──────────────────┐
  │                            │   │                            │   │                            │
  │  /maestro-artist           │   │  /maestro-critic           │   │  /maestro-virtuoso         │
  │  CREATE                    │   │  CRITIQUE                  │   │  PERFECT                   │
  │                            │   │                            │   │                            │
  │  queue/*.md                │   │  ⊳ Explore subagents       │   │  ORIENT                    │
  │      │                     │   │    scan codebase            │   │  ⊳ Explore subagents       │
  │      ▼                     │   │      │                     │   │    scan src/tests/config    │
  │  ┌─────────┐               │   │      ▼                     │   │      │                     │
  │  │  team:  │               │   │  run full test suite       │   │  ASSESS                    │
  │  │  build  │               │   │      │                     │   │  ┌─────────────────┐        │
  │  └────┬────┘               │   │      ▼                     │   │  │ team: v-assess  │        │
  │       │                    │   │  ┌─────────┐               │   │  │ ⊳ each analyst  │        │
  │  ┌────┼────┐               │   │  │  team:  │               │   │  │   uses Explore  │        │
  │  ▼    ▼    ▼               │   │  │ reviewer│               │   │  └────────┬────────┘        │
  │ w-1  w-2  w-3              │   │  └────┬────┘               │   │  SELECT ── pick batch      │
  │  │    │    │               │   │  ┌────┴────┐               │   │  IMPLEMENT                  │
  │  ▼    ▼    ▼               │   │  ▼         ▼               │   │  ┌─────────────────┐        │
  │ ANALYZE                    │   │ conflict  quality          │   │  │ team: v-impl    │        │
  │ ⊳ Explore subagents       │   │ checker   sweep            │   │  │ ⊳ teammates use │        │
  │ PLAN                       │   │ ⊳ Explore  ⊳ Explore      │   │  │   Explore + g-p │        │
  │ ⊳ Explore subagents       │   │  subagents  subagents      │   │  │   subagents     │        │
  │ IMPLEMENT                  │   │             │              │   │  └────────┬────────┘        │
  │ ⊳ general-purpose         │   │        sec / qual / perf   │   │  VALIDATE                   │
  │   subagents (TDD)          │   │             │              │   │  ⊳ g-p subagent runs       │
  │ TEST                       │   │      ⊳ g-p subagent       │   │    test suite               │
  │ COMMIT                     │   │        runs tests          │   │  COMMIT                     │
  │                            │   │      validate + commit     │   │  UPDATE PLAN                │
  │ retries: orchestrator      │   │                            │   │  CHECK ── loop or done      │
  │ spawns fresh workers       │   │  retries: lead spawns      │   │                            │
  │                            │   │  fresh reviewer team       │   │  ↻ lead loops, spawns      │
  │                            │   │                            │   │    fresh teams each iter    │
  └────────────────────────────┘   └────────────────────────────┘   └────────────────────────────┘

  Agent teams: multi-session coordination (teammates with independent context windows)
  Subagents:   within-session research (Explore) and isolation (general-purpose)
  Fresh context: each spawned teammate gets its own context window automatically
```

---

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
claude --dangerously-skip-permissions
/maestro-artist

# 5. Review (autonomous — cross-feature quality, up to 3 retries)
claude --dangerously-skip-permissions
/maestro-critic

# 6. Refine (perpetual — runs for hours/days, up to 10 iterations)
claude --dangerously-skip-permissions
/maestro-virtuoso
```

---

## Phase Details

### Phase 1 — Artist

`/maestro-artist` reads `CLAUDE.md` for project standards, then reads `queue/*.md` files, creates a `maestro-build` **agent team**, and spawns workers in parallel — one per feature. Workers communicate via `SendMessage` to coordinate shared interfaces, announce file ownership, and avoid conflicts. `masterplan.md` is prepended to every feature for shared context.

Features with `depends-on:` lines are spawned in dependency order — independent features first, dependent features after their dependencies complete.

Each worker (teammate) runs 5 phases, using **subagents** throughout:

| Phase | What it does |
|---|---|
| **ANALYZE** | Reads `CLAUDE.md`, uses `Explore` subagents to research the codebase, reviews team roster for overlaps |
| **PLAN** | Designs implementation with parallel `Explore` subagents, broadcasts file ownership, coordinates shared interfaces |
| **IMPLEMENT** | Builds with parallel `general-purpose` subagents, each owning separate files. TDD: tests first |
| **TEST** | Runs feature-scoped tests only (not full suite — other workers are mid-build) |
| **COMMIT** | Commits changes on success for crash safety |

If tests fail, the orchestrator spawns a fresh worker with clean context (up to 3 retries, configurable). Each fresh worker = fresh context window.

### Phase 2 — Critic

`/maestro-critic` runs a retry loop managed by the lead. The lead first uses `Explore` **subagents** to research the codebase structure, cross-feature touchpoints, and recent git history — keeping heavy exploration out of main context. Each iteration runs the **full test suite** to establish a clean baseline, then spawns a `reviewer` **agent team** with 2 teammates:

| Teammate | Focus | Subagent usage |
|---|---|---|
| **conflict-checker** | Duplicate routes, naming collisions, circular imports, conflicting global state, inconsistent data models | `Explore` subagents map all routes/exports/state across modules before fixing |
| **quality-sweep** | **Security** (OWASP Top 10) → **Code quality** (bugs, dead code, error handling) → **Performance** (N+1 queries, bundle size, indexes) | `Explore` subagents scan per category before fixing |

Both teammates fix issues they find. Validation runs in a `general-purpose` **subagent** to isolate verbose test output. The lead cleans up the team, commits on success. If validation fails and retries remain, the lead spawns a **fresh reviewer team** — new teammates get clean context windows automatically.

### Phase 3 — Virtuoso

`/maestro-virtuoso` runs a perpetual improvement loop managed by the lead. `IMPROVEMENT_PLAN.md` is shared state between iterations. Each iteration spawns fresh agent teams, so teammates always get clean context. **Subagents** are used throughout for focused research and test isolation. The lead runs up to 10 iterations (configurable) through 8 phases:

| Phase | What it does | Subagent usage |
|---|---|---|
| **ORIENT** | Reads CLAUDE.md, AGENTS.md, IMPROVEMENT_PLAN.md, queue files, git history | `Explore` subagents scan src/, tests/, and config in parallel |
| **ASSESS** | Spawns a **fresh agent team** with 3 analysts: code, test, quality. CLAUDE.md violations are auto-Critical | Each analyst uses `Explore` subagents for parallel scanning |
| **SELECT** | Picks highest-priority parallel batch (up to 3-4 tasks) from the plan | — |
| **IMPLEMENT** | **Fresh agent team** with file-ownership boundaries — no overlap between teammates | Teammates use `Explore` + `general-purpose` subagents for research and parallel file edits |
| **VALIDATE** | Single-agent backpressure: full test suite, typecheck, lint, CLAUDE.md gates. Up to 3 self-healing attempts | `general-purpose` subagent isolates verbose test output |
| **COMMIT** | One commit per logical change with clear "why" messages | — |
| **UPDATE PLAN** | Marks tasks done, updates affected feature files and masterplan in `queue/`, creates new feature files for discoveries | — |
| **CHECK** | If all done → `ALL_IMPROVEMENTS_COMPLETE`. Otherwise → next iteration with fresh teams | — |

---

## Skills Structure

Each skill follows the official [Claude Code skill specification](https://code.claude.com/docs/en/skills):

```
skills/
├── maestro-artist/
│   └── SKILL.md          # Phase 1 — parallel feature builder
├── maestro-critic/
│   └── SKILL.md          # Phase 2 — cross-feature quality review
└── maestro-virtuoso/
    └── SKILL.md          # Phase 3 — perpetual improvement engine
```

### Frontmatter

All three skills use the same frontmatter pattern:

| Field | Value | Why |
|---|---|---|
| `name` | `maestro-artist` / `maestro-critic` / `maestro-virtuoso` | Slash command name |
| `description` | Phase description + when to use | Shown in `/` autocomplete menu |
| `argument-hint` | `[max-retries]` or `[optional focus area or max-iterations]` | Autocomplete hint |
| `user-invocable` | `true` | Appears in `/` menu |
| `disable-model-invocation` | `true` | Prevents Claude from auto-triggering these heavy pipelines |

### Invocation

Skills are invoked manually only — Claude will never auto-trigger them:

```
/maestro-artist          # Build all features from queue/
/maestro-artist 5        # Build with up to 5 retries per feature
/maestro-critic          # Review with up to 3 retries (default)
/maestro-critic 5        # Review with up to 5 retries
/maestro-virtuoso        # Improve for up to 10 iterations (default)
/maestro-virtuoso 20     # Improve for up to 20 iterations
/maestro-virtuoso security  # Focus improvements on security
```

---

## Setup

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (native install) — includes built-in [subagents](https://code.claude.com/docs/en/sub-agents) (`Explore`, `general-purpose`, `Plan`)
2. Enable [agent teams](https://code.claude.com/docs/en/agent-teams) (experimental):
   ```json
   // ~/.claude/settings.json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```
3. Install skills into your personal or project skill directory:
   ```bash
   # Personal (available across all projects)
   git clone https://github.com/JohnCari/maestro-framework.git maestro
   cp -r maestro/skills/maestro-artist ~/.claude/skills/maestro-artist
   cp -r maestro/skills/maestro-critic ~/.claude/skills/maestro-critic
   cp -r maestro/skills/maestro-virtuoso ~/.claude/skills/maestro-virtuoso

   # Or project-level (shared via version control)
   cp -r maestro/skills/maestro-artist .claude/skills/maestro-artist
   cp -r maestro/skills/maestro-critic .claude/skills/maestro-critic
   cp -r maestro/skills/maestro-virtuoso .claude/skills/maestro-virtuoso
   ```

Configure MCP servers, plugins, or additional skills in your project's `CLAUDE.md` — maestro discovers and uses them automatically.

---

## License

CC0 — Public Domain
