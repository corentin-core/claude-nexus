---
paths:
  - "**/*.py"
---

# Python Code Quality

These patterns prevent common review comments. Follow them strictly.

## Type hints - Required everywhere

All functions must have complete type annotations:

```python
# BAD
def calculate_total(items, tax_rate):
    return sum(i.price for i in items) * (1 + tax_rate)

# GOOD
def calculate_total(items: tuple[Item, ...], tax_rate: Decimal) -> Decimal:
    return sum(i.price for i in items) * (1 + tax_rate)
```

## Read-only parameters: use Sequence, not list

**Why**: `list[T]` in a parameter signature implies the function may mutate the list.
For read-only access, use `Sequence[T]` (supports list, tuple, and other sequences) or
`Iterable[T]` (if iterating only once).

**Rule**: For function parameters that are only read (not mutated), use
`collections.abc.Sequence` or `collections.abc.Iterable` instead of `list` or `tuple`.

```python
# BAD - implies mutation
def compute_total(entries: list[Entry]) -> float:
    return sum(e.value for e in entries)

# GOOD - signals read-only intent
from collections.abc import Sequence

def compute_total(entries: Sequence[Entry]) -> float:
    return sum(e.value for e in entries)
```

| Need | Type |
|------|------|
| Random access or multiple iterations | `Sequence[T]` |
| Single iteration, or materialized into tuple/list early | `Iterable[T]` |
| Will modify the collection | `list[T]` |

## Return tuples, not lists

**Why**: Tuples are immutable and signal that the caller shouldn't modify the result.

**Rule**: ALWAYS use `tuple[T, ...]` instead of `list[T]` for function return values.

```python
# BAD
def get_items(self) -> list[Item]:
    return list(self._items)

# GOOD
def get_items(self) -> tuple[Item, ...]:
    return tuple(self._items)
```

## NamedTuple vs frozen dataclass

| Use case                                | Choice                    |
| --------------------------------------- | ------------------------- |
| Pure data, no methods                   | NamedTuple                |
| Need unpacking `a, b = obj`             | NamedTuple                |
| Need indexing `obj[0]`                  | NamedTuple                |
| Custom operators (`__add__`, `__mul__`) | `@dataclass(frozen=True)` |
| Complex default values                  | `@dataclass(frozen=True)` |

**Rule**: Use `NamedTuple` for simple records. Use `@dataclass(frozen=True)` when you
need custom methods, especially arithmetic operators.

## Domain objects over primitives

Use domain objects instead of primitive types:

```python
# BAD
def get_results(self) -> dict[str, date]:
    ...

# GOOD
def get_results(self) -> tuple[Result, ...]:
    ...
```

## Single source of truth

Don't maintain two representations of the same data:

```python
# BAD - redundant index
self._items: tuple[Item, ...] = items
self._items_by_id: dict[int, Item] = {i.id: i for i in items}

# GOOD - derive when needed
self._items: tuple[Item, ...] = items

def get_by_id(self, id: int) -> Item | None:
    return next((i for i in self._items if i.id == id), None)
```

## Encapsulation - Private by default

Attributes should be private unless there's a reason to expose them:

```python
# BAD
self.repository = SqliteRepository()

# GOOD
self._repository = SqliteRepository()
```

## No over-engineering

Keep it simple - don't add abstractions for one-time operations.

## Logging instead of print

Never use `print()` for user feedback in library code:

```python
# BAD
print(f"Processed {count} items")

# GOOD
logger.info("Processed %d items", count)
```

## Circular imports - Never work around silently

**Rule**: NEVER use `if TYPE_CHECKING:` to work around circular imports. Instead:

1. **Stop and report** the circular import to the user
2. **Analyze** which module depends on which
3. **Propose** a refactoring solution (extract common types, reorganize modules)

**Acceptable uses of TYPE_CHECKING**:

- Forward references within the same module (self-referential types)
- Avoiding heavy imports that are only needed for type hints (e.g., pandas, numpy)
