#!/usr/bin/env bats

load test_helper/setup

# ─── Basic deployment ────────────────────────────────────────────────────────

@test "deploys shared rules to all git repos" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" ]
    [ -L "$TEST_WORKSPACE/project-b/.claude/rules/git-conventions.md" ]
}

@test "deploys shared commands to all git repos" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/commands/handle-pr.md" ]
    [ -L "$TEST_WORKSPACE/project-b/.claude/commands/handle-pr.md" ]
}

@test "deploys shared skills as directory symlinks" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/skills/commit" ]
    [ -d "$TEST_WORKSPACE/project-a/.claude/skills/commit" ]
}

@test "deploys shared settings.json" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/settings.json" ]
}

# ─── Parent CLAUDE.md ────────────────────────────────────────────────────────

@test "deploys parent CLAUDE.md to base dir" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/CLAUDE.md" ]
    grep -q "Shared CLAUDE.md" "$TEST_WORKSPACE/CLAUDE.md"
}

@test "skips parent CLAUDE.md when disabled" {
    echo 'DEPLOY_PARENT_CLAUDE_MD=false' >> "$CLAUDE_CONFIG_DIR/config.sh"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_WORKSPACE/CLAUDE.md" ]
}

# ─── Global deployment ───────────────────────────────────────────────────────

@test "deploys global commands and agents to CLAUDE_HOME" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_HOME/commands/update-config.md" ]
    [ -L "$CLAUDE_HOME/agents/reviewer.md" ]
}

@test "skips global deployment when disabled" {
    echo 'DEPLOY_GLOBAL=false' >> "$CLAUDE_CONFIG_DIR/config.sh"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$CLAUDE_HOME/commands/update-config.md" ]
    [ ! -e "$CLAUDE_HOME/agents/reviewer.md" ]
}

# ─── Non-git directories skipped ─────────────────────────────────────────────

@test "skips directories without .git" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACE/not-a-repo/.claude" ]
}

# ─── Self-skip ───────────────────────────────────────────────────────────────

@test "does not deploy to itself" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -d "$CLAUDE_CONFIG_DIR/.claude/rules" ]
}

# ─── Exclude projects ────────────────────────────────────────────────────────

@test "skips excluded projects" {
    echo 'EXCLUDE_PROJECTS=("project-b")' >> "$CLAUDE_CONFIG_DIR/config.sh"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
    [ ! -d "$TEST_WORKSPACE/project-b/.claude" ]
}

# ─── Never overwrite real files ──────────────────────────────────────────────

@test "never overwrites a real file" {
    mkdir -p "$TEST_WORKSPACE/project-a/.claude/rules"
    echo "# My custom rule" > "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    # Should still be a regular file, not a symlink
    [ ! -L "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
    grep -q "My custom rule" "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md"
}

# ─── Stale symlink cleanup ───────────────────────────────────────────────────

@test "removes stale symlinks pointing to deleted config" {
    # Deploy first
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ -L "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" ]

    # Remove the source file
    rm "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"

    # Re-deploy
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" ]
}

# ─── Gitignore management ────────────────────────────────────────────────────

@test "adds .claude/ to .gitignore" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    grep -qxF '.claude/' "$TEST_WORKSPACE/project-a/.gitignore"
}

@test "does not duplicate .claude/ in .gitignore on second run" {
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    count=$(grep -cxF '.claude/' "$TEST_WORKSPACE/project-a/.gitignore")
    [ "$count" -eq 1 ]
}

# ─── Project-specific overrides ──────────────────────────────────────────────

@test "deploys project-specific rules only to that project" {
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/project-a/rules"
    echo "# Custom rule for A" > "$CLAUDE_CONFIG_DIR/projects/project-a/rules/custom.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/rules/custom.md" ]
    [ ! -e "$TEST_WORKSPACE/project-b/.claude/rules/custom.md" ]
}

