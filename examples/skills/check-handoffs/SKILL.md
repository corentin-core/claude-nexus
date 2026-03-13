---
name: check-handoffs
description:
  Check for pending cross-repo messages addressed to the current project. Use at the
  start of a session or when coordinating with other Claude instances.
---

# Check Handoffs

Read pending messages from the shared context that are addressed to the current project.

## Arguments

`$ARGUMENTS` is optional. Can specify a task ID to check only that task:

- `/check-handoffs` — check all active tasks
- `/check-handoffs 20260312-move-tests` — check specific task

## Instructions

### 1. Identify current project

```bash
basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

### 2. Find active tasks

```bash
cat $BASE_DIR/.shared-context/active-tasks.md 2>/dev/null
```

### 3. Scan for pending messages

For each active task, read messages where `to:` matches this project and `status: pending`.

### 4. For each pending message, propose actions based on type:

- **handoff**: Copy staging files, apply changes, acknowledge
- **question**: Answer the question, respond via `/handoff`
- **result**: Review results, acknowledge

### 5. Process (with user confirmation)

1. Copy staging files to the appropriate location
2. Apply described changes (import updates, etc.)
3. Acknowledge the message (`status: pending` → `status: acknowledged`)
4. Optionally send a response via `/handoff`

$ARGUMENTS
