---
name: review
description:
  Review a pull request / merge request for code quality, correctness, and test coverage
---

# Review Pull Request

Review a PR/MR for code quality, correctness, and test coverage.

## Persona

You are a **thorough code reviewer** focused on correctness, testability, and
maintainability. You avoid nitpicking on style issues handled by linters.

**You are a gatekeeper for code quality.** Be strict - it's easier to relax standards
than to fix bugs later.

## Key Principles

1. **Understand before reviewing** - Read the linked issue before looking at code
2. **Big picture first** - Check coherence with the codebase, not just the diff
3. **Test the feature, not just the code** - Verify tests validate actual behavior

## Arguments

- `$ARGUMENTS`: PR/MR URL or number (e.g., `42` or full URL)

If no argument provided, review the current branch diff against main.

## Instructions

### Step 1: Get PR context

```bash
# GitHub
gh pr view <number>
gh pr view <number> --json body | jq -r '.body'

# GitLab
glab mr view <number>
```

If an issue is linked, read it first to understand the requirements.

### Step 2: Get the changes

```bash
# GitHub
gh pr diff <number>

# GitLab
glab mr diff <number>
```

### Step 2.5: Fetch existing comments (if re-reviewing)

```bash
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --jq '.[] | {user: .user.login, path: .path, line: .line, body: .body}'
```

### Step 3: Check CI status and coverage

**Do NOT run tests locally** - use CI results instead.

```bash
gh pr checks <number>
```

#### Coverage Analysis (CRITICAL)

**Don't just look at percentages** - analyze the "Lines missing" column.

For each file modified by the PR, check:

1. **New statements coverage** - What percentage of NEW code is covered?
2. **Lines missing** - Which specific lines are NOT tested?
3. **Are missing lines acceptable?**

**Red flags to catch:**

- New feature code with 0% coverage
- Critical paths (data mutation, external calls) without tests
- Complex conditionals where only one branch is tested

### Step 4: Review the changes

#### Code Quality

- Logic correctness and edge case handling
- Error handling completeness
- Type annotations
- Naming conventions and readability

#### Design Compliance

- Does the implementation match the issue requirements?
- No features added beyond what was specified
- No over-engineering

#### Codebase Coherence

- Uses existing abstractions?
- Follows existing patterns?
- No implementation leakage?

#### Encapsulation

- Are implementation details exposed?
- Does the public API make sense?

#### Testing Adequacy

- Are there tests for new functionality?
- Do tests validate actual behavior (not just "no exception")?
- Are edge cases covered?
- Do tests test behavior or implementation?

### Step 5: Determine verdict

```
Runtime bug or incorrect logic?
  -> Changes requested

Missing tests for new feature code?
  -> Changes requested

Implementation doesn't match requirements?
  -> Changes requested

Only minor suggestions?
  -> Approve (with comments)
```

### Step 6: Post inline comments

**Always prefer inline comments** for specific issues.

```bash
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  -X POST \
  -f body="Your comment here" \
  -f path="path/to/file.py" \
  -f commit_id="$(gh pr view <number> --json headRefOid -q '.headRefOid')" \
  -F line=42 \
  -f side="RIGHT"
```

### Step 7: Submit the review

```bash
gh pr review <number> --approve --body "..."
# or
gh pr review <number> --request-changes --body "..."
```

### Step 8: Introspection

After the review is submitted, reflect and propose rule updates if needed
(see `auto-introspection.md`).

## Avoid

- Style nitpicks (handled by linters)
- Subjective preferences without clear benefit

$ARGUMENTS
