# Auto-Introspection

## Trigger

This rule activates **automatically** when the user:

- Contradicts you ("no", "that's wrong")
- Points out an error ("you made a mistake", "that's not right")
- Corrects your work ("don't do X, instead do Y")
- Expresses frustration with your output ("this is bad", "start over")

## Response Pattern

When triggered, **always** end your response with a proposal to update your config:

```markdown
---

**Improvement proposal:**

I made the mistake of [concise description]. To prevent this in the future:

- **File to modify**: `.claude/rules/X.md` | `.claude/skills/X/SKILL.md` | `CLAUDE.md`
- **Proposed change**: [description of the change]

Should I apply this change? (`/update-config`)
```

## Decision Tree

```
User points out error
  ↓
Is it a recurring pattern that could happen again?
  YES → Propose rule/skill update
  NO  → Just acknowledge and fix, no config change needed

What type of mistake?
  - Wrong process/workflow → Update skill (SKILL.md)
  - Missing knowledge about project → Update CLAUDE.md
  - Bad habit/pattern → Create/update rule (.claude/rules/)
```

## Examples

### Example 1: Workflow mistake

**User**: "stop running tests locally, CI already does that"

**Response should include**:

```markdown
---

**Improvement proposal:**

I made the mistake of running tests locally when CI already provides those results.

- **File to modify**: `.claude/skills/review/SKILL.md`
- **Proposed change**: Add a "Check CI status" step and explicitly state to NOT run
  tests locally

Should I apply this change? (`/update-config`)
```

### Example 2: One-off mistake (no config change)

**User**: "you forgot a parameter in that function call"

**Response**: Fix the mistake, but no config proposal needed (too specific, won't
recur).

## Important

- **Don't wait to be asked** - propose the improvement proactively
- **Be specific** - identify the exact file and change needed
- **Be concise** - the proposal should be 3-5 lines max
- **Ask permission** - never modify config without user approval
- **Use `/update-config`** - when the user approves, invoke the skill to apply the change
