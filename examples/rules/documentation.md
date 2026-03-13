# Documentation Guidelines

## Language

**Rule**: ALWAYS write documentation in English, including user documentation.

This ensures consistency across the codebase and makes the project accessible to a wider
audience.

## Structure

Separate user documentation from developer documentation:

```
docs/
├── user/    # End-user guides (how to use features)
└── dev/     # Developer docs (architecture, data flows, APIs)
```

## No File Paths

**Why**: File paths create maintenance burden when refactoring.

**Rule**: NEVER include file paths in documentation unless absolutely necessary.

## Developer Documentation Content

Focus on concepts that help understand the system:

- Architecture and component interactions
- Data models and relationships
- Event flows and state transitions
- Service APIs and responsibilities
- Testing strategies

## Describe Responsibilities, Not Methods

**Why**: Method signatures are implementation details that change frequently and
duplicate what's already in the code.

**Rule**: Describe component responsibilities in natural language bullet points, not
method tables.

Use Mermaid diagrams for:

- Architecture overviews (graph TB)
- Class relationships (classDiagram)
- Database schemas (erDiagram)
- Sequence flows (sequenceDiagram)
- State machines (stateDiagram-v2)

## Prefer Diagrams Over Text

**Why**: Diagrams are more expressive and easier to scan. Duplicating the same
information in text adds maintenance burden without value.

**Rule**: When a diagram clearly conveys the information, don't add redundant text that
says the same thing.

## User Documentation Content

Focus on practical usage:

- Feature overview and use cases
- Step-by-step guides
- Configuration options
- Troubleshooting sections
