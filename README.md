# Lisa Flow

> Structured AI development with automatic TDD, UI polish, and security review

Combines [GitHub Spec Kit](https://github.com/github/spec-kit) phases with a [Ralph-style](https://ghuntley.com/loop/) self-healing test loop.

## Requirements

### Tools
- **Bash 4.0+** (for array features)
- [Claude Code](https://github.com/anthropics/claude-code)
- [GitHub CLI](https://cli.github.com/) (gh)

### Claude Code Skills
- [GitHub Spec Kit](https://github.com/github/spec-kit) - speckit.* skills
- frontend-design - for BEAUTIFY phase
- [CodeRabbit](https://github.com/coderabbitai/coderabbit) - for REVIEW phase

### MCP Servers
- [Context7](https://github.com/upstash/context7) - up-to-date library documentation (works in headless mode with `-p` flag)
- [Semgrep](https://github.com/semgrep/mcp) - security vulnerability scanning for SECURITY phase

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
    },
    "semgrep": {
      "command": "uvx",
      "args": ["--python", "3.12", "semgrep-mcp"]
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
./lisa-flow.sh "feature description" [max_test_iterations]
```

**Tests are automatically included** - no need to specify "with tests".

### Examples

```bash
./lisa-flow.sh "Build user auth API"
./lisa-flow.sh "Implement shopping cart" 10
```

## How It Works

```
SPECIFY → PLAN → TASKS → IMPLEMENT → BEAUTIFY → SECURITY → REVIEW → TEST
```

| Phase | Description |
|-------|-------------|
| **Specify** | Creates spec with TDD requirement (automatic) |
| **Plan** | Technical implementation plan |
| **Tasks** | Breaks down into tasks.md |
| **Implement** | Builds the feature |
| **Beautify** | UI/UX polish (accessibility, HCI, visual consistency) |
| **Security** | Semgrep MCP security scan (vulnerabilities, secrets, supply chain) |
| **Review** | CodeRabbit agent code review with autonomous fix cycles |
| **Test** | Self-healing loop until all tests pass |

The test loop reads the latest `tasks.md` and iterates until all tests pass or max iterations reached.

## Inspiration

| Source | Contribution |
|--------|--------------|
| [Ralph Loop](https://ghuntley.com/loop/) by Geoffrey Huntley | Self-healing test loop |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Structured spec phases |

> *"Trust the AI to self-identify, self-correct, and self-improve."* — Geoffrey Huntley

## Features

- **Input validation** - Validates test_retries is a positive integer
- **Safe command execution** - No `eval`, uses array-based execution to prevent command injection
- **ISO 8601 log timestamps** - Sortable log filenames (`YYYY-MM-DD_HH-MM-SS`)
- **Improved error handling** - ERR trap includes line numbers and logs to file
- **Progress visualization** - Unicode progress bar and phase timing summary
- **SECONDS builtin** - Efficient timing without subshells

## Security

Uses `--dangerously-skip-permissions` for automation. Use in trusted environments only.

The script validates inputs and uses safe command execution patterns to prevent injection attacks.

## License

CC0 1.0 Universal - Public Domain
