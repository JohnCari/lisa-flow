# Lisa Flow

> Structured AI development workflow using GitHub Spec Kit

A sequential workflow script that runs [GitHub Spec Kit](https://github.com/github/spec-kit) phases with fresh Claude sessions. Each phase writes artifacts to disk, and the next session picks up where the last left off.

## Inspiration

This project is inspired by [Ralph Loop](https://ghuntley.com/loop/), created by [Geoffrey Huntley](https://github.com/ghuntley). Ralph Loop is an iterative execution pattern that runs an AI agent repeatedly until completion, with each iteration starting fresh to avoid context pollution.

### Why "Lisa"?

Both names come from *The Simpsons*:

| Character | Approach | Technique |
|-----------|----------|-----------|
| **Ralph Wiggum** | Persistent but chaotic - keeps trying until it works | Loop until PRD complete |
| **Lisa Simpson** | Methodical and structured - plans before acting | Sequential spec phases |

Lisa Flow takes the "fresh context per iteration" insight from Ralph Loop but applies it to a structured, phase-based workflow using Spec Kit.

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
./lisa-flow.sh "your feature description"
```

### Example

```bash
./lisa-flow.sh "Build a REST API for user management with JWT authentication"
```

## How It Works

Lisa Flow runs four Spec Kit phases sequentially, each in a **fresh Claude session**:

```
1. /speckit.specify  -->  Writes spec to disk
2. /speckit.plan     -->  Reads spec, writes plan
3. /speckit.tasks    -->  Reads plan, writes tasks
4. /speckit.implement -->  Reads tasks, implements
```

**Key insight:** State persists via filesystem + git, not session memory. Each phase gets full context for its work only, avoiding the context accumulation problem.

### Why Fresh Sessions?

During long sessions, Claude's context window fills with conversation history, file contents, and commands. This reduces performance. By starting fresh each phase:

- No context pollution from previous phases
- Each session focuses on one job
- Spec Kit artifacts carry all necessary state

## Security Note

This script uses `--dangerously-skip-permissions` which grants Claude full system access. Use in trusted environments only.

## References

- [Ralph Loop - Geoffrey Huntley](https://ghuntley.com/loop/)
- [GitHub Spec Kit](https://github.com/github/spec-kit)
- [Claude Code](https://github.com/anthropics/claude-code)
- [Ralph Wiggum Plugin](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md)

## License

CC0 1.0 Universal - Public Domain
