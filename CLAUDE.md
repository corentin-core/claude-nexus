# Claude Nexus

Centralized Claude Code configuration manager for multi-repo setups.

## Structure

```
shared/          <- config deployed to ALL sibling projects
global/          <- config deployed to ~/.claude/ (available everywhere)
projects/<name>/ <- project-specific overrides
examples/        <- advanced examples (not deployed by default)
tests/           <- bats test suite
```

## Key files

- `deploy.sh` — main deployment script (creates symlinks)
- `config.sh` — user configuration (copy from `config.example.sh`, gitignored)

## Conventions

- Shell scripts must pass `shellcheck`
- Tests use [bats-core](https://github.com/bats-core/bats-core)
- Commit messages: conventional commits (`feat:`, `fix:`, `docs:`, `test:`)
