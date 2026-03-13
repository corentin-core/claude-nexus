## Pull Request Review

**Why**:
- Thorough reviews catch bugs, security issues, and design problems early
- Consistent review format helps authors address feedback efficiently

**Rule**: ALWAYS check these before approving:
1. Tests cover the changed behavior
2. No unrelated changes mixed in
3. Error handling is present at system boundaries
4. No secrets or credentials in the diff

**Rule**: NEVER approve if CI is failing.