@test "project-specific CLAUDE.md is symlinked" {
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/project-a"
    echo "# Project A context" > "$CLAUDE_CONFIG_DIR/projects/project-a/CLAUDE.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/CLAUDE.md" ]
    grep -q "Project A context" "$TEST_WORKSPACE/project-a/CLAUDE.md"
}

@test "warns about name collisions" {
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/project-a/rules"
    echo "# Override" > "$CLAUDE_CONFIG_DIR/projects/project-a/rules/git-conventions.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "overrides shared"
}

# ─── Settings.json priority ──────────────────────────────────────────────────

@test "project-specific settings.json takes priority over shared" {
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/project-a"
    echo '{"custom": true}' > "$CLAUDE_CONFIG_DIR/projects/project-a/settings.json"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/settings.json" ]
    grep -q "custom" "$TEST_WORKSPACE/project-a/.claude/settings.json"
}

# ─── Dry-run mode ────────────────────────────────────────────────────────────

@test "dry-run creates no symlinks" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh" --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DRY RUN"
    [ ! -e "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
    [ ! -e "$TEST_WORKSPACE/CLAUDE.md" ]
}

# ─── Idempotency ─────────────────────────────────────────────────────────────

@test "running deploy twice is idempotent" {
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -L "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
}

# ─── Memory deployment ───────────────────────────────────────────────────────

@test "deploys memory when enabled" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    echo "# Team info" > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    # Memory should be deployed to the encoded path
    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    [ -L "$CLAUDE_HOME/projects/$encoded/memory/team.md" ]
}

@test "skips memory when disabled" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    echo "# Team info" > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    [ ! -e "$CLAUDE_HOME/projects/$encoded/memory/team.md" ]
}

@test "indexes deployed memory in MEMORY.md" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    echo "# Team info" > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"
    [ -f "$index" ]
    grep -qF "[team.md](team.md)" "$index"
}

@test "prunes stale MEMORY.md entry when shared memory is deleted" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    echo "# Team info" > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"
    grep -qF "team.md" "$index"

    # Delete the shared memory and redeploy
    rm "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    # Symlink removed and index entry pruned
    [ ! -e "$CLAUDE_HOME/projects/$encoded/memory/team.md" ]
    ! grep -qF "team.md" "$index"
}

@test "prune leaves hand-written MEMORY.md entries alone" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    echo "# Team info" > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    memory_dir="$CLAUDE_HOME/projects/$encoded/memory"
    index="$memory_dir/MEMORY.md"

    # A locally-authored entry: link text differs from the (absent) target
    echo "- [My Local Note](local-note.md) — kept" >> "$index"

    # Delete the shared memory and redeploy: team.md prunes, local entry stays
    rm "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    ! grep -qF "team.md" "$index"
    grep -qF "[My Local Note](local-note.md)" "$index"
}

# ─── Empty directories ───────────────────────────────────────────────────────

@test "works with no shared rules" {
    rm -f "$CLAUDE_CONFIG_DIR/shared/rules/"*.md
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
}

@test "refreshes the MEMORY.md hook when a shared memory description changes" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    printf -- '---\nname: team\ndescription: first hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"
    grep -qF "— first hook" "$index"

    # Reword the description and redeploy: the already-indexed entry follows
    printf -- '---\nname: team\ndescription: second hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    grep -qF "— second hook" "$index"
    ! grep -qF "— first hook" "$index"
    [ "$(grep -c "\[team.md\](team.md)" "$index")" -eq 1 ]
}

@test "description refresh leaves a hand-written entry for the same file alone" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    printf -- '---\nname: team\ndescription: deployed hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"

    # Link text differs from the target, so this one is the author's, not deploy's
    echo "- [Team, my own words](team.md) — kept" >> "$index"

    printf -- '---\nname: team\ndescription: reworded hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    grep -qF "— reworded hook" "$index"
    grep -qF "[Team, my own words](team.md) — kept" "$index"
}
