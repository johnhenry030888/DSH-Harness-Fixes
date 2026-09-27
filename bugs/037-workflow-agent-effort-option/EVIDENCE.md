# Evidence — bug 037

## Primary evidence (pre-fix)

- Drill **v16 F5 / v17 §2**: a stage-1 workflow child silently ran at the
  **lead's** `max` while its sibling recorded `null`; the run records carried
  `requestedProvider`/`requestedModel` only and no stage could express an
  effort.
- Drill **v19 §5 item 2 / v25 §5 item 2**: the "effort-matched" candidate pair
  ran unmatched because both `agent()` stages inherited the lead's effort (one
  header had no `reasoningEffort` key at all); 035 closed the record half, but
  the pinning half was still missing.
- Drill **v21 §7 R1**: "`agent()` accepts no effort → a pinned merge must
  leave the workflow" — v18 paid a 72.8 s inter-stage handoff to run its merge
  as a directly-delegated child at `low`, and v19's in-workflow merge
  inherited the lead's `max` (644.4 s barrier, both workflow bars missed).
- Drill **v26 §6 item 2**: re-confirmed `effort` was deferred by the worker
  (`agent() option "effort" is deferred …`).

## Fix markers (checked by `scripts/check.sh`)

- `worker.cjs`: `...opts.effort !== void 0 ? { agentOptions: { reasoningEffort:
  opts.effort } } : {}`, `...opts.effort !== void 0 ? { requestedEffort:
  opts.effort } : {}`, `agent() option "effort" must be a non-empty string`,
  `(supported: label, phase, schema, provider, model, effort)`,
  `...record.effort !== void 0 ? { effort: record.effort } : {},`.
- `dsh-workflow-worker-thread/lib/index.js`:
  `request.agentOptions?.reasoningEffort !== void 0 ? { agentOptions: {` and
  the `reasoningEffort` spread into the child's creation options.
- `dsh-tool-workflow/lib/index.js`:
  `...agent.requestedEffort === void 0 ? {} : { requestedEffort:
  agent.requestedEffort },` and the description sentence
  `An effort the target model does not advertise fails that stage loudly with
  the platform…`.
- Types: `requestedEffort?: string;` (`dsh-workflow`),
  `readonly requestedEffort?: string;` (tool-workflow record types),
  `agentOptions?: { reasoningEffort?: string };` (child-start request).

## Before/after check output

```
$ (pre-037, after reversing the six patches on the installed bundle)
missing: ...opts.effort !== void 0 ? { agentOptions: { reasoningEffort: opts.effort } } : {} (in lib)
missing: ...opts.effort !== void 0 ? { requestedEffort: opts.effort } : {} (in lib)
missing: agent() option "effort" must be a non-empty string (in lib)
missing: (supported: label, phase, schema, provider, model, effort) (in lib)
missing: ...record.effort !== void 0 ? { effort: record.effort } : {}, (in lib)
missing: request.agentOptions?.reasoningEffort !== void 0 ? { agentOptions: { (in lib)
missing: ...request.agentOptions?.reasoningEffort !== void 0 ? { reasoningEffort: request.agentOptions.reasoningEffort } : {} (in lib)
missing: ...agent.requestedEffort === void 0 ? {} : { requestedEffort: agent.requestedEffort }, (in lib)
missing: An effort the target model does not advertise fails that stage loudly with the platform (in lib)
missing: requestedEffort?: string; (in types)
missing: readonly requestedEffort?: string; (in types)
missing: agentOptions?: { reasoningEffort?: string }; (in types)
bug-037 fix MISSING
exit=1

$ (reapply.sh, which chains 006 -> 028 -> 035 as no-ops then applies the six patches)
fix missing -- applying patches...
already present -- nothing to do
already present -- nothing to do
already present -- nothing to do
bug-037 fix PRESENT
re-applied OK -- restart the DSH host to load it
exit=0

$ (reapply.sh again)  already present -- nothing to do   (exit 0, idempotent)
```

## Live probe (scratch `DSH_HOME`, real `~/.dsh` untouched)

