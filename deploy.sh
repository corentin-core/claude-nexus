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
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
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

# ─── Helpers ─────────────────────────────────────────────────────────────────

log()    { echo "  $1"; }
action() { echo "→ $1"; }
warn()   { echo "⚠ $1"; }

# Portable readlink -f (works on macOS without coreutils)
resolve_path() {
    local path="$1"
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    elif command -v readlink &>/dev/null && readlink -f "$path" &>/dev/null; then
        readlink -f "$path"
    else
        # Fallback: resolve manually
        local dir file
        dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd)"
        file="$(basename "$path")"
        echo "$dir/$file"
    fi
}

# Create a symlink, removing existing symlink if it points to this repo.
# Never overwrites a real (non-symlink) file.
safe_link() {
    local src="$1"  # source file in claude-nexus
    local dst="$2"  # destination path

    if [[ -L "$dst" ]]; then
        local current_target
        current_target="$(resolve_path "$dst" 2>/dev/null || true)"
        if [[ "$current_target" == "$SCRIPT_DIR"/* ]]; then
            if $DRY_RUN; then
                log "[dry-run] would update symlink: $dst → $src"
            else
                rm "$dst"
                ln -s "$src" "$dst"
                log "updated: $dst"
            fi
        else
            warn "skipping $dst (symlink to external target: $current_target)"
        fi
    elif [[ -e "$dst" ]]; then
        warn "skipping $dst (real file exists)"
    else
        if $DRY_RUN; then
            log "[dry-run] would create symlink: $dst → $src"
        else
            mkdir -p "$(dirname "$dst")"
            ln -s "$src" "$dst"
            log "created: $dst"
        fi
    fi
}

# Remove symlinks in a directory that point to deleted files in this repo
clean_stale_symlinks() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0

    local f
    for f in "$dir"/*; do
        [[ -L "$f" ]] || continue
        local target
        target="$(readlink "$f" 2>/dev/null || true)"
        if [[ "$target" == "$SCRIPT_DIR"/* ]] && [[ ! -e "$target" ]]; then
            if $DRY_RUN; then
                log "[dry-run] would remove stale symlink: $f"
            else
                rm "$f"
                log "removed stale: $f"
            fi
        fi
    done
}

# Ensure .claude/ is in the project's .gitignore
ensure_gitignored() {
    local target_dir="$1"
    local gitignore="$target_dir/.gitignore"

    [[ -d "$target_dir/.git" ]] || return 0

    if [[ -f "$gitignore" ]]; then
        if grep -qxF '.claude/' "$gitignore" 2>/dev/null; then
            return 0
        fi
    fi

    if $DRY_RUN; then
        log "[dry-run] would add .claude/ to $gitignore"
    else
        echo '.claude/' >> "$gitignore"
        log "added .claude/ to $gitignore"
    fi
}

# Deploy all .md files from a source dir as symlinks in a target dir
deploy_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    [[ -d "$src_dir" ]] || return 0

    local f
    for f in "$src_dir"/*.md; do
        [[ -f "$f" ]] || continue
        safe_link "$f" "$dst_dir/$(basename "$f")"
    done
}

# Deploy skills: symlink each skill directory
deploy_skills() {
    local src_dir="$1"
    local dst_dir="$2"

    [[ -d "$src_dir" ]] || return 0
    mkdir -p "$dst_dir"

    local skill_dir
    for skill_dir in "$src_dir"/*/; do
        [[ -d "$skill_dir" ]] || continue
        safe_link "$skill_dir" "$dst_dir/$(basename "$skill_dir")"
    done
}

# Encode a path for Claude's project directory naming convention
# /home/user/projects/foo → -home-user-projects-foo
encode_project_path() {
    echo "${1//\//-}"
}

# Deploy shared memory files into a project's Claude memory directory
deploy_memory() {
    local project_path="$1"
    local encoded
    encoded="$(encode_project_path "$project_path")"
    local memory_dir="$CLAUDE_HOME/projects/$encoded/memory"

    if [[ -d "$SCRIPT_DIR/shared/memory" ]]; then
        mkdir -p "$memory_dir"
        clean_stale_symlinks "$memory_dir"
        deploy_dir "$SCRIPT_DIR/shared/memory" "$memory_dir"
    fi
}

# Check if a project should be excluded
is_excluded() {
    local name="$1"
    local excluded
    for excluded in "${EXCLUDE_PROJECTS[@]+"${EXCLUDE_PROJECTS[@]}"}"; do
        [[ "$name" == "$excluded" ]] && return 0
    done
    return 1
}

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

    # Skip self
    [[ "$target_dir" == "$SCRIPT_DIR" ]] && continue

    # Only deploy to git repos
    [[ -d "$target_dir/.git" ]] || continue

    # Skip excluded projects
    if is_excluded "$project_name"; then
        log "skipping $project_name (excluded)"
        continue
    fi

    echo ""
    action "$project_name"

    ensure_gitignored "$target_dir"

    # Clean stale symlinks
    clean_stale_symlinks "$target_dir/.claude/rules"
    clean_stale_symlinks "$target_dir/.claude/commands"
    clean_stale_symlinks "$target_dir/.claude/skills"

    # Deploy shared config
    mkdir -p "$target_dir/.claude/rules" "$target_dir/.claude/commands"
    deploy_dir "$SCRIPT_DIR/shared/rules" "$target_dir/.claude/rules"
    deploy_dir "$SCRIPT_DIR/shared/commands" "$target_dir/.claude/commands"
    deploy_skills "$SCRIPT_DIR/shared/skills" "$target_dir/.claude/skills"

    # Deploy project-specific overrides
    local_project_dir="$SCRIPT_DIR/projects/$project_name"
    if [[ -d "$local_project_dir" ]]; then
        # Warn about name collisions
        for subdir in rules commands; do
            [[ -d "$local_project_dir/$subdir" ]] || continue
            for f in "$local_project_dir/$subdir"/*.md; do
                [[ -f "$f" ]] || continue
                local_basename="$(basename "$f")"
                if [[ -f "$SCRIPT_DIR/shared/$subdir/$local_basename" ]]; then
                    warn "$project_name/$subdir/$local_basename overrides shared/$subdir/$local_basename"
                fi
            done
        done

        deploy_dir "$local_project_dir/rules" "$target_dir/.claude/rules"
        deploy_dir "$local_project_dir/commands" "$target_dir/.claude/commands"
        deploy_skills "$local_project_dir/skills" "$target_dir/.claude/skills"

        # Project-specific CLAUDE.md
        if [[ -f "$local_project_dir/CLAUDE.md" ]]; then
            safe_link "$local_project_dir/CLAUDE.md" "$target_dir/CLAUDE.md"
        fi

        # Project-specific CLAUDE.local.md
        if [[ -f "$local_project_dir/CLAUDE.local.md" ]]; then
            safe_link "$local_project_dir/CLAUDE.local.md" "$target_dir/CLAUDE.local.md"
        fi

        # Project-specific settings.json
        if [[ -f "$local_project_dir/settings.json" ]]; then
            safe_link "$local_project_dir/settings.json" "$target_dir/.claude/settings.json"
        fi
    fi

    # Shared settings.json as fallback
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

    clean_stale_symlinks "$CLAUDE_HOME/commands"
    clean_stale_symlinks "$CLAUDE_HOME/agents"

    mkdir -p "$CLAUDE_HOME/commands" "$CLAUDE_HOME/agents"
    deploy_dir "$SCRIPT_DIR/global/commands" "$CLAUDE_HOME/commands"
    deploy_dir "$SCRIPT_DIR/global/agents" "$CLAUDE_HOME/agents"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Done ==="

count_or_zero() { find "$@" -maxdepth 0 2>/dev/null | wc -l; }

echo "Projects with specific config: $(count_or_zero "$SCRIPT_DIR"/projects/*/)"
echo "Shared rules: $(count_or_zero "$SCRIPT_DIR"/shared/rules/*.md)"
echo "Shared commands: $(count_or_zero "$SCRIPT_DIR"/shared/commands/*.md)"
echo "Shared skills: $(count_or_zero "$SCRIPT_DIR"/shared/skills/*/)"
