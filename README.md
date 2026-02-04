# Lisa Flow

> Structured AI development with automatic TDD, UI polish, and self-healing tests

Combines [GitHub Spec Kit](https://github.com/github/spec-kit) phases with a [Ralph-style](https://ghuntley.com/loop/) self-healing test loop.

## Requirements

### Tools
- **Bash 4.0+** (for array features)
- [Claude Code](https://github.com/anthropics/claude-code)
- [GitHub CLI](https://cli.github.com/) (gh)

### Claude Code Skills
- [GitHub Spec Kit](https://github.com/github/spec-kit) - speckit.* skills
- frontend-design - for BEAUTIFY phase

### MCP Servers
- [Context7](https://github.com/upstash/context7) - up-to-date library documentation (works in headless mode with `-p` flag)

## Setup

### 1. Install Claude Code Skills

Follow the [Spec Kit installation guide](https://github.com/github/spec-kit#installation).

### 2. Configure MCP Servers

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

### 3. Clone Lisa Flow

```bash
git clone https://github.com/JohnCari/lisa-flow.git
chmod +x lisa-flow/lisa-flow.sh
```

## Usage

```bash
./lisa-flow.sh <feature> [retries]
```

- `retries` - Max TEST phase iterations until tests pass (default: 5)
- **Tests are automatically included** - no need to specify "with tests"

### Input Methods

| Method | Example | Description |
|--------|---------|-------------|
| Inline text | `"Build auth API"` | Direct feature description |
| @file | `@spec.md` | Read from file (@ prefix) |

### Examples

```bash
# Inline text
./lisa-flow.sh "Build user auth API"

# Read from file
./lisa-flow.sh @specs/my-feature.md

# With custom test retries
./lisa-flow.sh "Implement shopping cart" 10
```

## How It Works

```
SPECIFY → PLAN → TASKS → IMPLEMENT → BEAUTIFY → TEST
```

| Phase | Description |
|-------|-------------|
| **Specify** | Creates spec with TDD requirement (automatic) |
| **Plan** | Technical implementation plan |
| **Tasks** | Breaks down into tasks.md |
| **Implement** | Builds the feature |
| **Beautify** | UI/UX polish on session's frontend files only (maintains design coherence) |
| **Test** | Self-healing loop with integrated code review |

### TEST Phase Details

The TEST phase combines testing with code quality review in a self-healing loop:

1. **Run all tests** - fix failures in implementation (never modifies tests)
2. **Code quality** - fix bugs, dead code, magic numbers, code smells
3. **Security** - check and fix OWASP vulnerabilities
4. **Performance** - fix inefficiencies

Iterates until all checks pass or max retries reached.

## Inspiration

| Source | Contribution |
|--------|--------------|
| [Ralph Loop](https://ghuntley.com/loop/) by Geoffrey Huntley | Self-healing test loop |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Structured spec phases |

> *"Trust the AI to self-identify, self-correct, and self-improve."* — Geoffrey Huntley

## Features

- **Flexible input** - Accepts inline text or @file syntax
- **Session-scoped phases** - BEAUTIFY only processes files changed this session
- **Safe command execution** - No `eval`, uses array-based execution to prevent command injection
- **ISO 8601 log timestamps** - Sortable log filenames (`YYYY-MM-DD_HH-MM-SS`)
- **Log rotation** - Auto-deletes logs older than 7 days
- **Progress visualization** - Unicode progress bar and phase timing summary

## Security

Uses `--dangerously-skip-permissions` for automation. Use in trusted environments only.

The script validates inputs and uses safe command execution patterns to prevent injection attacks.

## License

CC0 1.0 Universal - Public Domain
