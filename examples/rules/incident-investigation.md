# Incident Investigation

## Absence of Logs is Ambiguous

**Why**: Many components only log errors, not successful operations. "No logs after
event X" can mean the system crashed OR it recovered and works fine.

**Rule**: ALWAYS consider both interpretations of absent logs:

- Absence of error logs = system might be working (successful operations aren't logged)
- Absence of error logs = system might have stopped (process crashed)

To distinguish, look for **positive evidence**: other components' log activity, parallel
systems reaching the same endpoints, state transitions after the event.

## Never Post Externally with Unverified Claims

**Why**: Incorrect root cause analysis in public channels erodes trust and can lead to
wrong actions.

**Rule**: NEVER post on external channels until every key claim is backed by concrete
evidence. If a claim is a deduction (not directly observed), either verify it first or
mark it explicitly as uncertain.

```
# BAD - unverified deduction posted as fact
"The service never retried after the network change"

# GOOD - verified with evidence
"Logs show connection errors every 4s for service A but nothing for service B
after 12:03:53 — this likely means B recovered"

# ALSO GOOD - explicit uncertainty
"We're not sure yet whether the service retried — investigating"
```

## Frame the Problem Before Deep-Diving

**Why**: Confusing a consequence with the root cause leads to hours of wasted
investigation.

**Rule**: Before reading any code, explicitly state your root cause hypothesis and
distinguish cause from consequence:

1. **Write the hypothesis**: "I believe X causes Y"
2. **Separate cause and consequence**: if removing the "cause" wouldn't fix the problem,
   it's a consequence
3. **Validate with the user** before spending time on code analysis

## Never Assume Cost Without Measuring

**Why**: "Lightweight" events or "trivial" code paths can have surprising overhead.
Aggregated costs matter: 1ms x 100 events = 100ms.

**Rule**: NEVER estimate a code path cost as "trivial" or "~1ms" without evidence:

1. Look for **measured data** first (metrics, timing logs)
2. If no data exists, **instrument before concluding** — don't guess
3. Consider **aggregated cost**: cost per event x events per cycle x cycles per second

## Start with the Simplest Hypothesis

**Why**: Users report what they see in logs, not necessarily what's actually broken.
Misleading log messages are a common source of false incident reports.

**Rule**: ALWAYS evaluate simple hypotheses first before investigating complex ones:

1. Did the user misinterpret a log message? (false positive, init noise, etc.)
2. Is the system actually working despite the reported error?
3. Is this a known/expected behavior?

Only after ruling these out, investigate deeper.
