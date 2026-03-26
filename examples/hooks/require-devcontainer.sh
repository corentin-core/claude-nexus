#!/usr/bin/env bash
#
# Claude Code PreToolUse hook: block git commit when a devcontainer is configured
# but we're not running inside a container.
#
# Receives JSON on stdin with tool_input.command. If the command is a git commit
# and .devcontainer/devcontainer.json exists in the repo, blocks execution with
# a reminder to use the devcontainer.
#
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on git commit commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+(commit|add\s.*&&\s*git\s+commit)'; then
    exit 0
fi

# Check if a devcontainer is configured in the repo
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO_ROOT" ]] || [[ ! -f "$REPO_ROOT/.devcontainer/devcontainer.json" ]]; then
    exit 0
fi

# Check if we're already inside a container
if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
    exit 0
fi

# Block the commit
echo '{"decision": "block", "reason": "This project has a devcontainer. Run commits inside the devcontainer (docker exec) to ensure pre-commit hooks use the correct environment. See .claude/rules/devcontainer.md."}'
