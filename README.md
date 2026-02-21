# Maestro Framework

> Drop feature files in `queue/`, run `/maestro-artist`, walk away.

Agentic coding orchestrator that turns a feature queue into tested, reviewed, continuously improving code. Built on Claude Code [agent teams](https://code.claude.com/docs/en/agent-teams) + [subagents](https://code.claude.com/docs/en/sub-agents) — no external plugins required.

## How It Works

```
  queue/*.md ──▶ /maestro-artist ──▶ /maestro-critic ──▶ /maestro-virtuoso
                 Phase 1: CREATE      Phase 2: CRITIQUE    Phase 3: PERFECT
```

| Phase | Skill | What it does | Agent teams | Subagents |
|:---:|---|---|---|---|
| 1 | `/maestro-artist` | Builds all features in parallel | `maestro-build` — one worker per feature, coordinated via messaging | Workers use `Explore` for research, `general-purpose` for parallel TDD |
| 2 | `/maestro-critic` | Cross-feature conflicts + quality sweep | `reviewer` — conflict-checker + quality-sweep in parallel | Lead + teammates use `Explore` for scanning, `general-purpose` for test isolation |
| 3 | `/maestro-virtuoso` | Perpetual improvement loop | `virtuoso-assess` (3 analysts) + `virtuoso-impl` (workers per task) | All teammates use `Explore` for analysis, `general-purpose` for parallel edits |

**Fresh context** comes from agent teams — each teammate gets its own context window. When retries or new iterations are needed, the lead spawns fresh teams automatically.

## Quick Start

```bash
# 1. Configure CLAUDE.md with project standards, build/test commands, quality gates

# 2. Create queue/masterplan.md with your project vision

# 3. Break the masterplan into feature files: queue/001-auth.md, 002-dashboard.md, etc.

# 4. Run the pipeline
claude --dangerously-skip-permissions
/maestro-artist                    # Build — spawns parallel workers
/maestro-critic                    # Review — fixes cross-feature issues
/maestro-virtuoso                  # Refine — perpetual improvement loop
```

Each phase runs in a separate session. All three skills use `disable-model-invocation: true` — Claude never auto-triggers them.

### Arguments

```
/maestro-artist 5                  # Up to 5 retries per feature (default: 3)
/maestro-critic 5                  # Up to 5 review retries (default: 3)
/maestro-virtuoso 20               # Up to 20 improvement iterations (default: 10)
/maestro-virtuoso security         # Focus improvements on a specific area
```

## Phase Details

### Phase 1 — Artist

Reads `queue/*.md`, spawns one **teammate** per feature in a `maestro-build` agent team. Features with `depends-on:` lines are tiered — independent features build first, dependents wait.

Each worker runs: **ANALYZE** (Explore subagents research codebase) → **PLAN** (Explore subagents for parallel research, broadcast file ownership) → **IMPLEMENT** (general-purpose subagents for parallel TDD) → **TEST** (feature-scoped only) → **COMMIT**.

Workers coordinate via `SendMessage` — announcing file ownership, aligning on shared interfaces. Failed workers get replaced with fresh teammates (up to `MAX_RETRIES`).

### Phase 2 — Critic

Lead uses **Explore subagents** to map the codebase, then runs the full test suite as baseline. Spawns a `reviewer` agent team:

- **conflict-checker** — uses Explore subagents to map routes/exports/state, then fixes: duplicate routes, naming collisions, circular imports, conflicting global state, inconsistent schemas
- **quality-sweep** — uses Explore subagents per category, then fixes: security (OWASP Top 10), code quality (bugs, dead code), performance (N+1, missing indexes)

Validation runs in a **general-purpose subagent** to isolate test output. If tests fail, the lead cleans up and spawns a fresh reviewer team (up to `MAX_RETRIES`).

### Phase 3 — Virtuoso

Perpetual loop with `IMPROVEMENT_PLAN.md` as shared state between iterations:

1. **ORIENT** — read project files + Explore subagents scan the codebase
2. **ASSESS** — `virtuoso-assess` agent team (3 analysts with Explore subagents each)
3. **SELECT** — pick highest-priority batch from the plan
4. **IMPLEMENT** — `virtuoso-impl` agent team (Explore + general-purpose subagents per teammate)
5. **VALIDATE** — single-agent backpressure: full test suite in a general-purpose subagent
6. **COMMIT** → **UPDATE PLAN** → **CHECK** — loop or finish

Each iteration spawns fresh teams. The lead stays lightweight — only coordination, never implementation.

## Setup

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with [agent teams](https://code.claude.com/docs/en/agent-teams) enabled:
   ```json
   // ~/.claude/settings.json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```

2. Install skills:
   ```bash
   git clone https://github.com/JohnCari/maestro-framework.git maestro

   # Personal (all projects)
   cp -r maestro/skills/maestro-artist ~/.claude/skills/
   cp -r maestro/skills/maestro-critic ~/.claude/skills/
   cp -r maestro/skills/maestro-virtuoso ~/.claude/skills/

   # Or project-level (version controlled)
   cp -r maestro/skills/maestro-artist .claude/skills/
   cp -r maestro/skills/maestro-critic .claude/skills/
   cp -r maestro/skills/maestro-virtuoso .claude/skills/
   ```

3. Configure your project's `CLAUDE.md` with build/test commands, coding standards, and any MCP servers or plugins — Maestro discovers and uses them automatically.

### Skill structure

Each skill is a standard [Claude Code skill](https://code.claude.com/docs/en/skills):

```
skills/
├── maestro-artist/SKILL.md       # Phase 1 — parallel feature builder
├── maestro-critic/SKILL.md       # Phase 2 — cross-feature quality review
└── maestro-virtuoso/SKILL.md     # Phase 3 — perpetual improvement engine
```

## License

CC0 — Public Domain
