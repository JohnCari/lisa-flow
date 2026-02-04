# Lisa Flow

> AI development with TDD and self-healing tests

Combines [Spec Kit](https://github.com/github/spec-kit) + [Ralph Loop](https://ghuntley.com/loop/)

## Setup

1. [Install Spec Kit](https://github.com/github/spec-kit#installation)
2. [Install Context7 MCP](https://github.com/upstash/context7#claude-code)
3. Clone: `git clone https://github.com/JohnCari/lisa-flow.git`

## Usage

```bash
./lisa-flow.sh <feature> [retries]
./lisa-flow.sh "Build auth API"
./lisa-flow.sh @spec.md 10
```

## Phases

```
SPECIFY → PLAN → TASKS → IMPLEMENT → BEAUTIFY → TEST
```

TEST phase: tests + code quality + security + performance (self-healing loop)

## License

CC0 - Public Domain
