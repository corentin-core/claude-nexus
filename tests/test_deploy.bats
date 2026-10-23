#!/usr/bin/env bats

load test_helper/setup

# ─── Basic deployment ────────────────────────────────────────────────────────

@test "deploys shared rules to all git repos" {
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -L "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
    [ "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/git-conventions.md" ]
    [ "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
    [ "$TEST_WORKSPACE/project-b/.claude/rules/git-conventions.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/git-conventions.md" ]
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
    [ -f "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" ]
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
    [ -f "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" ]

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
    [ "$TEST_WORKSPACE/project-a/.claude/rules/custom.md" -ef "$CLAUDE_CONFIG_DIR/projects/project-a/rules/custom.md" ]
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
    [ "$TEST_WORKSPACE/project-a/.claude/rules/git-conventions.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/git-conventions.md" ]
    [ "$(wc -l < "$CLAUDE_CONFIG_DIR/.deployed-rules")" -eq 4 ]
}

# ─── Rule hardlinks ──────────────────────────────────────────────────────────

@test "replaces a symlinked rule with a hardlink" {
    mkdir -p "$TEST_WORKSPACE/project-a/.claude/rules"
    ln -s "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" "$TEST_WORKSPACE/project-a/.claude/rules/testing.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -L "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" ]
    [ "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
}

@test "hardlinks the target of a rule symlinked inside the config repo" {
    mkdir -p "$CLAUDE_CONFIG_DIR/examples/rules"
    echo "# Python rule" > "$CLAUDE_CONFIG_DIR/examples/rules/python.md"
    ln -s ../../examples/rules/python.md "$CLAUDE_CONFIG_DIR/shared/rules/python.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ ! -L "$TEST_WORKSPACE/project-a/.claude/rules/python.md" ]
    grep -q "Python rule" "$TEST_WORKSPACE/project-a/.claude/rules/python.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh" --relink
    ! echo "$output" | grep -q "relinked"
}

@test "a project rule overrides the shared rule of the same name" {
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/project-a/rules"
    echo "# Testing for A" > "$CLAUDE_CONFIG_DIR/projects/project-a/rules/testing.md"
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/projects/project-a/rules/testing.md" ]
    [ "$TEST_WORKSPACE/project-b/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
}

@test "--relink re-links a rule whose source a checkout replaced" {
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    rm "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    echo "# Testing rule, v2" > "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    [ ! "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
    run "$CLAUDE_CONFIG_DIR/deploy.sh" --relink
    [ "$status" -eq 0 ]
    [ "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
    grep -q "v2" "$TEST_WORKSPACE/project-b/.claude/rules/testing.md"
}

@test "--relink removes a rule whose source was deleted" {
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    rm "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh" --relink
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" ]
    ! grep -q "testing.md" "$CLAUDE_CONFIG_DIR/.deployed-rules"
}

@test "installs the relink hooks and leaves a hook of your own alone" {
    git -C "$CLAUDE_CONFIG_DIR" init -q
    echo "#!/bin/sh" > "$CLAUDE_CONFIG_DIR/.git/hooks/post-checkout"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ -x "$CLAUDE_CONFIG_DIR/.git/hooks/post-merge" ]
    grep -q "deploy.sh\" --relink" "$CLAUDE_CONFIG_DIR/.git/hooks/post-merge"
    [ -x "$CLAUDE_CONFIG_DIR/.git/hooks/post-rewrite" ]
    ! grep -q "relink" "$CLAUDE_CONFIG_DIR/.git/hooks/post-checkout"
    echo "$output" | grep -q "hook of your own"
}

@test "post-checkout skips a rebase, and post-rewrite relinks at its end" {
    git -C "$CLAUDE_CONFIG_DIR" init -q
    "$CLAUDE_CONFIG_DIR/deploy.sh"
    rm "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    echo "# Testing rule, v2" > "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    mkdir "$CLAUDE_CONFIG_DIR/.git/rebase-merge"
    (cd "$CLAUDE_CONFIG_DIR" && .git/hooks/post-checkout)
    [ ! "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
    (cd "$CLAUDE_CONFIG_DIR" && .git/hooks/post-rewrite)
    [ "$TEST_WORKSPACE/project-a/.claude/rules/testing.md" -ef "$CLAUDE_CONFIG_DIR/shared/rules/testing.md" ]
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

@test "does not stack a second hook next to a hand-written entry" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    printf -- '---\nname: team\ndescription: deployed hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"

    # The author replaces the deployed hook with their own wording
    printf '# Memory Index\n\n- [Team, my own words](team.md) — kept\n' > "$index"

    printf -- '---\nname: team\ndescription: reworded hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    [ "$(grep -cF 'team.md' "$index")" -eq 1 ]
    grep -qF "[Team, my own words](team.md) — kept" "$index"
}

@test "indexes a memory whose name holds brackets exactly once per deploy" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    printf -- '---\nname: odd\ndescription: bracket hook\n---\n\n# Odd\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/note(1).md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"
    [ "$(grep -cF 'note(1).md' "$index")" -eq 1 ]
}

@test "a redeploy with nothing changed leaves MEMORY.md byte-identical" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    printf -- '---\nname: team\ndescription: stable hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"

    # A section of the author's own, which the redeploy must not disturb either
    printf '\n## My own notes\n\n- [Local note](local.md) — mine\n' >> "$index"
    before=$(md5sum < "$index")

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]
    [ "$(md5sum < "$index")" = "$before" ]
}

@test "dry-run neither rewrites MEMORY.md nor clobbers a MEMORY.md.tmp" {
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/memory"
    printf -- '---\nname: team\ndescription: first hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    echo 'DEPLOY_MEMORY=true' >> "$CLAUDE_CONFIG_DIR/config.sh"

    run "$CLAUDE_CONFIG_DIR/deploy.sh"
    [ "$status" -eq 0 ]

    encoded=$(echo "$TEST_WORKSPACE/project-a" | sed 's|/|-|g')
    index="$CLAUDE_HOME/projects/$encoded/memory/MEMORY.md"
    echo "not deploy's file" > "$index.tmp"
    before=$(md5sum < "$index")

    printf -- '---\nname: team\ndescription: second hook\n---\n\n# Team info\n' \
        > "$CLAUDE_CONFIG_DIR/shared/memory/team.md"
    run "$CLAUDE_CONFIG_DIR/deploy.sh" --dry-run
    [ "$status" -eq 0 ]

    [ "$(md5sum < "$index")" = "$before" ]
    [ "$(cat "$index.tmp")" = "not deploy's file" ]
}
