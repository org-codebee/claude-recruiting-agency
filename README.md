# Recruiting Agency — Claude Code Plugin

A self-organizing multi-agent team that assembles specialized AI agent teams on demand. Three autonomous agents collaborate to define, evaluate, approve, and persist new Claude Code subagents.

## Installation

### One-Liner (no git clone needed)

```bash
# Install globally (available in all projects)
curl -fsSL https://raw.githubusercontent.com/bheneka/recruiting-agency/main/install.sh | bash -s -- user

# Install into current project
curl -fsSL https://raw.githubusercontent.com/bheneka/recruiting-agency/main/install.sh | bash -s -- project

# Install into a specific project
curl -fsSL https://raw.githubusercontent.com/bheneka/recruiting-agency/main/install.sh | bash -s -- project ~/my-app

# Install both (project + global)
curl -fsSL https://raw.githubusercontent.com/bheneka/recruiting-agency/main/install.sh | bash -s -- both

# Force overwrite without prompts
curl -fsSL https://raw.githubusercontent.com/bheneka/recruiting-agency/main/install.sh | bash -s -- -f user
```

The script downloads all files from GitHub into a temp directory, installs them, and cleans up.

### From Cloned Repo

```bash
git clone https://github.com/bheneka/recruiting-agency.git
cd recruiting-agency

# Interactive — prompts where to install
./install.sh

# Or directly
./install.sh user              # global
./install.sh project ~/my-app  # specific project
./install.sh both              # both
./install.sh -f project        # force overwrite
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

### Environment Variables (optional)

Override the GitHub source for forks or private repos:

```bash
RECRUITING_GITHUB_OWNER=my-org \
RECRUITING_GITHUB_REPO=my-fork \
RECRUITING_GITHUB_BRANCH=develop \
  curl -fsSL https://raw.githubusercontent.com/my-org/my-fork/develop/install.sh | bash -s -- user
```

No dependencies beyond `curl` (or `wget`). No build step.

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
