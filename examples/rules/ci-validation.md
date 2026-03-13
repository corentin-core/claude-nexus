# CI/CD Validation

## Always validate CI before pushing

A broken pipeline wastes reviewer time. Validate syntax BEFORE pushing.

**GitHub Actions:**

```bash
# Use act for local validation (https://github.com/nektos/act)
act --list  # list available workflows
act -n      # dry-run

# Or check syntax online: https://rhysd.github.io/actionlint/
```

**GitLab CI:**

```bash
# Validate .gitlab-ci.yml syntax
glab ci lint
```

## Common CI errors to catch

| Error                           | Cause                                              |
| ------------------------------- | -------------------------------------------------- |
| `chosen stage X does not exist` | Job uses undefined stage (e.g., `test` vs `tests`) |
| `jobs config should contain...` | Missing required fields in job definition           |
| `unknown keys`                  | Typo in job configuration key                       |
| Invalid action reference        | Using `@v3` when `@v4` is latest                    |

## Check Docker image versions

Verify that Docker image tags referenced in CI are recent (not outdated by more than a
few minor versions). Check the project's container registry for latest tags.

## Analyzing CI failures on PRs/MRs

**Why**: When tests fail on a PR pipeline, comparing with *earlier pipelines of the same
branch* is misleading — they share the same broken code. Only comparing with the
**target branch** (e.g., `main`) tells you whether the failure is introduced by the PR.

**Rule**: When CI tests fail on a PR/MR:

1. Check if the **target branch pipeline passes** (e.g., latest `main` pipeline)
2. If target passes but PR fails → the PR introduces the failure, investigate the diff
3. If target also fails on the same tests → pre-existing issue, not caused by the PR
4. **Never conclude** "failures are pre-existing" just because earlier pipelines on the
   same branch also failed
