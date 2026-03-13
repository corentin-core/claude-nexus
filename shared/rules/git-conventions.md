## Git Conventions

**Why**:
- Consistent commit history makes changelogs and bisect useful
- Clean branches simplify reviews

**Rule**: ALWAYS use conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).

**Rule**: NEVER force-push to `main`/`master`.

```bash
# GOOD
git commit -m "feat: add user export endpoint"
git commit -m "fix: handle null response in auth middleware"

# BAD
git commit -m "update stuff"
git commit -m "wip"
```
