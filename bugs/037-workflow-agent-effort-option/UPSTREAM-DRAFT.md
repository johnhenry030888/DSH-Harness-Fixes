# Upstream draft — bug 037

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `workflow`'s `agent()` cannot pin a per-stage reasoning effort, so
an effort-pinned stage silently runs at the lead's effort

**Body:**

The workflow engine resolves a stage child's reasoning effort at creation
(`resolveChildEffort()`) and, since bug 035, records it as
`resolvedEffort`/`effortSource` on `workflow/agent-start`/`agent-end`. But the
script surface cannot express one: `dsh-workflow-worker-thread`'s
`readAgentOptions()` rejects `effort` as a deferred option
(`agent() option "effort" is deferred and not supported by this engine`), and
`ChildStartRequest` has no field to carry it. Every stage therefore inherits
the lead's effort.

Drill v16 F5/v17 §2 measured a stage child silently at the lead's `max` while
its sibling recorded `null`; v19 §5 item 2/v25 §5 item 2 could not run an
"effort-matched" candidate pair at all; v21 §7 R1 concluded "`agent()` accepts
no effort → a pinned merge must leave the workflow", which cost v18 a 72.8 s
inter-stage handoff to run its merge as a directly-delegated child at `low`,
and left v19's in-workflow merge at the lead's `max` (both workflow time bars
missed).

Proposal:

1. Promote `effort` from the deferred set to the supported `agent()` options
   (value: a non-empty string; anything else rejects with `INVALID_ARGUMENT`
   naming the option). Keep `isolation`/`agentType` deferred.
2. Forward it as the child's pinned creation option
   (`agentOptions.reasoningEffort` on the child-start request →
   `resolveChildEffort()`'s first branch), so the child runs at that effort and
   the run record shows `effortSource: "pinned"` beside `resolvedEffort`.
3. Record the requested value (`requestedEffort`) on
   `agent-start`/`agent-end` next to `requestedProvider`/`requestedModel`, so
   the full pinned route is readable from the run record.
4. An effort the target model does not advertise fails that stage loudly with
   the platform's own `UNSUPPORTED_REASONING_EFFORT` (surfaced as the
   `WorkflowError`/`errorCode` the script can catch and branch on, and on
   `agent-end`) rather than falling back to a default. Do not clamp or alias.
5. Document the option in the tool description; the three type files carry
   `requestedEffort`/`agentOptions`.