`scripts/effort-option-probe.sh` runs one four-stage workflow through the
shipped headless profile: stage-one pinned `opencode-go/longcat-2.0 @ low`,
stage-two with no route/effort (inherits the lead's
`deepseek-v4.1-flash @ max`), stage-three pinned at the unadvertised `extreme`
inside a script try/catch, stage-four calling `agent(..., {effort: 5})`.

```
$ bash bugs/037-workflow-agent-effort-option/scripts/effort-option-probe.sh
bug 037 live probe — scratch home /tmp/orch-drill-037/home

    | The user wants me to call the workflow tool exactly once with the exact script body. Then reply with one line. Let me do that.
    | 
    | Note there's a potential conflict: the instruction says "Do not call any other tool." So I should just call workflow once and then reply.
    | 
    | Let me copy the script verbatim.
    | EFFORT-OPTION-PROBE-DONE {"stage1":"OK","stage2":"OK","stage3Error":{"code":"UNSUPPORTED_REASONING_EFFORT","message":"child agent failed: provider \"opencode-go\" model \"longcat-2.0\" does not support reasoning effort \"extreme\" — supported: off, minimal, low, medium, high (UNSUPPORTED_REASONING_EFFORT)"},"stage4Error":{"code":"INVALID_ARGUMENT","message":"agent() option \"effort\" must be a non-empty string"}}
  PASS  the lead completed the workflow run

agent-start records:
  seq=1 label=stage-one requested=opencode-go/longcat-2.0 requestedEffort='low' resolvedEffort='low' effortSource='pinned'
  seq=2 label=stage-two requested=None/None requestedEffort=None resolvedEffort='max' effortSource='inherited'
  seq=3 label=stage-three requested=opencode-go/longcat-2.0 requestedEffort='extreme' resolvedEffort='extreme' effortSource='pinned'
agent-end records:
  seq=1 outcome=completed errorCode=None
  seq=2 outcome=completed errorCode=None
  seq=3 outcome=failed errorCode='UNSUPPORTED_REASONING_EFFORT'
workflow return value (from the lead's final line):
  {"stage1": "OK", "stage2": "OK", "stage3Error": {"code": "UNSUPPORTED_REASONING_EFFORT", "message": "child agent failed: provider \"opencode-go\" model \"longcat-2.0\" does not support reasoning effort \"extreme\" — supported: off, minimal, low, medium, high (UNSUPPORTED_REASONING_EFFORT)"}, "stage4Error": {"code": "INVALID_ARGUMENT", "message": "agent() option \"effort\" must be a non-empty string"}}
child request headers:
  opencode-go/deepseek-v4.1-flash reasoningEffort='max'
  opencode-go/longcat-2.0 reasoningEffort='low'

  PASS  exactly three children started (stage-four never spawns)
  PASS  stage-one records requestedEffort/resolvedEffort low with effortSource pinned
  PASS  stage-two records no requestedEffort and the lead's max as inherited
  PASS  stage-three records the requested extreme effort as pinned and fails with the platform code
  PASS  stage-three's failure names the advertised ladder
  PASS  exactly two child headers exist (stage-three failed before its header)
  PASS  a longcat-2.0 child header carries reasoningEffort low
  PASS  the route-inheriting child header carries the lead's max
  PASS  stage-four rejects effort:5 with INVALID_ARGUMENT naming the option
  PASS  both positive stages returned the child's text and the negative stages returned no text

bug-037 live probe: PASS
scratch home kept for inspection: /tmp/orch-drill-037
```

## Raw run records (pasted from the lead's session transcript)

