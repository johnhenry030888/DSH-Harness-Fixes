# Evidence — bug 008

## Primary evidence (reports)

- `~/Desktop/orchestrator-drill-report-v4.md` §7 (Phase 5) and §14.2 finding 2:
  - the fork child reported its context began with the task prompt and nothing
    else;
  - the lead session `session-7f17108c-46ab-4bdf-b19b-3e0b5df2dd77` ran as one
    turn (`turn/start` seq 7, the only `turn/end` seq 482); the fork call
    fired at **seq 66**, so `completedTurnPrefix()` was empty by construction.
- `~/Desktop/orchestrator-drill-report-v4.md` §9 friction 5: "Forked child
  reported its context began with the task prompt; no earlier turns or
  artifacts … Clarify normal vs. fork semantics in the tool description, or add
  a positive-control probe."
- `~/Documents/Projects/DSH/ORCHESTRATOR-OPTIMIZATION-PLAN.md` §14.3 gap 3.
- `~/Desktop/orchestrator-drill-prompt-v5.md` Phase 5 positive control
  ("fork positive control: a fact established in THIS turn that a cold fork
  cannot know").

## Source references (pristine 0.1.5-rc.2)

- `@deepseek-ai/dsh-subagent-fork-in-process/lib/index.js` —
  `completedTurnPrefix()` returns `[]` without a `turn/end`;
  `start()`/`prepareContinuable()` pass no seed and no diagnostic.
- `@deepseek-ai/dsh-subagent-in-process-driver/lib/index.js` —
  `activationBoundary = SessionLogOffset(seed?.length ?? 0)`; the child session
  records `inheritedEventCount` and `isSeeded`.
- `@deepseek-ai/dsh-tool-subagent/lib/index.js` — `providerWording(true)`
  described the fork inheritance.

## Live re-verification (2026-09-25, installed bundle with the fix)

### Module-level (`scripts/seed-check.mjs`, installed fork provider)

```json
{
  "emptySeed": "no seed",
  "seededCount": 4,
  "warnings": [
    "subagent-fork-in-process: fork child of session session-open inherits 0 events — the parent has no completed turn yet (its current turn is still open), so the child starts with no inherited conversation; put the needed context in the prompt or continue an existing child with send_message instead"
  ]
}
SEED-CHECK PASS
```

The completed-turn parent produced a 4-event seed (`events.slice(0,
lastEnd.seq + 1)`) and no warning.

### Live mid-turn fork (headless, plain profile)

Lead: `dsh --profile headless "Use the subagent_fork tool …"`, exit 0.

Child session `6b6515f0-0793-49f6-b48d-4faa2220c8aa` (forked at the lead's
first turn):

- stored header: `"isSeeded":false`, `"origin":"subagent"`,
  `"delegationDepth":1`;
- `session/end-seed` events: **0** (the durable marker of an inherited prefix);
- `subagent/descriptor`: `{"version":3,"mode":"one-shot","provider":"fork",…}`.

The child did not know the token the parent wrote that turn (it read the file
it was pointed at, as instructed). The warning is captured by the module-level
check because the plain headless profile has no logger sink.

### Tool wording

`providerWording(true)` now returns (excerpt):

> "… a child agent seeded with the parent's completed turns up to the last
> `turn/end`. The current in-flight turn is never inherited, so forking while
> you are still inside your first turn gives the child NO prior conversation —
> put the facts it needs in the prompt, or continue an existing child with
> `send_message` instead. …"

Checked by `scripts/check.sh` markers:
`seeded with the parent's completed turns up to the last` and
`gives the child NO prior conversation`.
