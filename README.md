# Lisa Flow

> AI development with TDD and self-healing tests

Runs your feature through structured phases (specify → implement), then loops until all tests pass. Inspired by [Ralph Loop](https://ghuntley.com/loop/) — when something breaks, return it to the loop.

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
SPECIFY → PLAN → TASKS → IMPLEMENT → BEAUTIFY → TEST
```

TEST: tests + code quality + security + performance (self-healing loop)

## License

CC0 - Public Domain
