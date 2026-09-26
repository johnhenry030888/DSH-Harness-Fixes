# Bug 014 — workflow run records drop the child's spawn error

Severity: **medium**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

Three route rejections inside `workflow` runs produced
`tool-workflow/agent-end {"outcome":"failed"}` with **no error text and no
requested route**, and failed pins persist no child session dir — the failure is
unattributable from the run record. Drill v6 §7, v7 §7, v8 §7 all recorded the
same bare record:

```
tool-workflow/agent-start {"runId":"499f0232…","seq":1,"label":"reject-pin","phase":"reject-pin","childId":"91e94c89…"}
tool-workflow/agent-end   {"runId":"499f0232…","seq":1,"outcome":"failed"}
tool-workflow/run-end     {"runId":"499f0232…","stopReason":"completed"}
```

## Root cause

Four independent gaps in one path:

1. `dsh-subagent-in-process-driver`'s `readResult` never populated the seam's
   `SubagentResult.diagnostic`, although the child's `turn/end` reason carries
   the LLM failure verbatim (`{message, code}`). Consumers that already support
   diagnostics (e.g. the direct `subagent` tool) received nothing.
2. `dsh-workflow-worker-thread`'s host `startChild` snapshot dropped
   `diagnostic` when forwarding `ChildSettled` across the worker boundary.
3. The worker's `agent()` emitted `workflow/agent-end` with `{seq,label,phase,
   childId,outcome}` only — no error, no requested route.
4. `dsh-tool-workflow`'s recorder wrote only those four fields into the durable
   `tool-workflow/*` events.

## Fix design

Carry the failure into the run record, end to end:

- driver: `turnDiagnostic(reason)` renders `message (CODE)` for an `error`
  turn/end and sets `SubagentResult.diagnostic` on non-completed results;
- host: forward `diagnostic` in the `ChildSettled` snapshot;
- worker: `agent-start`/`agent-end` carry `requestedProvider`/`requestedModel`
  from `opts`, and a failed end carries `error` (the diagnostic where one
  exists, else `child ended with stopReason "<reason>"` or the rendered
  rejection);
- recorder: `tool-workflow/agent-start`/`agent-end` persist those fields;
- `dsh-workflow`'s payload types document them.

No secrets: the requested route is the two ids the caller wrote, and the
diagnostic is the provider-authored failure text the seam already bounds
(4096 bytes, no tool inputs/file contents/credentials).

## Rejected alternatives

- **Read the child session transcript from the recorder.** The recorder is a
  projection listener with no session-query service; reaching into another
  package's storage would couple the recorder to persistence.
- **Emit a synthetic `agent-start` for a start that never published a child.**
  The observed rejection path does publish a child (descriptor + session) that
  then fails its first request; the ledger's exactly-once pairing must not be
  changed for a path that already emits a real start.
- **Change `agent()` to throw for a failed child instead of resolving `null`.**
  That is the tool contract (`agent()` resolves `null` on child failure;
  `.filter(Boolean)` is documented). The acceptance for 014 is the run record;
  the script-visibility question is left to the engine's documented contract.
  (Residual, noted for reviewers: a rejected pin still reaches the script as
  `null`; the run record is now the attributable evidence.)

## Files patched

- `@deepseek-ai/dsh-subagent-in-process-driver/lib/index.js`
  (`patches/dsh-subagent-in-process-driver-diagnostic.patch`, stacks on 013)
- `@deepseek-ai/dsh-workflow-worker-thread/lib/index.js`
  (`patches/dsh-workflow-worker-thread-forward-diagnostic.patch`, stacks on 006)
- `@deepseek-ai/dsh-workflow-worker-thread/lib/worker.cjs`
  (`patches/dsh-workflow-worker-thread-agent-end-error.patch`)
- `@deepseek-ai/dsh-tool-workflow/lib/index.js`
  (`patches/dsh-tool-workflow-run-record-error.patch`)
- `@deepseek-ai/dsh-workflow/lib/types/types.d.ts`
  (`patches/dsh-workflow-agent-info-types.patch`)

## Acceptance evidence

See `EVIDENCE.md`. A live rejected pin inside a workflow now records:

```
tool-workflow/agent-start {"runId":"7500cc87…","seq":1,"label":"reject-pin","phase":"reject",
                           "childId":"aee7763e…","requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
tool-workflow/agent-end   {"runId":"7500cc87…","seq":1,"outcome":"failed",
                           "error":"pi-ai provider \"opencode-go\" has no configured model \"glm-5.3-flash\" (UNKNOWN_MODEL)",
                           "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
```
