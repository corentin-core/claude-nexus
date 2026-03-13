# Lint Disables

## Never Disable Lint Silently

**Why**: Disabling warnings hides problems. Each disable is a conscious tradeoff that
the user must validate.

**Rule**: ALWAYS ask the user before adding any lint suppression comment (`# pylint:
disable=`, `# type: ignore`, `# noqa:`, `#[allow(...)]`, `// eslint-disable`, etc.).

When you encounter a lint warning:

1. **Understand** why it triggers
2. **Fix** the underlying issue if possible
3. **If a fix is not possible**, STOP and ask the user:
   - Explain the warning and why it triggers
   - Explain the tradeoff of suppressing it
   - **Wait for explicit approval before adding any disable comment**
4. **Scope narrowly** - prefer inline disables over file-wide

**NEVER add a lint suppression without stopping to ask.** This is a hard checkpoint.
