#!/usr/bin/env bash
# claude-nexus configuration
#
# Copy this file to config.sh and customize.
# config.sh is gitignored — it won't be committed.

# ─── Required ────────────────────────────────────────────────────────────────

# Base directory containing all your projects.
# claude-nexus must be a subdirectory (sibling of the target projects).
# Default: parent directory of claude-nexus (auto-detected)
# BASE_DIR="$HOME/projects"

# ─── Optional features ───────────────────────────────────────────────────────

# Deploy global commands and agents to ~/.claude/ (available in all projects)
# DEPLOY_GLOBAL=true

# Deploy shared/CLAUDE.md as $BASE_DIR/CLAUDE.md (parent directory inheritance)
# DEPLOY_PARENT_CLAUDE_MD=true

# Deploy shared settings.json to each project's .claude/settings.json
# DEPLOY_SETTINGS=true

# Deploy shared/memory/*.md into Claude's per-project memory directories
# Requires Claude Code to have created ~/.claude/projects/ entries first
# DEPLOY_MEMORY=false

# ─── Exclusions ──────────────────────────────────────────────────────────────

# Directories to skip during deployment (in addition to claude-nexus itself)
# EXCLUDE_PROJECTS=("archived-project" "node_modules")
