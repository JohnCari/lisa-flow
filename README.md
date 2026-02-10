# Maestro

> Agentic coding orchestrator — turns a feature queue into tested, reviewed, continuously improving code

Drop feature files in `queue/`, run `/maestro.artist`, walk away.

## Architecture

```
        PHASE 1: CREATE               PHASE 2: CRITIQUE              PHASE 3: PERFECT
┌────────────────────────────┐  ┌────────────────────────────┐  ┌────────────────────────────┐
│                            │  │                            │  │                            │
│  /maestro.artist           │  │  /maestro.critic           │  │  /maestro.virtuoso         │
│                            │  │                            │  │  (via ralph-loop)          │
│  queue/ → agent team       │  │  1. run all tests          │  │                            │
│    ├ SPECIFY (speckit)     │  │  2. spawn 2 agents:        │  │  per iteration:            │
│    ├ PLAN   (speckit)      │  │     conflict-checker       │  │    ORIENT  (read all)      │
│    ├ TASKS  (speckit)      │  │     quality-sweep          │  │    ASSESS  (3 agents)      │
│    ├ IMPLEMENT (speckit)   │  │       ├ security           │  │    SELECT  (from plan)     │
│    └ TEST   (up to 3x)    │  │       ├ code quality       │  │    IMPLEMENT (team)        │
│                            │  │       └ performance        │  │    VALIDATE  (tests)       │
│  sequential per feature    │  │  3. final validation       │  │    COMMIT                  │
│  one worker per feature    │  │  self-healing, 3 attempts  │  │    UPDATE PLAN             │
│                            │  │                            │  │  ↻ loops for hours/days    │
└────────────────────────────┘  └────────────────────────────┘  └────────────────────────────┘
```

## Quick Start

```bash
# 1. Set up your project constitution (principles, quality gates)
/speckit.constitution

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

**Phase 1 — Artist:** `/maestro.artist` reads `queue/*.md` files in order, creates a `maestro-build` agent team, and spawns one worker per feature. Each worker runs 5 Spec Kit phases sequentially: `speckit.specify` → `speckit.plan` (with parallel research subagents) → `speckit.tasks` → `speckit.implement` (with parallel implementation subagents) → TEST. Workers use Context7 MCP for accurate library docs. Tests retry up to 3 times (configurable). If a feature fails, a fresh retry worker is spawned. `masterplan.md` is prepended to every feature for shared context.

**Phase 2 — Critic:** `/maestro.critic` runs the full test suite first to establish a clean baseline, then spawns a `reviewer` agent team with 2 teammates: a **conflict-checker** (finds cross-feature conflicts: duplicate routes, naming collisions, circular imports, conflicting state, inconsistent schemas) and a **quality-sweep** (sequential deep scan: security per OWASP Top 10, code quality, performance). Both teammates fix issues they find. Final validation re-runs all tests. Self-healing: if validation fails, the entire team is recreated — up to 3 total attempts.

**Phase 3 — Virtuoso:** `/maestro.virtuoso` runs inside a Ralph Loop for continuous improvement. Each iteration: **ORIENT** (reads constitution, CLAUDE.md, IMPROVEMENT_PLAN.md, speckit artifacts, git history, codebase) → **ASSESS** (spawns 3 read-only agents: code-analyst, test-analyst, quality-analyst — constitution violations are auto-Critical) → **SELECT** (picks highest-priority parallel batch from plan) → **IMPLEMENT** (agent team with file-ownership boundaries, no overlap) → **VALIDATE** (single-agent backpressure: full test suite, typecheck, lint, constitution gates, up to 3 self-healing attempts) → **COMMIT** → **UPDATE PLAN**. `IMPROVEMENT_PLAN.md` is shared state between iterations. Exits with `ALL_IMPROVEMENTS_COMPLETE` only when genuinely done.

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
   cp maestro/maestro.artist.md .claude/commands/maestro.artist.md
   cp maestro/maestro.critic.md .claude/commands/maestro.critic.md
   cp maestro/maestro.virtuoso.md .claude/commands/maestro.virtuoso.md
   ```

## License

CC0 — Public Domain
