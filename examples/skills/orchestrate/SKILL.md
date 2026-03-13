---
name: orchestrate
description:
  Orchestrate a cross-repo task by creating a plan, dispatching workers (autonomous or
  interactive), and validating consistency. Use when work spans multiple repositories.
---

# Cross-Repo Orchestrator

Coordinate work across multiple repositories by creating tasks, dispatching workers, and
validating results.

## Arguments

`$ARGUMENTS` is the task description. It should mention:
- What needs to happen (move files, sync changes, migrate code, etc.)
- Which repos are involved (if known)

Example: `/orchestrate move integration tests from repo-a to repo-b`

## Instructions

### Phase 1: Understand the task

1. Parse `$ARGUMENTS` to understand what needs to happen
2. Identify the repos involved. Check they exist:

```bash
ls -d $BASE_DIR/<repo>/ 2>/dev/null
```

3. For each repo, quickly assess current state:

```bash
git -C $BASE_DIR/<repo> branch --show-current
git -C $BASE_DIR/<repo> status --short
```

4. Identify dependencies between steps (what must happen before what)

### Phase 2: Create the task

1. Generate a task ID: `<date>-<short-description>` (e.g., `20260312-move-tests`)

2. Create the task directory and files:

```bash
TASK_DIR=$BASE_DIR/.shared-context/tasks/<task-id>
mkdir -p "$TASK_DIR/staging" "$TASK_DIR/messages"
```

3. Write `task.md` with the plan:

```markdown
---
id: <task-id>
status: planning
created: <ISO-8601>
repos:
  - <repo1>
  - <repo2>
---

# <Task title>

## Goal

<What we're trying to achieve>

## Steps

### Step 1: <description> (repo: <repo>, mode: <autonomous|interactive>)

- [ ] <substep>
- [ ] <substep>

### Step 2: <description> (repo: <repo>, mode: <autonomous|interactive>)

- [ ] <substep>
- [ ] <substep>

## Validation Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
```

4. Update the active tasks index:

```bash
ACTIVE=$BASE_DIR/.shared-context/active-tasks.md
mkdir -p "$BASE_DIR/.shared-context/tasks"
echo "- [<task-id>](tasks/<task-id>/task.md) — <one-line summary> (status: planning)" >> "$ACTIVE"
```

5. **Present the plan to the user** and ask for confirmation before proceeding.

### Phase 3: Dispatch workers

For each step in the plan, decide the execution mode:

**Criteria for autonomous mode** (worker runs unattended via `claude -p`):
- Task is mechanical and well-defined (copy files, update imports, run tests)
- No ambiguous decisions needed
- Changes are limited in scope and reversible

**Criteria for interactive mode** (user launches a separate Claude instance):
- Task involves design decisions
- Complex refactoring with judgment calls
- User wants to review as it happens

**CRITICAL: Do NOT use the Agent tool for autonomous workers.** The Agent tool creates
sub-agents in the same process that inherit permission constraints and CANNOT get Bash
permissions when running in background. Always use `claude -p` via the Bash tool.
The Agent tool is fine for read-only research tasks that don't need Bash.

#### Autonomous worker dispatch

**Always use a git worktree** so the worker has an isolated copy of the repo.

```bash
# 1. Create an isolated worktree for the worker
REPO=$BASE_DIR/<repo>
TASK_ID=<task-id>
BRANCH=<branch-name>
WORKTREE=/tmp/worker-<repo>-$TASK_ID

git -C "$REPO" fetch origin
git -C "$REPO" worktree add "$WORKTREE" -b "$BRANCH" origin/main

# 2. Write the worker prompt
cat > /tmp/worker-<repo>.txt << 'PROMPT'
You are working on a cross-repo task in a git worktree.

## Important: you are in a worktree
- Your working directory is a git worktree, NOT the main repo
- All your changes are isolated — no conflict with other instances

## Task context
<paste relevant section from task.md>

## Your assignment
<specific instructions for this worker>

## When done
Write your results to the shared context messages directory, then exit.
PROMPT

# 3. Launch the worker in the worktree
cd "$WORKTREE" && claude -p \
  --permission-mode bypassPermissions \
  --disallowedTools "Bash(rm -rf *) Bash(git push --force *)" \
  --no-session-persistence \
  "$(cat /tmp/worker-<repo>.txt)" 2>&1
```

**Important**: Run workers sequentially if steps depend on each other. Run in parallel
only for truly independent steps.

#### Worktree cleanup

After validation:

```bash
git -C $BASE_DIR/<repo> worktree remove /tmp/worker-<repo>-<task-id>
git -C $BASE_DIR/<repo> branch -d <branch-name>
```

#### Interactive worker dispatch

For interactive steps, tell the user:

```
Please open a new terminal and run:
  cd $BASE_DIR/<repo> && claude

Then tell the instance:
  /check-handoffs
```

### Phase 4: Follow up and validate

After workers complete:

1. **Read worker messages** from the shared context
2. **Validate consistency** (files moved, imports updated, tests pass)
3. **Handle blockers** (relay answers, ask user if needed)
4. **Update task status** as steps complete
5. **Final report** to the user with changes by repo and next steps
6. Update `active-tasks.md` status to `done`

## Error Handling

- If an autonomous worker fails, capture its output and present to the user
- If a worker times out (>10 minutes), kill it and switch to interactive mode
- If staging files are inconsistent, stop and report the discrepancy

$ARGUMENTS
