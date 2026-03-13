#!/usr/bin/env bash
#
# setup-worktree-config.sh - Replicate Claude Code config into a git worktree
#
# Usage: setup-worktree-config.sh <main-repo> <worktree-path>
#
# When claude-nexus deploys config via symlinks into a project's .claude/ directory,
# those files are gitignored and won't appear in git worktrees. This script recreates
# them so that Claude Code instances running in worktrees get the same rules, commands,
# skills, and settings as the main repo.
#
# All symlinks created by deploy.sh use absolute paths, so they work as-is in worktrees.
#
set -euo pipefail

usage() {
    echo "Usage: $0 <main-repo> <worktree-path>"
    echo ""
    echo "Replicate Claude Code config (.claude/, CLAUDE.md, etc.) into a git worktree."
    echo ""
    echo "Arguments:"
    echo "  main-repo      Path to the main git repository"
    echo "  worktree-path  Path to the worktree to configure"
    exit 1
}

[[ $# -lt 2 ]] && usage

MAIN_REPO="$(cd "$1" && pwd)"
WORKTREE="$(cd "$2" && pwd)"

if [[ ! -d "$MAIN_REPO/.git" ]]; then
    echo "ERROR: $MAIN_REPO is not a git repository"
    exit 1
fi

if [[ ! -d "$WORKTREE" ]]; then
    echo "ERROR: $WORKTREE does not exist"
    exit 1
fi

# --- Replicate .claude/ directory ---

if [[ -d "$MAIN_REPO/.claude" ]]; then
    echo "Setting up .claude/ in worktree..."

    # Iterate over subdirectories (rules, commands, skills, agents, etc.)
    for subdir in "$MAIN_REPO/.claude"/*/; do
        [[ -d "$subdir" ]] || continue
        dirname="$(basename "$subdir")"

        # Skip worktrees subdir (not relevant for worktree config)
        [[ "$dirname" == "worktrees" ]] && continue

        if [[ -L "${subdir%/}" ]]; then
            # Whole directory is a symlink — copy it as-is
            target="$(readlink "${subdir%/}")"
            mkdir -p "$WORKTREE/.claude"
            ln -sf "$target" "$WORKTREE/.claude/$dirname"
            echo "  Linked .claude/$dirname -> $target"
        else
            # Regular directory containing symlinks and/or real files
            mkdir -p "$WORKTREE/.claude/$dirname"
            for entry in "$subdir"*; do
                [[ -e "$entry" ]] || continue
                name="$(basename "$entry")"

                if [[ -L "$entry" ]]; then
                    # Copy symlink as-is (absolute target works in worktree)
                    target="$(readlink "$entry")"
                    ln -sf "$target" "$WORKTREE/.claude/$dirname/$name"
                else
                    # Real file — symlink to the main repo's copy
                    ln -sf "$entry" "$WORKTREE/.claude/$dirname/$name"
                fi
            done
            echo "  Replicated .claude/$dirname/"
        fi
    done

    # Handle files directly in .claude/ (settings.json, settings.local.json, etc.)
    for file in "$MAIN_REPO/.claude"/*; do
        [[ -f "$file" ]] || [[ -L "$file" && ! -d "$file" ]] || continue
        name="$(basename "$file")"
        mkdir -p "$WORKTREE/.claude"

        if [[ -L "$file" ]]; then
            target="$(readlink "$file")"
            ln -sf "$target" "$WORKTREE/.claude/$name"
        else
            ln -sf "$file" "$WORKTREE/.claude/$name"
        fi
        echo "  Linked .claude/$name"
    done
fi

# --- Replicate root-level CLAUDE.md and CLAUDE.local.md ---

for md_file in CLAUDE.md CLAUDE.local.md; do
    src="$MAIN_REPO/$md_file"
    dst="$WORKTREE/$md_file"

    # Skip if already exists in worktree (e.g. tracked by git)
    [[ -e "$dst" ]] && continue

    if [[ -L "$src" ]]; then
        # Symlink from deploy.sh — copy the symlink
        target="$(readlink "$src")"
        ln -sf "$target" "$dst"
        echo "Linked $md_file -> $target"
    elif [[ -f "$src" ]]; then
        # Real file — symlink to main repo's copy
        ln -sf "$src" "$dst"
        echo "Linked $md_file -> $src"
    fi
done

echo "Done — worktree config ready at $WORKTREE"
