# Recruiting Agency — Claude Code Plugin

A self-organizing multi-agent team that assembles specialized AI agent teams on demand. Three autonomous agents collaborate to define, evaluate, approve, and persist new Claude Code subagents.

## Installation

### Quick Install (Interactive)

```bash
./install.sh
```

The installer prompts you to choose: project-level, user-level, or both.

### Targeted Install

```bash
# Install into a specific project
./install.sh project ~/my-app

# Install globally (available in all projects)
./install.sh user

# Install both
./install.sh both

# Force overwrite without prompts
./install.sh -f project
```

### Manual Install

```bash
# Project-level
cp -r .claude/ /path/to/your/project/.claude/

# Global
cp .claude/agents/*.md ~/.claude/agents/
cp .claude/commands/recruiting.md ~/.claude/commands/recruiting.md
```

### Management

```bash
# Check installation status
./install.sh status

# Uninstall
./install.sh uninstall           # from project
./install.sh uninstall-user      # from ~/.claude
./install.sh uninstall-all       # both
```

No dependencies, no build step.

## Usage

In any Claude Code conversation, invoke the slash command:

```
/recruiting I want to build a real-time chat application with WebSocket support, React frontend, and Go backend.
```

```
/recruiting I need a cloud engineer to help me build a Lambda-based API in AWS.
```

```
/recruiting Ich möchte eine mobile App für Restaurantbewertungen bauen — stelle mir ein passendes Team zusammen.
```

The plugin detects the language of your input and generates culturally appropriate agent names.

## How It Works

### The Team

| Agent | Role | Model |
|-------|------|-------|
| **Victoria** (CEO) | Receives your request, formulates the project vision, approves all hires, decides where agents are stored | `claude-opus-4-6` |
| **Nathan** (Requirements Analyst) | Analyzes requirements, checks for existing agents that can be reused, validates proposals | `claude-sonnet-4-6` |
| **Sophia** (Recruiting Specialist) | Designs new agent definitions with precise system prompts and appropriate model selection | `claude-sonnet-4-6` |

### Workflow

```
User Request
    │
    ▼
┌──────────┐
│ Victoria  │ ── Formulates Project Brief
│  (CEO)    │    (Goal, Context, Roles, Scope)
└────┬─────┘
     │
     ▼
┌──────────┐
│  Nathan   │ ── Analyzes requirements
│ (Analyst) │ ── Scans existing agents (.claude/agents/ + ~/.claude/agents/)
└────┬─────┘ ── Decides: REUSE / UPDATE / RECRUIT
     │
     ▼ (for each RECRUIT)
┌──────────┐
│  Sophia   │ ◄──┐
│(Recruiter)│    │  Feedback loop (max 3 iterations)
└────┬─────┘    │
     │          │
     ▼          │
┌──────────┐    │
│  Nathan   │ ──┘  Validates proposal
│ (Analyst) │
└────┬─────┘
     │
     ▼
┌──────────┐
│ Victoria  │ ── Final approval + scope decision
│  (CEO)    │    (project / user / local)
└────┬─────┘
     │
     ▼
  Write agent .md file to disk
     │
     ▼
  Summary Report
```

### Persistence Scopes

Victoria decides where each agent is stored:

| Scope | Path | Use Case |
|-------|------|----------|
| `project` | `.claude/agents/<name>.md` | Agents specific to this project (versioned in git) |
| `user` | `~/.claude/agents/<name>.md` | Generic agents reusable across all projects |
| `local` | `.claude/agents/<name>.md` | Experimental or sensitive agents (added to `.gitignore`) |

### Existing Agent Handling

Before creating any new agent, Nathan inventories all existing agents:

- **80%+ skill overlap** → Reuse the existing agent as-is
- **40-79% overlap** → Propose an update (with CEO confirmation; significant changes create a new agent instead)
- **<40% overlap** → Recruit a new specialist

## Agent File Format

All generated agents follow the Claude Code subagent format:

```markdown
---
name: James (Senior Go Backend Engineer)
model: claude-sonnet-4-6
description: Specializes in Go microservices with gRPC, PostgreSQL, and AWS deployment.
---

# Role: Senior Go Backend Engineer — James

You are **James**, a senior Go backend engineer...

## Core Responsibilities
...

## Technical Expertise
...
```

## Supported Languages

The name generator supports: English, German, Spanish, French, Japanese (Romaji), and Portuguese. The language is auto-detected from your input.

## File Structure

```
.claude/
├── commands/
│   └── recruiting.md      # Slash command entry point
└── agents/
    ├── victoria.md         # CEO
    ├── nathan.md           # Requirements Analyst
    └── sophia.md           # Recruiting Specialist
```

## Tips

- Be specific in your request — the more context you provide, the better the assembled team.
- You can request a single specialist or an entire team.
- After assembly, mention any agent by name in your Claude Code conversations to activate them.
- Run `/recruiting` again to expand your team as the project evolves.
