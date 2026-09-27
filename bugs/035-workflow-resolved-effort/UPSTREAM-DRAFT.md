# Upstream draft — bug 035

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** Workflow run records omit the resolved reasoning effort, and an
adapter header can lack the `reasoningEffort` key entirely

**Body:**

Two halves of the same defect made an effort-matched workflow comparison
unfalsifiable:

1. `tool-workflow/agent-start` and `agent-end` records carry
   `requestedProvider`/`requestedModel` only. Drill v16 F5/v17 §2: a stage-1
   child silently ran at the lead's `max` while its sibling recorded `null`.
   Drill v26 §6 item 2 re-confirmed the gap on source basis.
2. `dsh-llm`'s call resolution materializes `reasoningEffort` only when the
   caller requested one or the adapter exposes a model default. Drill v19 §5
   item 2 / v25 §5 item 2: one sibling's `request/header` had **no
   `reasoningEffort` key at all** (longcat-2.0) while its pair carried `max`,
   so "effort-matched by model choice" could not be checked from the
   transcript.

Proposal:

1. Record `resolvedEffort` plus `effortSource` (`pinned` | `inherited` |
   `default` | `unknown`) on both workflow run records, resolved from the
   child's own request header when present, else from creation-time
   resolution (child options + parent header + adapter default); never omit
   the fields — unresolvable is `{resolvedEffort: null, effortSource:
   "unknown"}`.
2. Make every adapter's request header carry an explicit `reasoningEffort`:
   when a reasoning-capable model has no requested level and no adapter
   default, materialize the `"default"` sentinel, and have adapters treat it
   as "no explicit effort" so wire behaviour is unchanged.
