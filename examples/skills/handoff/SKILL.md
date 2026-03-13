---
name: handoff
description:
  Send a message or files to another repo as part of a cross-repo task. Use when
  coordinating work between Claude instances in different repositories.
---

# Handoff

Communicate with another Claude instance working in a different repository, as part of a
cross-repo task.

## Arguments

`$ARGUMENTS` is a free-form string. Parse it for:

| Parameter | Format | Example |
|-----------|--------|---------|
| **to** | repo name | `to my-api`, `to frontend` |
| **task** | task ID (optional, auto-detected) | `task 20260312-move-tests` |
| **type** | message type (default: `handoff`) | `type result`, `type question` |
| **files** | files to copy to staging | `files tests/test_foo.py tests/test_bar.py` |

Example: `/handoff to my-api files tests/test_foo.py type handoff`

## Instructions

### 1. Identify the task

If no task ID is provided, find the active task involving the current project:

```bash
cat $BASE_DIR/.shared-context/active-tasks.md 2>/dev/null
```

If multiple tasks are active, ask the user which one.

### 2. Copy files to staging (if any)

```bash
TASK_DIR=$BASE_DIR/.shared-context/tasks/<task-id>

for file in <file-list>; do
  mkdir -p "$TASK_DIR/staging/$(dirname "$file")"
  cp "$file" "$TASK_DIR/staging/$file"
done
```

### 3. Write the message

Determine the next message number, then write:

```bash
TASK_DIR=$BASE_DIR/.shared-context/tasks/<task-id>

cat > "$TASK_DIR/messages/${NEXT}-${FROM}.md" << 'EOF'
---
from: <from>
to: <to>
type: <type>
status: pending
timestamp: <ISO-8601>
---

## Summary

<what was done / what needs to happen>

## Files in staging

- `staging/<path>` — <description>

## Action needed

<what the receiving instance should do>
EOF
```

### 4. Confirm to user

```
Message written to task <task-id>.
The instance in <target-project> can pick this up with /check-handoffs.
```

$ARGUMENTS
