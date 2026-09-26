# Bug 014b — `workflow` `agent()` failure: document the run-record lookup

Severity: **medium** (trap in the script-authoring contract). Local fix:
**APPLIED** to the `dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**
(follow-up to bug 014, which landed the run-record fields).

## Symptoms

Bug 014 made a failed `agent()` inside `workflow` attributable from the run
record (`agent-end` carries `error` + `requestedProvider`/`requestedModel`),
but the **script still receives a bare `null`**:

```json
{"runId":"a75834b3-…","seq":1,"outcome":"failed",
 "error":"pi-ai provider \"opencode-go\" has no configured model \"glm-5.3-flash\" (UNKNOWN_MODEL)",
 "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
```

while the script saw `null` (`scriptSaw:"null"`, `typeofResult:"object"`). A
workflow author cannot distinguish "the requested route was rejected" from
"the child returned nothing" without out-of-band inspection — drill v10 §8
(Phase 7) and §10 friction #4; v9 §9 #2.

## Root cause

The engine's documented contract is `agent()` resolves `null` on child
failure (`.filter(Boolean)` is the intended idiom), so the return value is
deliberately lossy. The tool description said only "Resolves `null` when the
child fails" and never told the script author where the attributable failure
went — even though bug 014 had just put a precise `error` on the run record.

## Fix design

The task allowed either a typed return or documenting the run-record lookup
prominently; the engine's `null` contract is deliberate (changing it would
break `filter(Boolean)` scripts and is rejected — see below), so the
description now says, in the same bullet that documents the `null`:

> Resolves `null` when the child fails (filter with `.filter(Boolean)`) — the
> return value deliberately says nothing about WHY, so a rejected route and a
> child that produced nothing are both `null`. To attribute a failure, read
> the run record, never the return value: every stage emits
> `workflow/agent-start`/`agent-end` records in the caller's run history
> whose `agent-end` carries the `error` diagnostic plus
> `requestedProvider`/`requestedModel` when the child failed before producing
> output.

This is a single description edit; no engine behavior changes.

## Rejected alternatives

- **Return `{ok:false, error:{code,message}}` from `agent()`.** Breaks the
  documented engine contract outright: existing scripts treat any truthy
  return as the child's output, and `filter(Boolean)` — the documented idiom —
  would stop filtering failures. A discriminated result needs an engine-wide
  API version and belongs in the engine's own design, not this batch.
- **Add a `strict` option that throws.** Same API-surface problem, and the
  014 acceptance was scoped to the run record; a behavior flag without the
  engine's own versioning is not seam-clean.
- **Only document in the workflow package's types.** Script authors write
  plain JS in the tool call; the tool description is the model-facing spec,
  and it is what the calling model actually reads before writing the script.

## Files patched

- `@deepseek-ai/dsh-tool-workflow/lib/index.js`
  (`patches/tool-workflow-agent-null-provenance.patch`, applies to pristine
  sources with or without bug 014's recorder patch)

## Acceptance evidence

See `EVIDENCE.md`. Live (headless profile): the lead quoted the new
description passage verbatim when asked what `agent()` resolves to on failure
and what to read to attribute it. `check.sh` exits 1 pre-fix / 0 post-fix.
