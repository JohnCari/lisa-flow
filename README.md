# Lisa Flow

> Structured AI development with automatic TDD, UI polish, and security review

Combines [GitHub Spec Kit](https://github.com/github/spec-kit) phases with a [Ralph-style](https://ghuntley.com/loop/) self-healing test loop.

## Requirements

### Tools
- [Claude Code](https://github.com/anthropics/claude-code)
- [GitHub CLI](https://cli.github.com/) (gh)

### Claude Code Skills
- [GitHub Spec Kit](https://github.com/github/spec-kit) - speckit.* skills
- frontend-design - for BEAUTIFY phase

### MCP Servers
- [Context7](https://github.com/upstash/context7) - up-to-date library documentation

## Setup

### 1. Install Claude Code Skills

Follow the [Spec Kit installation guide](https://github.com/github/spec-kit#installation).

### 2. Configure Context7 MCP

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
SPECIFY → PLAN → TASKS → IMPLEMENT → BEAUTIFY → SECURITY → TEST
```

| Phase | Description |
|-------|-------------|
| **Specify** | Creates spec with TDD requirement (automatic) |
| **Plan** | Technical implementation plan |
| **Tasks** | Breaks down into tasks.md |
| **Implement** | Builds the feature |
| **Beautify** | UI/UX polish (accessibility, HCI, visual consistency) |
| **Security** | OWASP Secure Coding Practices review (14 areas) |
| **Test** | Self-healing loop until all tests pass |

The test loop reads the latest `tasks.md` and iterates until all tests pass or max iterations reached.

## Inspiration

| Source | Contribution |
|--------|--------------|
| [Ralph Loop](https://ghuntley.com/loop/) by Geoffrey Huntley | Self-healing test loop |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Structured spec phases |

> *"Trust the AI to self-identify, self-correct, and self-improve."* — Geoffrey Huntley

## Security

Uses `--dangerously-skip-permissions`. Use in trusted environments only.

## License

CC0 1.0 Universal - Public Domain
