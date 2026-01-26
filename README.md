# Lisa Flow

> Structured AI development with automatic TDD and self-healing tests

Combines [GitHub Spec Kit](https://github.com/github/spec-kit) phases with a [Ralph-style](https://ghuntley.com/loop/) self-healing test loop.

## Requirements

- [Claude Code](https://github.com/anthropics/claude-code)
- [GitHub Spec Kit](https://github.com/github/spec-kit)

## Installation

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
SPECIFY → PLAN → TASKS → IMPLEMENT → TEST LOOP
```

1. **Specify** - Creates spec with TDD requirement (automatic)
2. **Plan** - Technical implementation plan
3. **Tasks** - Breaks down into tasks.md
4. **Implement** - Builds the feature
5. **Test Loop** - Runs tests, fixes failures, repeats until pass

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
