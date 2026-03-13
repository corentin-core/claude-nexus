---
name: commit
description: Stage and commit changes using conventional commits.
---

# Commit

Create a well-formed conventional commit for the current changes.

## Arguments

`$ARGUMENTS` is an optional hint about what was changed. If empty, infer from
the diff.

## Instructions

1. Run `git status` and `git diff --staged` (and `git diff` if nothing is staged)
2. Analyze the changes to determine the commit type:
   - `feat:` — new feature
   - `fix:` — bug fix
   - `refactor:` — restructuring without behavior change
   - `docs:` — documentation only
   - `test:` — adding/updating tests
   - `chore:` — tooling, dependencies, CI
3. If nothing is staged, stage the relevant files (prefer explicit `git add <file>` over `git add .`)
4. Draft a concise commit message (1-2 lines) focusing on **why**, not **what**
5. Show the message to the user and ask for confirmation
6. Commit

$ARGUMENTS
