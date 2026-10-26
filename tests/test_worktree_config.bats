#!/usr/bin/env bats

load test_helper/setup

# A worktree inside project-a, where Claude Code puts its own.
setup_worktree() {
    mkdir -p "$CLAUDE_CONFIG_DIR/examples/scripts"
    cp "$BATS_TEST_DIRNAME/../examples/scripts/setup-worktree-config.sh" "$CLAUDE_CONFIG_DIR/examples/scripts/"
    MAIN_REPO="$TEST_WORKSPACE/project-a"
    WORKTREE="$MAIN_REPO/.claude/worktrees/wt"
    mkdir -p "$WORKTREE"
    "$CLAUDE_CONFIG_DIR/deploy.sh" > /dev/null
}

setup_worktree_config() {
    "$CLAUDE_CONFIG_DIR/examples/scripts/setup-worktree-config.sh" "$MAIN_REPO" "$WORKTREE"
}

@test "hardlinks a worktree rule to its source, and --relink keeps it" {
    setup_worktree
    run setup_worktree_config
    [ "$status" -eq 0 ]
    [ ! -L "$WORKTREE/.claude/rules/testing.md" ]
    [ "$WORKTREE/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
    rm "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    echo "# Testing rule, v2" > "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    "$CLAUDE_CONFIG_DIR/deploy.sh" --relink
    [ "$WORKTREE/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
}

@test "hardlinks the main repo's own rule" {
    setup_worktree
    echo "# Local rule" > "$MAIN_REPO/.claude/rules/local.md"
    run setup_worktree_config
    [ "$status" -eq 0 ]
    [ "$WORKTREE/.claude/rules/local.md" -ef "$MAIN_REPO/.claude/rules/local.md" ]
    grep -q "^$WORKTREE/.claude/rules/local.md" "$CLAUDE_CONFIG_DIR/.deployed-rules"
}

@test "a re-run replaces a whole .claude symlinked to the main repo's" {
    setup_worktree
    rmdir "$WORKTREE"
    mkdir -p "$TEST_WORKSPACE/wt"
    WORKTREE="$TEST_WORKSPACE/wt"
    ln -s "$MAIN_REPO/.claude" "$WORKTREE/.claude"
    run setup_worktree_config
    [ "$status" -eq 0 ]
    [ ! -L "$WORKTREE/.claude" ]
    [ "$WORKTREE/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
}

@test "a re-run leaves no link inside a symlinked skill" {
    setup_worktree
    setup_worktree_config
    run setup_worktree_config
    [ "$status" -eq 0 ]
    [ -L "$WORKTREE/.claude/skills/commit" ]
    [ ! -e "$CLAUDE_CONFIG_DIR/shared/skills/commit/commit" ]
}

@test "skips a rule whose source was deleted" {
    setup_worktree
    rm "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    run setup_worktree_config
    [ "$status" -eq 0 ]
    [ ! -e "$WORKTREE/.claude/rules/testing.md" ]
    [ "$WORKTREE/.claude/rules/git-conventions.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/git-conventions.md" ]
}

@test "prune_manifest drops the rules of a removed worktree" {
    setup_worktree
    setup_worktree_config
    rm -rf "$WORKTREE"
    run bash -c "SCRIPT_DIR='$CLAUDE_CONFIG_DIR' DRY_RUN=false; source '$CLAUDE_CONFIG_DIR/lib/deploy-lib.sh'; prune_manifest"
    [ "$status" -eq 0 ]
    run grep -q "worktrees/wt" "$CLAUDE_CONFIG_DIR/.deployed-rules"
    [ "$status" -eq 1 ]
    grep -q "^$MAIN_REPO/.claude/rules/testing.md" "$CLAUDE_CONFIG_DIR/.deployed-rules"
}
