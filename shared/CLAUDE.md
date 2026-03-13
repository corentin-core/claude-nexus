# Shared Context

## Language Conventions

- **Code, commits, PRs**: English
- **Conversation**: Adapt to the user's language

## Working Principles

### Documentation-First

Read project documentation before modifying a module.

### Coherence with Existing Codebase

When modifying code that depends on internal packages, check how they're used
in related modules. Verify that the interface contract (field names, types,
return values) is respected.

### Apply Changes Globally

When a fix or pattern is requested, don't just apply it where explicitly
mentioned. Search for the same pattern elsewhere and fix all occurrences.

## Configuration Management

Config is managed via the `claude-nexus` repo (sibling of your projects).

- **Never edit symlinked files directly** in project `.claude/` directories
- After adding/removing config files: run `claude-nexus/deploy.sh`
