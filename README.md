# Lisa Flow

> Structured AI development workflow using GitHub Spec Kit + Ralph-style self-healing tests

A sequential workflow script that runs [GitHub Spec Kit](https://github.com/github/spec-kit) phases with fresh Claude sessions, followed by an automatic self-healing test loop inspired by [Ralph Wiggum Loop](https://ghuntley.com/loop/).

## Inspiration

This project combines two approaches:

| Source | Contribution |
|--------|--------------|
| [Ralph Loop](https://ghuntley.com/loop/) by [Geoffrey Huntley](https://github.com/ghuntley) | Self-healing test loop - iterates until tests pass |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Structured specification phases |

### Why "Lisa"?

Both names come from *The Simpsons*:

| Character | Approach | Used For |
|-----------|----------|----------|
| **Ralph Wiggum** | Persistent but chaotic - keeps trying until it works | Self-healing test loop |
| **Lisa Simpson** | Methodical and structured - plans before acting | Spec Kit phases |

Lisa Flow is the best of both: **structured planning** (Lisa) + **persistent self-correction** (Ralph).

## Requirements

- [Claude Code](https://github.com/anthropics/claude-code) - Anthropic's CLI for Claude
- [GitHub Spec Kit](https://github.com/github/spec-kit) - Specification framework for AI-assisted development

## Installation

```bash
# Clone the repository
git clone https://github.com/JohnCari/lisa-flow.git
cd lisa-flow

# Make the script executable
chmod +x lisa-flow.sh

# Optionally, add to your PATH
cp lisa-flow.sh /usr/local/bin/lisa-flow
```

## Usage

```bash
./lisa-flow.sh "your feature description" [max_test_iterations]
```

### Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `feature description` | Yes | - | What to build |
| `max_test_iterations` | No | 5 | Max test/fix cycles before stopping |

### Examples

```bash
# Default: 5 test iterations max
./lisa-flow.sh "Build a REST API for user management with JWT authentication"

# Custom: 10 test iterations max
./lisa-flow.sh "Implement shopping cart with checkout flow" 10
```

## How It Works

Lisa Flow runs in two phases:

### Phase 1: Lisa Flow (Structured Spec Kit)

```
SPECIFY  -->  PLAN  -->  TASKS  -->  IMPLEMENT
```

Each step runs in a **fresh Claude session**. State persists via filesystem + git.

### Phase 2: Ralph Test Loop (Self-Healing)

```
┌─────────────────────────────────────┐
│     READ tasks.md & RUN TESTS       │
└──────────────┬──────────────────────┘
               │
        Pass? ─┴─ Fail?
         │          │
       EXIT    CLAUDE FIXES CODE
                    │
                    ↓
               (repeat until pass or max iterations)
```

After implementation, the script:
1. **Finds latest `tasks.md`** - Searches `specs/` and `.specify/specs/` for the most recently modified tasks.md
2. **Runs tests** defined in the tasks
3. If tests fail, **Claude analyzes and fixes** the code
4. **Repeats** until all tests pass or max iterations reached

Since Spec Kit creates folders like `specs/001-feature/tasks.md`, `specs/002-feature/tasks.md`, the script automatically finds and uses the latest one.

> *"Tests, builds, and lints reject invalid work. The agent must fix issues before committing. Trust the AI to self-identify, self-correct, and self-improve."* — Geoffrey Huntley

## Complete Workflow

```
============================================
  LISA FLOW - Structured AI Development
============================================

=== SPECIFY ===
(Claude creates specification)

=== PLAN ===
(Claude creates technical plan)

=== TASKS ===
(Claude breaks down into tasks → tasks.md)

=== IMPLEMENT ===
(Claude implements the code)

============================================
  RALPH TEST LOOP - Self-Healing Tests
============================================

--- Test iteration 1 of 5 ---
(Claude reads tasks.md, runs tests, fixes failures)

--- Test iteration 2 of 5 ---

=== ALL TESTS PASSED ===
Lisa completed successfully after 2 iteration(s).
```

## Security Note

This script uses `--dangerously-skip-permissions` which grants Claude full system access. Use in trusted environments only.

## References

- [Ralph Loop - Geoffrey Huntley](https://ghuntley.com/loop/)
- [Ralph Wiggum Plugin - Anthropic](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md)
- [GitHub Spec Kit](https://github.com/github/spec-kit)
- [Claude Code](https://github.com/anthropics/claude-code)

## License

CC0 1.0 Universal - Public Domain
