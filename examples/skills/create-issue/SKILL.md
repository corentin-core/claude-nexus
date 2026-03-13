---
name: create-issue
description:
  Create a well-structured issue (feature or bug) with proper labels and context.
  Works with GitHub and GitLab.
---

# Create Issue

Create a well-structured issue from a description or observed bug.

## Arguments

`$ARGUMENTS` is a free-form description. Parse it for:

| Parameter | Format | Example |
|-----------|--------|---------|
| **type** | `bug` or `feature` (default: `feature`) | `bug: login fails on Safari` |
| **description** | free-form text | the rest of the arguments |

## Instructions

### Step 1: Gather context

If reporting a bug:

1. **Reproduce** - Check logs, error messages, or user reports
2. **Identify affected component** - Which part of the codebase?
3. **Check for duplicates** - Search existing issues

If creating a feature:

1. **Understand the ask** - What problem does this solve?
2. **Check related issues** - Dependencies, duplicates, parent epics

### Step 2: Draft the issue

#### Bug template

```markdown
## Description

<Clear description of the bug>

## Steps to Reproduce

1. <step 1>
2. <step 2>
3. <step 3>

## Expected Behavior

<what should happen>

## Actual Behavior

<what happens instead>

## Environment

- Version: <version or commit>
- OS: <if relevant>

## Root Cause (if identified)

<analysis of why this happens>

## Proposed Fix

<approach to fix, if known>
```

#### Feature template

```markdown
## Context

<Why is this needed? What problem does it solve?>

## Proposed Solution

<High-level approach>

## Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Technical Notes

<Any implementation details, constraints, or dependencies>

## Related Issues

- <links to related issues>
```

### Step 3: User review

Present the draft to the user. **Wait for approval before creating.**

### Step 4: Create the issue

```bash
# GitHub
gh issue create --title "<type>: <title>" --body "$(cat <<'EOF'
<issue body>
EOF
)" --label "<label1>,<label2>"

# GitLab
glab issue create --title "<type>: <title>" --description "..." --label "<label>"
```

### Step 5: Apply labels

Common label scheme:

| Label | When |
|-------|------|
| `bug` | Bug report |
| `enhancement` | New feature |
| `priority:high` | Blocking or critical |
| `priority:medium` | Should be done soon |
| `priority:low` | Nice to have |

### Step 6: Confirm

```
Issue #<number> created: <url>
Labels: <labels>
```

$ARGUMENTS
