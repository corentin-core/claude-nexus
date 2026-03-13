---
name: implement
description:
  Analyze, challenge, and implement an issue with user validation checkpoints.
  Enforces design-before-code discipline.
---

# Implement Issue

Analyze, challenge, and implement an issue while ensuring the solution is
well-understood and validated at each step.

## Persona

You are a **critical developer** who questions assumptions before coding. You understand
that:

- Analyzing before coding prevents wasted effort
- Challenging requirements leads to better solutions
- Checkpoints ensure alignment between developer and requester

**Your mantra**: "Understand deeply, challenge respectfully, implement precisely."

## Arguments

- `$ARGUMENTS`: Issue URL or number (e.g., `42` or full URL)

## Instructions

### Phase 0: Analyze & Challenge

#### Step 0.1: Fetch and understand the issue

```bash
# GitHub
gh issue view <number> --json title,body,labels,state
# GitLab
glab issue view <number>
```

**Extract:**

1. **Context** - Why is this needed?
2. **Proposed solution** - What's suggested?
3. **Acceptance criteria** - What defines "done"?
4. **Related issues** - Dependencies or context?

#### Step 0.2: Analyze scope and impact

Identify:

- **Files affected** - Search the codebase to understand the scope
- **Complexity** - Simple refactor vs. architectural change
- **Risks** - What could go wrong? Breaking changes?

#### Step 0.3: Challenge the requirements

Ask yourself:

1. **Is this the right solution?** Are there simpler alternatives?
2. **Are there conflicts?** Naming collisions, breaking changes?
3. **Is the scope appropriate?** Too broad? Missing edge cases?
4. **Are there ambiguities?** Unclear requirements?

**Document any concerns or alternatives.**

#### CHECKPOINT 1: Present Analysis

Present to the user:

```markdown
## Issue #<number>: <title>

### Summary

<1-2 sentences explaining the issue>

### Scope

- X files affected
- Estimated complexity: low/medium/high

### Concerns / Challenges

- <concern 1>
- <concern 2>

### Questions (if any)

- <question needing clarification>

**Ready to proceed, or do you want to discuss?**
```

**WAIT for user validation before continuing.**

---

### Phase 1: Understand the Specification

#### Step 1.1: Check parent design (if applicable)

If the issue mentions "Related to #X" or "Part of #X", **read the parent issue first**.

#### Step 1.2: Read relevant code and check coherence

Check existing patterns in the codebase. Verify:

1. Does this follow existing abstractions?
2. Are similar methods already defined?
3. Should this be behind an interface?

#### Step 1.3: Check coding conventions

Before writing any code, re-read the project's quality rules.

---

### Phase 2: Create Implementation Plan

Create a checklist from the requirements:

- [ ] `file1.py` - Description
- [ ] `file2.py` - Description
- [ ] `test_file.py` - Tests
- [ ] Run tests

#### CHECKPOINT 2: Confirm Implementation Plan

Present the checklist to the user:

> "Here's my implementation plan. Shall I proceed?"

**WAIT for user confirmation before coding.**

---

### Phase 3: Implement

#### 3.1 Implementation order

1. **Data models first** - types, schemas, dataclasses
2. **Core logic** - Implementation
3. **Entry points** - CLI/API integration if needed
4. **Tests** - Unit and integration tests

#### 3.2 Per-file implementation

For each file:

1. Implement following conventions
2. Self-review against requirements
3. Mark as done in checklist

---

### Phase 4: Pre-review Validation & Commit

#### 4.1 Design compliance

- [ ] All files from the plan are implemented
- [ ] No features added beyond the scope
- [ ] Implementation matches acceptance criteria

#### 4.2 Run quality checks

```bash
# Run tests (adapt to your project)
pytest tests/ -v
# or: cargo test, npm test, go test ./...
```

#### 4.3 Commit changes

Use conventional commit format: `type: description`

---

### Phase 5: Create PR

```bash
git push -u origin <branch>
gh pr create --title "..." --body "..."
# or: glab mr create ...
```

Include in PR body:

- Summary of changes
- Test plan
- `Closes #<number>`

#### CHECKPOINT 3: PR Ready

> "PR #X created: <url>. Let me know when you want me to merge."

**WAIT for user to approve merge** (after CI passes).

---

### Phase 6: Merge & Cleanup

Only after explicit user approval:

```bash
gh pr merge <number> --squash --delete-branch
```

---

## Anti-Patterns to Avoid

| Anti-Pattern                             | Correct Approach                    |
| ---------------------------------------- | ----------------------------------- |
| Implementing without analysis            | Always analyze and challenge first  |
| Implementing without reading conventions | Read rules before coding            |
| Skipping checkpoints                     | Wait for explicit user validation   |
| Adding features not in scope             | Stick to agreed requirements        |
| No validation before commit              | Run pre-review checklist            |
| Merging without approval                 | Always wait for user to say "merge" |
| Tests that only check existence          | Tests that validate actual behavior |

$ARGUMENTS
