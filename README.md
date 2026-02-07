# Lisa Flow

> Fully autonomous AI development with structured specs and self-healing tests

Lisa Flow combines [GitHub Spec Kit](https://github.com/github/spec-kit)'s structured phases with [Geoffrey Huntley's Ralph Loop](https://ghuntley.com/loop/) philosophy.

Drop feature files in `harness/`, run `lisa.sh`, walk away. It specs, plans, implements, and polishes each feature — then runs a self-healing test loop until everything passes. Fully hands-off from start to finish.

## Architecture

```
lisa.sh (orchestrator)  →  flow.sh (worker)  →  claude CLI (AI)
```

- **`lisa.sh`** — reads `harness/*.md` features, calls `flow.sh` for each, runs a final integration pass
- **`flow.sh`** — runs a single feature through 5 phases, called by `lisa.sh` (not run directly)

## Setup

1. [Install Claude Code](https://docs.anthropic.com/en/docs/claude-code) (native install)
2. Install `/frontend-design` skill from [Anthropic Marketplace](https://marketplace.anthropic.com)
3. [Install Spec Kit](https://github.com/github/spec-kit#installation)
4. [Install Context7 MCP](https://github.com/upstash/context7#claude-code)
5. [Enable Agent Teams](#enable-agent-teams) (recommended)
6. Clone: `git clone https://github.com/JohnCari/lisa-flow.git`

### Enable Agent Teams

Lisa Flow uses [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams) and [subagents](https://code.claude.com/docs/en/sub-agents) to parallelize work. Agent teams are experimental and disabled by default.

Add this to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or set the environment variable directly:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Restart Claude Code after enabling for changes to take effect.

## Usage

```bash
# 1. Edit the masterplan (shared context for all features)
vim lisa-flow/harness/masterplan.md

# 2. Add numbered feature files
echo "Build auth API with JWT" > lisa-flow/harness/001-auth.md
echo "Build user dashboard" > lisa-flow/harness/002-dashboard.md

# 3. Run
lisa-flow/lisa.sh           # default 3 retries
lisa-flow/lisa.sh 5         # 5 retries per test phase
```

The `harness/` directory lives inside `lisa-flow/`:

```
lisa-flow/
├── harness/
│   ├── masterplan.md       # big picture (read below)
│   ├── 001-step.md         # steps, processed in order
│   └── 002-step.md
├── lisa.sh                 # orchestrator (run this)
├── flow.sh                 # worker (called by lisa.sh)
└── logs/
```

### masterplan.md vs step files

**`masterplan.md`** is the big picture — project-wide context, constraints, and architecture decisions. It gets prepended to every step automatically. Write it once, it applies everywhere. Think of it as the brief that every step reads before starting work.

**`001-step.md`, `002-step.md`, ...** are the actual work. Each file describes one feature or step to build. They are processed in filename order. Keep each step focused — one feature per file. The numbered prefix controls execution order.

## Phases

Each feature goes through 5 phases inside `flow.sh`:

```
SPECIFY → PLAN → TASKS → IMPLEMENT → TEST
```

| Phase | What it does | Parallelism |
|-------|-------------|-------------|
| **SPECIFY** | Generates a spec from the feature description | Single session |
| **PLAN** | Researches and designs the implementation | Subagents |
| **TASKS** | Breaks the plan into ordered tasks | Single session |
| **IMPLEMENT** | Writes the code | Agent team |
| **TEST** | Self-healing loop — runs tests, fixes failures, checks quality/security/perf | Subagents |

After all features complete, `lisa.sh` runs a **final integration pass** using an **agent team** to test everything together and fix cross-feature conflicts.

### Why subagents vs agent teams?

**[Subagents](https://code.claude.com/docs/en/sub-agents)** are lightweight — they do independent work and report results back. Used for PLAN (parallel research) and TEST (parallel checks) where each task is self-contained and workers don't need to talk to each other. Lower token cost.

**[Agent teams](https://code.claude.com/docs/en/agent-teams)** are full Claude instances that coordinate with each other in real time. Used for IMPLEMENT (teammates own different files and need to avoid conflicts) and INTEGRATION (cross-feature fixes may affect the same files). Higher token cost, but worth it when coordination matters.

## How It Works

1. `lisa.sh` reads all `.md` files from `lisa-flow/harness/` (excluding `masterplan.md`)
2. For each feature, it prepends `masterplan.md` content (if present) and calls `flow.sh`
3. `flow.sh` runs the feature through all 5 phases using `claude -p --dangerously-skip-permissions`
4. If a feature fails, `lisa.sh` retries it once automatically
5. After all features, `lisa.sh` runs a final integration pass to catch cross-feature issues
6. Prints a summary table with PASS/FAIL per feature and total time

The entire pipeline is fully autonomous — no human approval prompts, no interaction needed.

## License

CC0 - Public Domain
