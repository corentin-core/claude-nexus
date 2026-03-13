# Common test setup for deploy.sh tests

# Create a temporary workspace that mimics the expected directory structure:
# workspace/
# ├── claude-nexus/    (copy of the repo)
# ├── project-a/        (fake git repo)
# ├── project-b/        (fake git repo)
# └── not-a-repo/       (no .git — should be skipped)

setup() {
    TEST_WORKSPACE="$(mktemp -d)"

    # "Install" claude-nexus into the workspace
    CLAUDE_CONFIG_DIR="$TEST_WORKSPACE/claude-nexus"
    mkdir -p "$CLAUDE_CONFIG_DIR"

    # Copy deploy.sh and config.example.sh
    cp "$BATS_TEST_DIRNAME/../deploy.sh" "$CLAUDE_CONFIG_DIR/deploy.sh"
    chmod +x "$CLAUDE_CONFIG_DIR/deploy.sh"

    # Create shared config
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/rules"
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/commands"
    mkdir -p "$CLAUDE_CONFIG_DIR/shared/skills/commit"
    mkdir -p "$CLAUDE_CONFIG_DIR/global/commands"
    mkdir -p "$CLAUDE_CONFIG_DIR/global/agents"
    mkdir -p "$CLAUDE_CONFIG_DIR/projects"

    echo "# Shared CLAUDE.md" > "$CLAUDE_CONFIG_DIR/shared/CLAUDE.md"
    echo "# Git rule" > "$CLAUDE_CONFIG_DIR/shared/rules/git-conventions.md"
    echo "# Testing rule" > "$CLAUDE_CONFIG_DIR/shared/rules/testing.md"
    echo "# Handle PR" > "$CLAUDE_CONFIG_DIR/shared/commands/handle-pr.md"
    echo "---" > "$CLAUDE_CONFIG_DIR/shared/skills/commit/SKILL.md"
    echo '{"permissions":{}}' > "$CLAUDE_CONFIG_DIR/shared/settings.json"
    echo "# Global cmd" > "$CLAUDE_CONFIG_DIR/global/commands/update-config.md"
    echo "# Agent" > "$CLAUDE_CONFIG_DIR/global/agents/reviewer.md"

    # Create fake git repos
    mkdir -p "$TEST_WORKSPACE/project-a/.git"
    mkdir -p "$TEST_WORKSPACE/project-b/.git"

    # Create a non-git directory (should be skipped)
    mkdir -p "$TEST_WORKSPACE/not-a-repo"

    # Override CLAUDE_HOME to avoid touching the real one
    export CLAUDE_HOME="$TEST_WORKSPACE/.claude"
    mkdir -p "$CLAUDE_HOME"

    # Write a config.sh that points BASE_DIR to our workspace
    cat > "$CLAUDE_CONFIG_DIR/config.sh" << EOF
BASE_DIR="$TEST_WORKSPACE"
DEPLOY_GLOBAL=true
DEPLOY_PARENT_CLAUDE_MD=true
DEPLOY_SETTINGS=true
DEPLOY_MEMORY=false
EXCLUDE_PROJECTS=()
EOF
}

teardown() {
    rm -rf "$TEST_WORKSPACE"
}
