# Resource Management

**Why**: Running heavy tasks in parallel (pre-commit + full test suite, multiple Docker
containers, parallel builds) can exhaust RAM and freeze the user's machine.

## Rules

**NEVER run heavy tasks in parallel.** Specifically:

- Never run pre-commit and a test suite at the same time
- Never run two test suites simultaneously
- Never launch a background build while tests are running

**ALWAYS limit test parallelism:**

```bash
# Disable xdist parallel workers to avoid RAM explosion
pytest tests/ -p no:xdist

# Or limit workers explicitly
pytest tests/ -n 2  # max 2 workers
```

**ALWAYS run heavy tasks sequentially**, one at a time:

```bash
# GOOD: one at a time
pre-commit run --all-files
# wait for completion, then:
pytest tests/

# BAD: both in parallel background tasks
```

**Monitor before launching:** If a heavy task is already running in the background,
wait for it to complete before starting another one.
