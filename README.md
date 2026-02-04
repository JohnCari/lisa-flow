# Lisa Flow

> Autonomous AI development with structured specs and self-healing tests

Lisa Flow combines [GitHub Spec Kit](https://github.com/github/spec-kit)'s structured phases with [Geoffrey Huntley's Ralph Loop](https://ghuntley.com/loop/) philosophy.

Give it a feature description. It specs, plans, implements, and polishes — then runs a self-healing test loop until everything passes. When something breaks, it goes back to the loop.

## Setup

1. [Install Claude Code](https://docs.anthropic.com/en/docs/claude-code) (native install)
2. Install `/frontend-design` skill from [Anthropic Marketplace](https://marketplace.anthropic.com)
3. [Install Spec Kit](https://github.com/github/spec-kit#installation)
4. [Install Context7 MCP](https://github.com/upstash/context7#claude-code)
5. Clone: `git clone https://github.com/JohnCari/lisa-flow.git`

## Usage

```bash
lisa-flow/lisa-flow.sh <feature> [retries]
lisa-flow/lisa-flow.sh "Build auth API"
lisa-flow/lisa-flow.sh @path/to/spec.md 10
```

- `"feature text"` — describe your feature directly as a string
- `@path/to/file` — read feature description from a file (use `@` prefix followed by the file path)

## Phases

```
SPECIFY → PLAN → TASKS → IMPLEMENT → TEST
```

TEST: tests + code quality + security + performance (self-healing loop)

## License

CC0 - Public Domain
