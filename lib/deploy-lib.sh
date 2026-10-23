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

# ─── Rule hardlinks ──────────────────────────────────────────────────────────

# Claude Code skips a rule file that is a symlink to outside the project, so
# rules are hardlinked. A hardlink does not name its source, so the manifest
# records each one as "dst<TAB>src", which tells a deployed rule from a real one.
RULES_MANIFEST="${RULES_MANIFEST:-$SCRIPT_DIR/.deployed-rules}"

manifest_src() {
    [[ -f "$RULES_MANIFEST" ]] || return 0
    awk -F'\t' -v dst="$1" '$1 == dst { print $2; exit }' "$RULES_MANIFEST"
}

manifest_set() {
    local dst="$1" src="$2"
    [[ "$(manifest_src "$dst")" == "$src" ]] && return 0
    manifest_del "$dst"
    printf '%s\t%s\n' "$dst" "$src" >> "$RULES_MANIFEST"
}

manifest_del() {
    [[ -f "$RULES_MANIFEST" ]] || return 0
    local tmp
    tmp="$(mktemp "$RULES_MANIFEST.XXXXXX")"
    awk -F'\t' -v dst="$1" '$1 != dst' "$RULES_MANIFEST" > "$tmp"
    mv "$tmp" "$RULES_MANIFEST"
}

# A hardlink needs one filesystem; a copy is the fallback across two. -L links
# the target of a symlinked source, whose relative path would break in a project.
hardlink_or_copy() {
    ln -fL "$1" "$2" 2>/dev/null || cp -fL "$1" "$2"
}

