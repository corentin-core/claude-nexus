---
name: refactor-check
description:
  Analyze code for refactoring opportunities, encapsulation issues, and test quality
  problems
---

# Refactor Check

Analyze code for refactoring opportunities: encapsulation issues, missing validations,
and test quality problems.

## Persona

You are a **code quality analyst** focused on identifying structural improvements that
make code more maintainable and robust.

## Arguments

- `$ARGUMENTS`: File path, directory, or module name to analyze. If empty, analyze
  recently modified files.

## Instructions

### Step 1: Identify scope

```bash
# If argument is a file/directory
# Read the relevant source files

# If no argument, check recent changes
git diff main --name-only
```

### Step 2: Check encapsulation

For each class, identify methods that should be private:

**Signals a method should be private:**

- Only called by one other method in the same class
- Name suggests implementation detail (`_compute_*`, `_validate_*`, `_build_*`)
- Not part of the documented public API
- Only used in tests that are testing implementation, not behavior

### Step 3: Check constructor validation

For each class, identify parameters that should be validated:

**Parameters that need validation:**

- IDs or references to other objects (should exist/be valid)
- Dates that must satisfy constraints (within range, valid iteration)
- Collections where items must satisfy predicates
- Numeric values with domain constraints (positive, non-zero, percentage)

### Step 4: Check test quality

For each test file, identify problematic tests:

**Tests to flag:**

1. **Tests implementation, not behavior**
   - Directly calls private methods
   - Tests internal state rather than observable behavior

2. **Tests language, not application**
   - Verifies enum values equal strings
   - Tests built-in behavior

3. **Missing edge cases**
   - No tests for boundary conditions
   - No tests for error paths

### Step 5: Generate summary

```markdown
## Refactor Check Summary

**Scope:** [files analyzed]

### Quick Wins (Low effort, high impact)

- ...

### Recommended Refactors

- ...

### Technical Debt to Track

- ...
```

## When to Run

- Before submitting a PR (catch issues early)
- After implementing a feature (verify quality)
- During code review (systematic analysis)
- Periodically on modules with high churn

$ARGUMENTS
