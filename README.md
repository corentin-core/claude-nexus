# claude-nexus

Centralized [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration
for multi-repo setups. One repo to manage rules, commands, skills, and agents — deployed
via symlinks to all your projects.

## Why?

Claude Code loads rules, commands, and skills from each project's `.claude/` directory,
but these don't inherit across projects. If you work on multiple repos, you end up
copy-pasting the same config everywhere.

In a team, everyone also has their own Claude Code preferences — but you don't want to
commit personal config into each project's repo. claude-nexus keeps your config separate,
centralized, and out of your projects' git history.

**claude-nexus** solves this by keeping all your Claude Code configuration in a single
repo and deploying it via symlinks. Change a rule once, run `deploy.sh`, and every
project gets the update.

## How it works

```
workspace/                  ← any directory
├── claude-nexus/           ← this repo (must be a sibling)
├── my-api/                 ← your projects
├── my-frontend/
└── my-cli/
```

`deploy.sh` scans sibling directories for git repos and symlinks your shared config
into each one's `.claude/` directory.

| Source in claude-nexus | Deployed to |
|---|---|
| `shared/CLAUDE.md` | `workspace/CLAUDE.md` (parent inheritance) |
| `shared/rules/*.md` | `project/.claude/rules/` |
| `shared/commands/*.md` | `project/.claude/commands/` |
| `shared/skills/<name>/` | `project/.claude/skills/` |
| `shared/settings.json` | `~/.claude/settings.json` + `project/.claude/settings.json` (fallback) |
| `projects/<name>/rules/*.md` | `<name>/.claude/rules/` (override) |
| `projects/<name>/CLAUDE.md` | `<name>/CLAUDE.md` |
| `global/commands/*.md` | `~/.claude/commands/` |
| `global/agents/*.md` | `~/.claude/agents/` |

## Quick start

```bash
# 1. Clone alongside your projects
cd ~/projects
git clone https://github.com/YOUR_USER/claude-nexus.git

# 2. Configure (optional — defaults work if claude-nexus is a sibling)
cd claude-nexus
cp config.example.sh config.sh
# Edit config.sh if your projects aren't in the parent directory

# 3. Deploy
./deploy.sh
```

Run `./deploy.sh --dry-run` to preview changes without touching anything.

## Directory structure

```
claude-nexus/
├── deploy.sh                    # Deployment script (idempotent)
├── config.example.sh            # Configuration template
├── lib/
│   └── deploy-lib.sh            # Shared helper functions (reusable by submodule consumers)
│
├── shared/                      # Deployed to ALL sibling projects
│   ├── CLAUDE.md                # Shared context (parent directory inheritance)
│   ├── settings.json            # Shared Claude Code settings (user-level + project fallback)
│   ├── rules/*.md               # → each project's .claude/rules/
│   ├── commands/*.md            # → each project's .claude/commands/
│   └── skills/<name>/SKILL.md   # → each project's .claude/skills/
│
├── projects/<name>/             # Project-specific (overrides shared)
│   ├── CLAUDE.md                # Project context
│   ├── CLAUDE.local.md          # Local/private context (gitignored)
│   ├── settings.json            # Project-specific settings
│   ├── rules/*.md
│   ├── commands/*.md
│   └── skills/<name>/SKILL.md
│
├── global/                      # Deployed to ~/.claude/ (all projects)
│   ├── commands/*.md            # Global slash commands
│   └── agents/*.md              # Custom subagents
│
└── examples/                    # Library of ready-to-use examples
    ├── rules/                   # Battle-tested rules
    ├── skills/                  # Workflow skills
    ├── commands/                # Interactive commands
    ├── agents/                  # Specialized subagents
    └── scripts/
        ├── claude-mode.sh       # Toggle auto/supervised permission profiles
        └── setup-worktree-config.sh  # Replicate .claude/ config into git worktrees
```

## Configuration

Copy `config.example.sh` to `config.sh` and customize:

| Variable | Default | Description |
|---|---|---|
| `BASE_DIR` | Parent of claude-nexus | Directory containing your projects |
| `DEPLOY_GLOBAL` | `true` | Deploy to `~/.claude/` |
| `DEPLOY_PARENT_CLAUDE_MD` | `true` | Symlink `shared/CLAUDE.md` to `$BASE_DIR/` |
| `DEPLOY_SETTINGS` | `true` | Deploy `settings.json` to projects |
| `DEPLOY_MEMORY` | `false` | Deploy memory files to Claude's project dirs |
| `EXCLUDE_PROJECTS` | `()` | Array of directory names to skip |

## Usage

### Add a shared rule

```bash
cat > shared/rules/no-console-log.md << 'EOF'
## No console.log in production code

**Why**: Console statements clutter production logs.

**Rule**: ALWAYS remove `console.log` before committing.
EOF

./deploy.sh
```

The rule is now active in every project.

### Add a project-specific override

```bash
mkdir -p projects/my-api/rules
cat > projects/my-api/rules/api-conventions.md << 'EOF'
## API Conventions

**Rule**: ALWAYS return proper HTTP status codes (not just 200).
EOF

./deploy.sh
```

This rule only applies to `my-api`.

### Override a shared file

Create a file with **the same name** in `projects/<name>/`. The project-specific
version takes precedence (deploy will print a warning so you know it's intentional).

### Writing conventions

**Rules** follow: **Why** (bullets) → **Rule** (ALWAYS/NEVER) → **Examples** (code).

**Commands** include `$ARGUMENTS` for user input.

**Skills** are directories with a `SKILL.md` containing YAML frontmatter:

```yaml
---
name: my-skill
description: What this skill does
---
```

## Deploy behavior

- **Auto-discovery**: deploys to all sibling git repos automatically
- **Idempotent**: safe to run multiple times
- **Non-destructive**: never overwrites real (non-symlink) files
- **Self-cleaning**: removes stale symlinks when source files are deleted
- **Auto-gitignore**: adds `.claude/` to each project's `.gitignore`
- **macOS compatible**: no GNU coreutils required

## Example library

The `examples/` directory contains a curated library of production-tested configurations.
Copy anything you like into `shared/` (or `global/`) and run `deploy.sh`.

### Rules

| Rule | What it does |
|---|---|
| `auto-introspection` | Self-improvement loop: Claude proposes config updates when corrected |
| `implementation-workflow` | Enforces design-before-code with user checkpoints |
| `lint-disables` | Hard checkpoint: never suppress lint without user approval |
| `python-quality` | Python conventions: type hints, immutability, encapsulation |
| `documentation` | Doc guidelines: diagrams over text, responsibilities over methods |
| `design-mockups` | ASCII art mockups required for UI features |
| `testing` | Two-tier testing strategy, validate behavior not existence |
| `pr-review` | PR review guardrails (no drive-by issues, fix in-PR problems) |
| `resource-management` | Prevent machine exhaustion from parallel heavy tasks |
| `ci-validation` | Validate CI syntax before pushing, analyze failures correctly |
| `incident-investigation` | Investigation framework: frame problems, verify before posting |
| `api-correctness` | Verify API response structure before parsing |
| `learning-mode` | Inverted mode: Claude teaches, user implements (for learning projects) |

### Skills

| Skill | What it does |
|---|---|
| `implement` | Full 6-phase implementation workflow with checkpoints |
| `review` | Thorough PR review: CI, coverage, design compliance, inline comments |
| `create-pr` | Structured PR creation with conventional commits and issue linking |
| `create-issue` | Issue creation (feature or bug) with templates and labels |
| `refactor-check` | Code quality analysis: encapsulation, validations, test quality |
| `update-config` | Edit config from any project: modify, deploy, commit, push (global skill) |
| `orchestrate` | Multi-repo task coordinator using `claude -p` workers in worktrees |
| `handoff` | Send files/messages between Claude instances via shared filesystem |
| `check-handoffs` | Receive and process cross-repo messages |

### Commands

| Command | What it does |
|---|---|
| `handle-pr-comments` | Address review comments one-by-one with user validation |
| `trace-change` | Trace a code change: commit → PR → issue → affected versions |
| `discovery` | Technical investigation with evidence-based findings and estimates |

### Agents

| Agent | What it does |
|---|---|
| `code-reviewer` | Multi-language code reviewer (security, quality, performance) |
| `python-pro` | Expert Python developer with type safety and async patterns |

### Scripts

| Script | What it does |
|---|---|
| `claude-mode.sh` | Shell function to toggle auto/supervised permission profiles |
| `setup-worktree-config.sh` | Replicate `.claude/` config into git worktrees (used by orchestrate) |

## Use as a submodule

claude-nexus can also serve as a **framework** for your own config repo. Add it as a
submodule to reuse `lib/deploy-lib.sh` while keeping your own content:

```bash
# In your config repo
git submodule add https://github.com/YOUR_USER/claude-nexus.git base

# Your deploy.sh sources the shared helpers
cat > deploy.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

source "$SCRIPT_DIR/base/lib/deploy-lib.sh"

# Use helpers: safe_link, deploy_shared_config, deploy_project_overrides, etc.
# Add your own deploy logic on top
SCRIPT
```

This lets you maintain your own rules and skills while benefiting from deploy tooling
updates upstream.

## Contributing

1. Fork and clone
2. Make your changes
3. Run `shellcheck -x deploy.sh` and `bats tests/`
4. Open a PR

## License

MIT
