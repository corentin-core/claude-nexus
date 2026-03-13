## Testing

**Why**:
- Tests document expected behavior
- Regressions are caught before they reach production

**Rule**: ALWAYS add or update tests when changing behavior.

**Rule**: NEVER disable or skip tests without a comment explaining why.

```python
# BAD — skipping without reason
@pytest.mark.skip
def test_calculate_total():
    ...

# GOOD — skip with explanation and issue link
@pytest.mark.skip(reason="Flaky on CI, see #1234")
def test_calculate_total():
    ...
```
