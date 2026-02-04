# Lisa Flow

> Autonomous AI development with structured specs and self-healing tests

Lisa Flow combines [GitHub Spec Kit](https://github.com/github/spec-kit)'s structured phases with [Geoffrey Huntley's Ralph Loop](https://ghuntley.com/loop/) philosophy.

Give it a feature description. It specs, plans, implements, and polishes — then runs a self-healing test loop until everything passes. When something breaks, it goes back to the loop.

## Setup

1. [Install Spec Kit](https://github.com/github/spec-kit#installation)
2. [Install Context7 MCP](https://github.com/upstash/context7#claude-code)
3. Clone: `git clone https://github.com/JohnCari/lisa-flow.git`

## Usage

```bash
lisa-flow/lisa-flow.sh <feature> [retries]
lisa-flow/lisa-flow.sh "Build auth API"
lisa-flow/lisa-flow.sh @spec.md 10
```

## Phases

```
SPECIFY → PLAN → TASKS → IMPLEMENT → TEST
```

TEST: tests + code quality + security + performance (self-healing loop)

## License

CC0 - Public Domain
