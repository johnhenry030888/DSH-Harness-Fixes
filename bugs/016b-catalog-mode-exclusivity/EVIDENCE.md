# EVIDENCE — bug 016b (`catalog` mode exclusivity)

## 1. Static gate

```
$ ./bugs/016b-catalog-mode-exclusivity/scripts/check.sh
bug-016b fix PRESENT
$ ./bugs/016b-catalog-mode-exclusivity/scripts/reapply.sh     # idempotent
already present -- nothing to do
```

Round-trip on a scratch copy of the installed file (reverse the patch to the
016-only state, re-apply it, parse):

```
reverse-applied to the 016 state: OK
stacked round-trip node --check: OK
```

Markers asserted: the guard (`is mutually exclusive with`), its conflict list
(`const conflicting = [args.provider === void 0 ? void 0 :`), the guarded call
(`if (args.catalog === true) {`), and the base 016 query
(`function listAgentCatalog(ctx, exec)`).

## 2. Live verification (freshly booted process, 2026-09-26)

The running GUI process predated the patch, so the guard was exercised through a
second `dsh web` instance started by the bug-020 helper
(`dsh-local-session.mjs --preset orchestrator`, ephemeral port, real harness
home) — i.e. a process that loaded the patched bundle from disk. Session
`session-e0631e94-26d1-447a-b6fd-0ab5a87d8e2e`, prompt: call
`list_subagent_models` twice with the mixed arguments.

```
CALL list_subagent_models {"catalog":true,"provider":"opencode-go"}
RESULT Error: `catalog` is mutually exclusive with `provider` — omit the route
       query to read this layer's own catalog, or drop `catalog` to query routes

CALL list_subagent_models {"catalog":true,"provider":"opencode-go","model":"longcat-2.0"}
RESULT Error: `catalog` is mutually exclusive with `provider` and `model` — omit
       the route query to read this layer's own catalog, or drop `catalog` to
       query routes
```

The `tool/result` records carry the error text with `isError: true`; the model
relayed both strings verbatim (assistant turn 1 step 2).

**Positive paths unchanged** — session `session-379b2fbf-9848-4a5a-ade2-d6b921794b55`
(same helper, after the 020b update) reported:

```
turnCompleted: true, headerToolCount: 178
assistant: Call 1 (`{"catalog": true}`): `count` = 178, `names.length` = 178.
           Call 2 (`{"provider": "opencode-go"}`): 8 lines returned.
```

So the guard rejects only the mixed call: the standalone catalog query still
returns the authoritative `{count, names}` (178 = the layer's own advertised
count) and the standalone provider query still lists the 8 configured routes.

## 3. Design notes

- The guard names **only the arguments the caller passed**, so the message is
  actionable in both directions ("drop the route query" / "drop `catalog`").
- The tool description states the rule as well, so a model can avoid composing
  the mixed call at all.
- Bug 016's `count === names.length` observation from drill v14 (friction #6) is
  a property of the builder, not a defect: the independent evidence is the
  comparison with the caller's own `request/header` length, which is what the
  drill and this run used (178).
