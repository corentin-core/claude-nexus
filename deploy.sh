#!/usr/bin/env bash
#
# deploy.sh - Deploy Claude Code configuration to all sibling projects
#
# Symlinks shared rules, commands, skills, and settings into each project's
# .claude/ directory. Idempotent: safe to run multiple times.
#
# Usage: ./deploy.sh [--dry-run]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# ─── Defaults (overridden by config.sh) ──────────────────────────────────────

BASE_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOY_GLOBAL=true
DEPLOY_PARENT_CLAUDE_MD=true
DEPLOY_SETTINGS=true
DEPLOY_MEMORY=false
EXCLUDE_PROJECTS=()

# ─── Load user config ────────────────────────────────────────────────────────

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# ─── Parse arguments ─────────────────────────────────────────────────────────

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE ==="
fi

# ─── Load helpers ─────────────────────────────────────────────────────────────

# shellcheck source=lib/deploy-lib.sh
source "$SCRIPT_DIR/lib/deploy-lib.sh"

# ─── 1. Parent CLAUDE.md ─────────────────────────────────────────────────────

if $DEPLOY_PARENT_CLAUDE_MD && [[ -f "$SCRIPT_DIR/shared/CLAUDE.md" ]]; then
    echo ""
    echo "=== Parent config ($BASE_DIR/) ==="
    safe_link "$SCRIPT_DIR/shared/CLAUDE.md" "$BASE_DIR/CLAUDE.md"
fi

# ─── 2. Per-project config ──────────────────────────────────────────────────

echo ""
echo "=== Per-project config ==="

for target_dir in "$BASE_DIR"/*/; do
    [[ -d "$target_dir" ]] || continue
    target_dir="${target_dir%/}"
    project_name="$(basename "$target_dir")"

    # Skip self and non-git dirs
    [[ "$target_dir" == "$SCRIPT_DIR" ]] && continue
    [[ -d "$target_dir/.git" ]] || continue

    # Skip excluded projects
    if is_excluded "$project_name" "${EXCLUDE_PROJECTS[@]+"${EXCLUDE_PROJECTS[@]}"}"; then
        log "skipping $project_name (excluded)"
        continue
    fi

    echo ""
    action "$project_name"

    ensure_gitignored "$target_dir"

    # Clean stale symlinks
    clean_stale_symlinks "$target_dir/.claude/rules"
    clean_stale_symlinks "$target_dir/.claude/commands"
    clean_stale_skills "$target_dir/.claude/skills"

    # Deploy shared config
    deploy_shared_config "$SCRIPT_DIR/shared" "$target_dir"

    # Deploy project-specific overrides
    deploy_project_overrides "$SCRIPT_DIR/projects/$project_name" "$target_dir"

    # Shared settings.json as fallback (if no project-specific settings)
    if $DEPLOY_SETTINGS; then
        if [[ ! -e "$target_dir/.claude/settings.json" ]] && [[ -f "$SCRIPT_DIR/shared/settings.json" ]]; then
            safe_link "$SCRIPT_DIR/shared/settings.json" "$target_dir/.claude/settings.json"
        fi
    fi

    # Memory deployment
    if $DEPLOY_MEMORY; then
        deploy_memory "$target_dir"
    fi
done

# ─── 3. Global ~/.claude/ config ────────────────────────────────────────────

if $DEPLOY_GLOBAL; then
    echo ""
    echo "=== Global config (~/.claude/) ==="

    # Deploy user-level settings
    if $DEPLOY_SETTINGS && [[ -f "$SCRIPT_DIR/shared/settings.json" ]]; then
        safe_link "$SCRIPT_DIR/shared/settings.json" "$CLAUDE_HOME/settings.json"
    fi

    clean_stale_symlinks "$CLAUDE_HOME/commands"
    clean_stale_symlinks "$CLAUDE_HOME/agents"

    mkdir -p "$CLAUDE_HOME/commands" "$CLAUDE_HOME/agents"
    deploy_dir "$SCRIPT_DIR/global/commands" "$CLAUDE_HOME/commands"
    deploy_dir "$SCRIPT_DIR/global/agents" "$CLAUDE_HOME/agents"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Done ==="
echo "Projects with specific config: $(count_or_zero "$SCRIPT_DIR"/projects/*/)"
echo "Shared rules: $(count_or_zero "$SCRIPT_DIR"/shared/rules/*.md)"
echo "Shared commands: $(count_or_zero "$SCRIPT_DIR"/shared/commands/*.md)"
echo "Shared skills: $(count_or_zero "$SCRIPT_DIR"/shared/skills/*/)"
