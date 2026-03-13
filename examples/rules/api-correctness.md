# API Correctness

When implementing or reviewing code that interacts with REST APIs, read the API
documentation first, then verify correctness before writing code.

## Verify response structure

Before parsing API responses, confirm:

1. Does the endpoint return a list or an object containing a list?
2. What are the exact field names?
3. How is the response structured?

```python
# BAD - assumes API returns list directly
def get_devices(self):
    return self._get("/api/devices")  # Actually returns {"devices": [...]}

# GOOD - matches actual API response
def get_devices(self):
    data = self._get("/api/devices")
    return data.get("devices", [])
```

## Check exact field names

Do not guess field names. Verify against the API spec:

```python
# BAD - guessed field name
metadata = response["samples_metadata"]

# GOOD - verified against API spec / OpenAPI
metadata = response["metadata"]["samples"]
```

## Verify with real data when possible

```bash
# Check actual API response structure
curl -s http://host/api/endpoint | jq 'keys'
curl -s http://host/api/endpoint | jq '.[0] | keys'
```
