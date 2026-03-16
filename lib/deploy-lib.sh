#!/usr/bin/env bash
#
# deploy-lib.sh - Shared helper functions for Claude Code config deployment
#
# Source this file from your deploy.sh:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/base/lib/deploy-lib.sh"  # or ./lib/deploy-lib.sh
#
# Required variables (set before sourcing):
#   SCRIPT_DIR  - Root of YOUR config repo (not the lib's location)
#   DRY_RUN     - "true" or "false"
#
# Optional variables:
#   CLAUDE_HOME - Default: $HOME/.claude
#

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# ─── Logging ──────────────────────────────────────────────────────────────────

log()    { echo "  $1"; }
action() { echo "→ $1"; }
warn()   { echo "⚠ $1"; }

# ─── Path resolution ─────────────────────────────────────────────────────────

# Portable readlink -f (works on macOS without coreutils)
resolve_path() {
    local path="$1"
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    elif command -v readlink &>/dev/null && readlink -f "$path" &>/dev/null; then
        readlink -f "$path"
    else
        local dir file
        dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd)"
        file="$(basename "$path")"
        echo "$dir/$file"
    fi
}

# ─── Symlink management ──────────────────────────────────────────────────────

# Create a symlink, removing existing symlink if it points to SCRIPT_DIR.
# Never overwrites a real (non-symlink) file.
safe_link() {
    local src="$1"
    local dst="$2"

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

# Remove symlinks in a directory that point to deleted files in SCRIPT_DIR
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

# ─── Git integration ─────────────────────────────────────────────────────────

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

# ─── Deployment helpers ───────────────────────────────────────────────────────

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

# Clean stale skill directory symlinks
clean_stale_skills() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0

    local entry
    for entry in "$dir"/*; do
        [[ -L "$entry" ]] || continue
        local target
        target="$(readlink "$entry" 2>/dev/null || true)"
        if [[ "$target" == "$SCRIPT_DIR"/* ]] && [[ ! -e "$target" ]]; then
            if $DRY_RUN; then
                log "[dry-run] would remove stale symlink: $entry"
            else
                rm "$entry"
                log "removed stale: $entry"
            fi
        fi
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
    local memory_src="${2:-$SCRIPT_DIR/shared/memory}"

    [[ -d "$memory_src" ]] || return 0

    local encoded
    encoded="$(encode_project_path "$project_path")"
    local memory_dir="$CLAUDE_HOME/projects/$encoded/memory"

    mkdir -p "$memory_dir"
    clean_stale_symlinks "$memory_dir"
    deploy_dir "$memory_src" "$memory_dir"
}

# Deploy shared config (rules, commands, skills) to a target project directory
# Supports layered deployment: call multiple times with different source dirs
deploy_shared_config() {
    local src_dir="$1"
    local target_dir="$2"

    [[ -d "$src_dir" ]] || return 0

    mkdir -p "$target_dir/.claude/rules" "$target_dir/.claude/commands"
    deploy_dir "$src_dir/rules" "$target_dir/.claude/rules"
    deploy_dir "$src_dir/commands" "$target_dir/.claude/commands"
    deploy_skills "$src_dir/skills" "$target_dir/.claude/skills"
}

# Deploy project-specific overrides (rules, commands, skills, CLAUDE.md, settings)
deploy_project_overrides() {
    local project_config_dir="$1"  # e.g., SCRIPT_DIR/projects/<name>
    local target_dir="$2"
    local shared_dir="${3:-$SCRIPT_DIR/shared}"  # for collision warnings

    [[ -d "$project_config_dir" ]] || return 0

    local project_name
    project_name="$(basename "$project_config_dir")"

    # Warn about name collisions
    for subdir in rules commands; do
        [[ -d "$project_config_dir/$subdir" ]] || continue
        for f in "$project_config_dir/$subdir"/*.md; do
            [[ -f "$f" ]] || continue
            local local_basename
            local_basename="$(basename "$f")"
            if [[ -f "$shared_dir/$subdir/$local_basename" ]]; then
                warn "$project_name/$subdir/$local_basename overrides shared/$subdir/$local_basename"
            fi
        done
    done

    deploy_dir "$project_config_dir/rules" "$target_dir/.claude/rules"
    deploy_dir "$project_config_dir/commands" "$target_dir/.claude/commands"
    deploy_skills "$project_config_dir/skills" "$target_dir/.claude/skills"

    # Project-specific CLAUDE.md and CLAUDE.local.md
    if [[ -f "$project_config_dir/CLAUDE.md" ]]; then
        safe_link "$project_config_dir/CLAUDE.md" "$target_dir/CLAUDE.md"
    fi
    if [[ -f "$project_config_dir/CLAUDE.local.md" ]]; then
        safe_link "$project_config_dir/CLAUDE.local.md" "$target_dir/CLAUDE.local.md"
    fi

    # Project-specific settings.json
    if [[ -f "$project_config_dir/settings.json" ]]; then
        safe_link "$project_config_dir/settings.json" "$target_dir/.claude/settings.json"
    fi
}

# Check if a project should be excluded
is_excluded() {
    local name="$1"
    shift
    local excluded
    for excluded in "$@"; do
        [[ "$name" == "$excluded" ]] && return 0
    done
    return 1
}

# ─── Counting helper ─────────────────────────────────────────────────────────

count_or_zero() { find "$@" -maxdepth 0 2>/dev/null | wc -l; }