```
{"type": "tool-workflow/agent-start", "seq": 20, "time": 1790545953370, "data": {"runId": "3eaca936-05b6-478d-92c4-7817323a1241", "seq": 1, "label": "stage-one", "childId": "89bba804-240d-4434-8c5b-6b209f3cf6ed", "requestedProvider": "opencode-go", "requestedModel": "longcat-2.0", "requestedEffort": "low", "resolvedEffort": "low", "effortSource": "pinned"}}
{"type": "tool-workflow/agent-end", "seq": 21, "time": 1790545956219, "data": {"runId": "3eaca936-05b6-478d-92c4-7817323a1241", "seq": 1, "outcome": "completed", "requestedProvider": "opencode-go", "requestedModel": "longcat-2.0", "requestedEffort": "low", "resolvedEffort": "low", "effortSource": "pinned"}}
{"type": "tool-workflow/agent-start", "seq": 23, "time": 1790545956279, "data": {"runId": "3eaca936-05b6-478d-92c4-7817323a1241", "seq": 2, "label": "stage-two", "childId": "c02d2e5e-8b5c-42e9-80ad-2ec6d2d213f8", "resolvedEffort": "max", "effortSource": "inherited"}}
{"type": "tool-workflow/agent-end", "seq": 24, "time": 1790545958469, "data": {"runId": "3eaca936-05b6-478d-92c4-7817323a1241", "seq": 2, "outcome": "completed", "resolvedEffort": "max", "effortSource": "inherited"}}
{"type": "tool-workflow/agent-start", "seq": 26, "time": 1790545958519, "data": {"runId": "3eaca936-05b6-478d-92c4-7817323a1241", "seq": 3, "label": "stage-three", "childId": "dd2b5a95-e1a6-4ffd-93ed-ee5b0f77514a", "requestedProvider": "opencode-go", "requestedModel": "longcat-2.0", "requestedEffort": "extreme", "resolvedEffort": "extreme", "effortSource": "pinned"}}
{"type": "tool-workflow/agent-end", "seq": 27, "time": 1790545958541, "data": {"runId": "3eaca936-05b6-478d-92c4-7817323a1241", "seq": 3, "outcome": "failed", "error": "provider \"opencode-go\" model \"longcat-2.0\" does not support reasoning effort \"extreme\" — supported: off, minimal, low, medium, high (UNSUPPORTED_REASONING_EFFORT)", "errorCode": "UNSUPPORTED_REASONING_EFFORT", "requestedProvider": "opencode-go", "requestedModel": "longcat-2.0", "requestedEffort": "extreme", "resolvedEffort": "extreme", "effortSource": "pinned"}}
```

Raw child headers (each child's own `request/header`):

```
child 89bba804-240d-4434-8c5b-6b209f3cf6ed: {"provider": "opencode-go", "model": "longcat-2.0", "reasoningEffort": "low"}
child c02d2e5e-8b5c-42e9-80ad-2ec6d2d213f8: {"provider": "opencode-go", "model": "deepseek-v4.1-flash", "reasoningEffort": "max"}
child dd2b5a95-e1a6-4ffd-93ed-ee5b0f77514a: (no request/header — its first prepareCall rejected before the header is logged)
```

The stage-three failure is **early and loud**: its `agent-start` (seq 26,
t=1790545958519) is followed 22 ms later by the failed `agent-end` (seq 27,
t=1790545958541) carrying the platform's own
`UNSUPPORTED_REASONING_EFFORT` code and the advertised ladder
(`off, minimal, low, medium, high`) — no fallback, no retry, no silent stage.

## Patch round-trip

```
forward apply (six patches onto the pre-037 baseline) == installed bundle: OK
reverse apply (six patches reversed) == pre-037 baseline: OK
ROUNDTRIP PASS

(installed) reverse the six patches -> check.sh MISSING (exit 1)
reapply.sh (chains 006/028/035, then applies six) -> check.sh PRESENT (exit 0)
reapply.sh second run -> "already present -- nothing to do" (exit 0)
```

## Verification limits (disclosed)

- The unadvertised-effort case fails at the child's **first LLM request**, not
  before the child session is published (README documents the route): the
  `agent-start` record exists and carries the pinned value, and the failure
  lands ~22 ms later. A caller that needs a pre-spawn refusal must inspect the
  ladder itself via `list_subagent_models({provider, model})` first.
- `effort` is recorded but not length- or vocabulary-checked beyond
  non-emptiness: the platform's ladder is the authority, and its rejection
  names every advertised level.
- The probe pins `longcat-2.0 @ low`, which that model advertises (its ladder
  is `off, minimal, low, medium, high` per the rejection text); a different
  deployment's ladder is the platform's to report, not this patch's.
