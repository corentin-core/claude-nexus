#!/usr/bin/env bash
# Claude Code permission profiles
# Source this file in your .bashrc or .zshrc:
#   source ~/projects/claude-nexus/examples/scripts/claude-mode.sh
#
# Usage:
#   claude-mode auto    # autonomous: Edit/Write auto-approved
#   claude-mode safe    # supervised: Edit/Write require approval (default)
#   claude-mode         # show current mode
#
# Toggles write permissions in ~/.claude/settings.json (user-level).
# Requires jq.

_CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Tools toggled by auto/safe — customize this list for your setup
# Add MCP tools (e.g., "mcp__serena__replace_symbol_body") as needed
_WRITE_TOOLS='["Edit", "Write", "NotebookEdit"]'

claude-mode() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required"; return 1
  fi
  if [[ ! -f "$_CLAUDE_SETTINGS" ]]; then
    echo "Error: $_CLAUDE_SETTINGS not found"; return 1
  fi

  case ${1:-} in
    auto)
      local tmp
      tmp=$(jq --argjson tools "$_WRITE_TOOLS" \
        '.permissions.allow = (.permissions.allow - $tools + $tools)' \
        "$_CLAUDE_SETTINGS")
      echo "$tmp" | jq . > "$_CLAUDE_SETTINGS"
      echo "Claude mode: autonomous (Edit/Write auto-approved)"
      echo "Restart Claude Code sessions for changes to take effect."
      ;;
    safe)
      local tmp
      tmp=$(jq --argjson tools "$_WRITE_TOOLS" \
        '.permissions.allow = (.permissions.allow - $tools)' \
        "$_CLAUDE_SETTINGS")
      echo "$tmp" | jq . > "$_CLAUDE_SETTINGS"
      echo "Claude mode: supervised (Edit/Write require approval)"
      echo "Restart Claude Code sessions for changes to take effect."
      ;;
    "")
      if jq -e '.permissions.allow | index("Edit")' "$_CLAUDE_SETTINGS" >/dev/null 2>&1; then
        echo "Current mode: autonomous"
      else
        echo "Current mode: supervised"
      fi
      ;;
    *)
      echo "Usage: claude-mode [auto|safe]"; return 1
      ;;
  esac
}
