# Maestro Framework

> Drop feature files in `queue/`, run `/maestro-artist`, walk away.

Turns a feature queue into tested, reviewed, continuously improving code. Built on Claude Code [agent teams](https://code.claude.com/docs/en/agent-teams) + [subagents](https://code.claude.com/docs/en/sub-agents).

```
queue/*.md ──▶ /maestro-artist ──▶ /maestro-critic ──▶ /maestro-virtuoso
               CREATE               CRITIQUE             PERFECT
```

## Quick Start

```bash
# 1. Set up CLAUDE.md with project standards, build/test commands, quality gates
# 2. Create queue/masterplan.md with your project vision
# 3. Break masterplan into features: queue/001-auth.md, 002-dashboard.md, etc.

# Run each phase in its own session
claude --dangerously-skip-permissions
/maestro-artist       # Build all features in parallel
/maestro-critic       # Fix cross-feature conflicts + quality sweep
/maestro-virtuoso     # Perpetual improvement loop
```

All arguments are optional natural language — the lead interprets whatever you pass:

```
/maestro-artist focus on backend only
/maestro-critic skip performance checks
/maestro-virtuoso security, max 5 iterations
```

Defaults: 3 retries (artist/critic), 10 iterations (virtuoso).

## The Three Phases

### `/maestro-artist` — Create

Spawns a `maestro-build` **agent team** with one worker per feature. Workers use **Explore subagents** to research the codebase, **general-purpose subagents** for parallel TDD, and coordinate via `SendMessage` to avoid file conflicts. Features with `depends-on:` lines build in dependency order. Failed workers get replaced with fresh teammates.

### `/maestro-critic` — Critique

Lead uses **Explore subagents** to map the codebase, runs the full test suite, then spawns a `reviewer` **agent team** with two teammates:

- **conflict-checker** — duplicate routes, naming collisions, circular imports, inconsistent schemas
- **quality-sweep** — security (OWASP Top 10), code quality, performance

If validation fails, the lead spawns a fresh reviewer team and retries.

### `/maestro-virtuoso` — Perfect

Perpetual improvement loop using `IMPROVEMENT_PLAN.md` as shared state:

**ORIENT** → **ASSESS** (3-analyst agent team) → **SELECT** → **IMPLEMENT** (agent team with file-ownership boundaries) → **VALIDATE** → **COMMIT** → **UPDATE PLAN** → loop

Each iteration spawns fresh teams. The lead only coordinates — never implements directly.

## Continuous Loop (optional)

Chain virtuoso + critic with the [Ralph Loop plugin](https://github.com/mikeyobrien/ralph-orchestrator) for fresh lead context each cycle:

```bash
claude --dangerously-skip-permissions
/ralph-loop "/maestro-virtuoso then run /maestro-critic" --max-iterations 30
```

Runs 30 full cycles: improve → validate → fresh context → repeat.

## Setup

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with [agent teams](https://code.claude.com/docs/en/agent-teams) enabled:
   ```json
   // ~/.claude/settings.json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```

2. Install skills:
   ```bash
   git clone https://github.com/JohnCari/maestro-framework.git maestro
   cp -r maestro/skills/maestro-artist ~/.claude/skills/
   cp -r maestro/skills/maestro-critic ~/.claude/skills/
   cp -r maestro/skills/maestro-virtuoso ~/.claude/skills/
   ```

3. Configure `CLAUDE.md` with your project's build/test commands and coding standards.

## License

CC0 — Public Domain
