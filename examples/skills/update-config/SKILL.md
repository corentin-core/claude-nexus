---
name: update-config
description:
  Add, modify, or remove a Claude Code configuration file (rule, command, skill, or
  CLAUDE.md) in the central config repo, then deploy and push. Designed to be installed
  as a global skill so it's available from any project.
---

# Update Claude Config

Add, modify, or remove a Claude Code configuration file in the central config repo,
then deploy and push.

## Arguments

`$ARGUMENTS` — describe what to add/modify/remove. Examples:
- "add a rule about never using print() in production code"
- "modify shared commit skill to include scope"
- "remove the testing rule"
- "add a project-specific command for my-api"

## Instructions

### Step 1: Find the config repo

The config repo is a sibling of the current project. Resolve its path:

```bash
# Adjust the directory name to match your config repo
CLAUDE_CONFIG="$(dirname "$(pwd)")/claude-nexus"
```

If the config repo isn't found, ask the user for the path.

All paths below are relative to `$CLAUDE_CONFIG`.

### Step 2: Determine the target location

```
Shared across all projects?
  YES → shared/rules/ or shared/commands/ or shared/skills/ or shared/CLAUDE.md
  NO  → projects/<project>/rules/ or projects/<project>/commands/

Global (~/.claude/)?
  YES → global/commands/ or global/agents/
```

### Step 3: Check if the file already exists

```bash
ls "$CLAUDE_CONFIG"/shared/rules/
ls "$CLAUDE_CONFIG"/shared/commands/
ls "$CLAUDE_CONFIG"/shared/skills/
ls "$CLAUDE_CONFIG"/projects/*/rules/
ls "$CLAUDE_CONFIG"/projects/*/commands/
```

### Step 4: Create or edit the file

Edit the file in `$CLAUDE_CONFIG` (NEVER edit symlinks in project dirs).

If creating a new project directory:

```bash
mkdir -p "$CLAUDE_CONFIG"/projects/<project>/{rules,commands}
```

Follow the writing conventions:

- **Rules**: Why (bullets) → Rule (ALWAYS/NEVER) → Examples (code)
- **Commands**: Include `$ARGUMENTS` placeholder for user input
- **Skills**: Directory with `SKILL.md` containing YAML frontmatter

### Step 5: Deploy

```bash
"$CLAUDE_CONFIG"/deploy.sh
```

Run with `--dry-run` first to preview changes if unsure.

### Step 6: Commit and push

```bash
cd "$CLAUDE_CONFIG"
git add -A
git commit -m "type: description"
git push
```

Use conventional commits: `feat:` (new rule/command/skill), `fix:` (correction),
`refactor:` (reorganization), `docs:` (README, comments).

## Tips

- Run `deploy.sh --dry-run` first to preview changes
- Project-specific files override shared files with the same name
- After adding a new project, deploy creates the `.claude/` directory and gitignores it

$ARGUMENTS
