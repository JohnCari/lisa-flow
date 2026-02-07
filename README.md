# Lisa Flow

> Autonomous AI development with structured specs and self-healing tests

Lisa Flow combines [GitHub Spec Kit](https://github.com/github/spec-kit)'s structured phases with [Geoffrey Huntley's Ralph Loop](https://ghuntley.com/loop/) philosophy.

Give it a feature description. It specs, plans, implements, and polishes — then runs a self-healing test loop until everything passes. When something breaks, it goes back to the loop.

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
lisa-flow/flow.sh <feature> [retries]
lisa-flow/flow.sh "Build auth API"
lisa-flow/flow.sh @path/to/spec.md 10
```

- `"feature text"` — describe your feature directly as a string
- `@path/to/file` — read feature description from a file (use `@` prefix followed by the file path)

## Phases

```
SPECIFY → PLAN → TASKS → IMPLEMENT → TEST
```

- **PLAN**: agent teams parallelize research across technical areas
- **IMPLEMENT**: agent teams parallelize coding of independent tasks
- **TEST**: agent teams parallelize checks (tests, code quality, security, performance) — self-healing loop

## Orchestrator

For multiple features, use the orchestrator. Drop `.md` files in a `harness/` directory and let it run through all of them autonomously — [Ralph Loop](https://ghuntley.com/loop/) style.

```bash
mkdir harness

# Optional: big-picture context shared across all features
cat > harness/masterplan.md << 'EOF'
E-commerce platform. React-free, vanilla JS. All features share
a common REST API at /api/. Use SQLite for storage.
EOF

# Feature files (numbered prefix controls order)
echo "Build auth API with JWT" > harness/001-auth.md
echo "Build user dashboard" > harness/002-dashboard.md
echo "Add notifications system" > harness/003-notifications.md

lisa-flow/lisa.sh [retries]
```

- `harness/masterplan.md` — optional big-picture context prepended to every feature
- `harness/001-*.md` — individual features, processed in filename order
- Each feature gets one retry on failure before moving on
- Final integration pass tests everything together and fixes cross-feature issues

## License

CC0 - Public Domain
