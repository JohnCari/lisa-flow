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

Lisa Flow uses [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams) to parallelize work in the PLAN, IMPLEMENT, and TEST phases. Agent teams are experimental and disabled by default.

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
lisa-flow/lisa.sh           # default 5 retries
lisa-flow/lisa.sh 10        # 10 retries per test phase
```

The `harness/` directory lives inside `lisa-flow/`:

```
lisa-flow/
├── harness/
│   ├── masterplan.md       # optional big-picture context, prepended to every feature
│   ├── 001-auth.md         # features, processed in filename order
│   └── 002-dashboard.md
├── lisa.sh                 # orchestrator (run this)
├── flow.sh                 # worker (called by lisa.sh)
└── logs/
```

## Phases

Each feature goes through 5 phases inside `flow.sh`:

```
SPECIFY → PLAN → TASKS → IMPLEMENT → TEST
```

| Phase | What it does |
|-------|-------------|
| **SPECIFY** | Generates a spec from the feature description |
| **PLAN** | Researches and designs the implementation (agent teams parallelize research) |
| **TASKS** | Breaks the plan into ordered tasks |
| **IMPLEMENT** | Writes the code (agent teams parallelize independent tasks) |
| **TEST** | Self-healing loop — runs tests, fixes failures, checks code quality/security/perf (agent teams parallelize checks) |

After all features complete, `lisa.sh` runs a **final integration pass** that tests everything together and fixes cross-feature conflicts.

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