# Hardlink a rule, replacing a symlink into SCRIPT_DIR or a rule the manifest
# lists. Never overwrites a real file.
safe_hardlink() {
    local src="$1"
    local dst="$2"

    if [[ -L "$dst" ]]; then
        local current_target
        current_target="$(resolve_path "$dst" 2>/dev/null || true)"
        if [[ "$current_target" != "$SCRIPT_DIR"/* ]]; then
            warn "skipping $dst (symlink to external target: $current_target)"
            return 0
        fi
    elif [[ -e "$dst" ]]; then
        if [[ "$dst" -ef "$src" ]]; then
            $DRY_RUN || manifest_set "$dst" "$src"
            return 0
        fi
        if [[ -z "$(manifest_src "$dst")" ]]; then
            warn "skipping $dst (real file exists)"
            return 0
        fi
    fi

    if $DRY_RUN; then
        log "[dry-run] would hardlink: $dst → $src"
    else
        mkdir -p "$(dirname "$dst")"
        rm -f "$dst"
        hardlink_or_copy "$src" "$dst"
        manifest_set "$dst" "$src"
        log "hardlinked: $dst"
    fi
}

# Remove the rules of a directory whose source was deleted
clean_stale_hardlinks() {
    local dir="$1"
    [[ -f "$RULES_MANIFEST" ]] || return 0

    local dst src
    while IFS=$'\t' read -r dst src; do
        [[ "$(dirname "$dst")" == "$dir" ]] || continue
        [[ -e "$src" ]] && continue
        if $DRY_RUN; then
            log "[dry-run] would remove stale rule: $dst"
        else
            rm -f "$dst"
            manifest_del "$dst"
            log "removed stale: $dst"
        fi
    done < <(cat "$RULES_MANIFEST")
}

# Re-link every rule of the manifest whose hardlink a git checkout broke: git
# replaces a file it rewrites, and the deployed copy keeps the old inode.
relink_rules() {
    [[ -f "$RULES_MANIFEST" ]] || return 0

    local dst src
    while IFS=$'\t' read -r dst src; do
        if [[ ! -e "$src" ]]; then
            rm -f "$dst"
            manifest_del "$dst"
            log "removed stale: $dst"
        elif [[ -d "$(dirname "$dst")" ]] && [[ ! "$dst" -ef "$src" ]]; then
            rm -f "$dst"
            hardlink_or_copy "$src" "$dst"
            log "relinked: $dst"
        fi
    done < <(cat "$RULES_MANIFEST")
}

# Install git hooks that run `deploy.sh --relink` after a pull, a checkout or a
# rebase of the config repo. A hook of your own is left alone.
install_relink_hooks() {
    local hooks_dir hook path
    hooks_dir="$(git -C "$SCRIPT_DIR" rev-parse --git-path hooks 2>/dev/null)" || return 0
    [[ "$hooks_dir" == /* ]] || hooks_dir="$SCRIPT_DIR/$hooks_dir"

    for hook in post-merge post-checkout post-rewrite; do
        path="$hooks_dir/$hook"
        if [[ -e "$path" ]] && ! grep -q 'deploy.sh --relink' "$path"; then
            warn "skipping $path (hook of your own: add '\"$SCRIPT_DIR/deploy.sh\" --relink' to it)"
            continue
        fi
        if $DRY_RUN; then
            log "[dry-run] would install: $path"
            continue
        fi
        mkdir -p "$hooks_dir"
        printf '#!/bin/sh\n"%s/deploy.sh" --relink > /dev/null || true\n' "$SCRIPT_DIR" > "$path"
        chmod +x "$path"
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

# Deploy all .md files from a source dir as hardlinks in a rules dir
deploy_rules_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    [[ -d "$src_dir" ]] || return 0

    local f
    for f in "$src_dir"/*.md; do
        [[ -f "$f" ]] || continue
        safe_hardlink "$f" "$dst_dir/$(basename "$f")"
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

    # Ensure MEMORY.md indexes all shared memory files (skip MEMORY.md itself)
    local memory_index="$memory_dir/MEMORY.md"
    if [[ ! -f "$memory_index" ]]; then
        # Create seed MEMORY.md
        if $DRY_RUN; then
            log "[dry-run] would create: $memory_index"
        else
            printf '# Memory Index\n\n## Shared\n\n' > "$memory_index"
            log "created: $memory_index"
        fi
    fi

    # Prune stale index entries. deploy writes "- [name.md](name.md) — …"; an
    # entry is stale when its link target (a bare filename) no longer has a file
    # or symlink in memory_dir (clean_stale_symlinks above already dropped the
    # symlink for a deleted shared memory). Only deploy-style entries — where the
    # link text equals the target — are touched, so hand-written or local-memory
    # entries (whose text differs from the filename) are left alone.
    if [[ -f "$memory_index" ]]; then
        local entry_re='^- \[([^]]+)\]\(([^)]+)\)'
        local line text link
        if $DRY_RUN; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                [[ $line =~ $entry_re ]] || continue
                text="${BASH_REMATCH[1]}"; link="${BASH_REMATCH[2]}"
                if [[ "$text" == "$link" && "$link" != */* && ! -e "$memory_dir/$link" ]]; then
                    log "[dry-run] would prune stale MEMORY.md entry: $link"
                fi
            done < "$memory_index"
        else
            local tmp_index="$memory_index.tmp" pruned=0
            : > "$tmp_index"
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ $line =~ $entry_re ]]; then
                    text="${BASH_REMATCH[1]}"; link="${BASH_REMATCH[2]}"
                    if [[ "$text" == "$link" && "$link" != */* && ! -e "$memory_dir/$link" ]]; then
                        log "pruned stale MEMORY.md entry: $link"
                        pruned=1
                        continue
                    fi
                fi
                printf '%s\n' "$line" >> "$tmp_index"
            done < "$memory_index"
            if [[ "$pruned" -eq 1 ]]; then
                mv "$tmp_index" "$memory_index"
            else
                rm -f "$tmp_index"
            fi
        fi
    fi

    # Upsert shared entries. The index hook is what decides whether a memory gets
    # opened at all, so a drifting description has to reach the already-indexed
    # projects too, not just the next new one.
    #
    # Identity is decided by the exact prefix this function writes, never by
    # re-parsing the line: a file name holding a "]" or a ")" defeats any
    # bracket-matching regex, and the entry would then be appended again on every
    # single deploy. Two arrays rather than one associative array, so the floor
    # stays at bash 3.2 (macOS).
    local names=() hooks=() f name description
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        name="$(basename "$f")"
        [[ "$name" == "MEMORY.md" ]] && continue

        # Extract description from frontmatter if available
        description="$(sed -n '/^---$/,/^---$/{ /^description:/{ s/^description: *//; p; q; } }' "$f")"
        names+=("$name")
        hooks+=("- [$name]($name) — ${description:-shared memory}")
    done < <(printf '%s\n' "$memory_src"/*.md | LC_ALL=C sort)
    [[ "${#names[@]}" -gt 0 ]] || return 0

    local i n line hook new_index="" refreshed=() appended=() linked=""
    if [[ -f "$memory_index" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            for i in "${!names[@]}"; do
                n="${names[$i]}"; hook="${hooks[$i]}"
                # Deploy-style entry: exactly what this function writes, so a hook
                # the author reworded into their own wording is left alone.
                if [[ "$line" == "- [$n]($n) — "* ]]; then
                    linked+=" $n"
                    if [[ "$line" != "$hook" ]]; then
                        line="$hook"
                        refreshed+=("$n")
                    fi
                    break
                fi
                # Any other entry pointing at the same file still counts as indexed,
                # so we never stack a second hook next to a hand-written one.
                if [[ "$line" == *"]($n)"* ]]; then
                    linked+=" $n"
                    break
                fi
            done
            new_index+="$line"$'\n'
        done < "$memory_index"
    fi

    for i in "${!names[@]}"; do
        n="${names[$i]}"
        [[ "$linked" == *" $n"* ]] && continue
        new_index+="${hooks[$i]}"$'\n'
        appended+=("$n")
    done

    [[ "${#refreshed[@]}" -eq 0 && "${#appended[@]}" -eq 0 ]] && return 0

    for n in ${refreshed[@]+"${refreshed[@]}"}; do
        if $DRY_RUN; then
            log "[dry-run] would refresh: $n description in MEMORY.md"
        else
            log "refreshed: $n description in MEMORY.md"
        fi
    done
    for n in ${appended[@]+"${appended[@]}"}; do
        if $DRY_RUN; then
            log "[dry-run] would add $n to MEMORY.md"
        else
            log "indexed: $n in MEMORY.md"
        fi
    done

    # Write through the existing path: no temp file to clobber, and a MEMORY.md
    # that is a symlink or is mode-protected keeps its inode and its mode.
    $DRY_RUN || printf '%s' "$new_index" > "$memory_index"
}

# Deploy shared config (rules, commands, skills) to a target project directory
# Supports layered deployment: call multiple times with different source dirs
deploy_shared_config() {
    local src_dir="$1"
    local target_dir="$2"

    [[ -d "$src_dir" ]] || return 0

    mkdir -p "$target_dir/.claude/rules" "$target_dir/.claude/commands"
    deploy_rules_dir "$src_dir/rules" "$target_dir/.claude/rules"
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

    deploy_rules_dir "$project_config_dir/rules" "$target_dir/.claude/rules"
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
