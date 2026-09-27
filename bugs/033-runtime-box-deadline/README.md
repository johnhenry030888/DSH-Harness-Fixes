# Bug 033 — a delegation deadline the runtime enforces (`boxSeconds`)

Severity: **high** (lanes that overrun produce nothing; two v26 lanes lost a
whole sweep and the entire measurement bundle). Local fix: **APPLIED** to the
`dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

Every drill since v23 lost work to lanes that overran their declared box:

- **v23 §3** (verify lane): a 300 s box became ~600 s, `SELF_ABORT` was
  written, and **0 of 19 mutants executed**.
- **v24 §3**: three lanes overran 2×/1.6×/1.8×, two were interrupted, two
  returned nothing; the one lane whose job ran inside a deadline-checked loop
  finished **19 mutants in 13 s**.
- **v26 §3** and §7 F1/F2: two in-driver lanes produced **no artifact at all**
  after 662 s and 323 s; the run lost one of two required mutation sweeps and
  the entire token/share/measurement bundle. v26's own recommendation:
  "A `timeout <box>` wrapper plus a mandatory first-line progress write
  converts an opaque hang into a partial table."

The box existed only as prompt discipline and a self-written sentinel; nothing
in the runtime stopped a child or returned its partial output.

## Root cause

No delegation deadline existed anywhere in the runtime: neither the
`tool-subagent` row/call surface nor `dsh-subagent`'s one-shot or continuable
lifecycle accepted or enforced one. A child could run forever, and an
interrupted child's tool result was the generic "run was cancelled" text with
no box provenance.

## Fix design

1. **Option surface** (`dsh-tool-subagent/lib/index.js`): the row config gains
   `boxSeconds: z.natural().min(5)` and every delegation call gains
   `box_seconds` (whole seconds, ≥ 5; per call overrides the row default).
   The value rides the existing `SubagentStartRequest` into the service.
2. **One-shot enforcement** (`dsh-subagent/lib/index.js`): `armOneShotBox()`
   arms a timer on the published run; at expiry it appends the durable
   `subagent/box {boxSeconds, elapsedSeconds, hit: true}` record to the child
   and cancels the local child the way `interrupt_agent` does. The run carries
   `run.box`; `settleForegroundRun`'s `boxStopError()` reports
   `agent "<id>" hit its <n> s box and was interrupted after <m> s; partial
   output follows: …` instead of a bare cancellation.
3. **Continuable enforcement** (`dsh-subagent`): the manager's
   `armBox(parent, childId, boxSeconds)` records the same event and calls
   `interrupt(childId, {kind:"ancestor", agent: parent})`; the timer is cleared
   at settlement. `createActivationObserver.capture()` folds the record into
   the terminal state and `settlementSummary()` says the stop was a box hit:
   `Background subagent <id> hit its <n> s box and was interrupted after <m> s
   — it did not finish; its partial output follows.` The settlement notice's
   source also carries the `box` field.
4. **Independent of `maxDepth`/`toolFilter`**; existing interrupt semantics are
   untouched (the box is one more caller of the same cancel path).

## Rejected alternatives

- **Prompt-discipline / external `timeout` only.** That is the bug: v25/v26
  proved prompt boxes are ignored and the run cannot see a partial table.
- **Fold the box into `maxDepth`/`toolFilter`.** Different concerns; a box is
  a time budget, not a capability mask.
- **Kill the child's process instead of interrupting the turn.** `interrupt_agent`
  is the documented stop; the box must behave identically so a partial result
  and the settlement path are preserved.
- **Report only the elapsed seconds with no partial text.** The drills lost
  artifacts because no partial was returned; the partial text is the point.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-box-deadline.patch`; stacks on
  031/032/036 of the same file)
- `@deepseek-ai/dsh-subagent/lib/types/types.d.ts`
  (`patches/dsh-subagent-box-types.patch`; stacks on bug 033's service patch)
- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-box-option.patch`; stacks on bug 019)
- `@deepseek-ai/dsh-session/lib/index.js` (the `subagent/box` event type is
  provisioned by bug 031's `dsh-session-known-subagent-events.patch`)

## Acceptance evidence

`EVIDENCE.md`: live `dsh --profile headless` probes in a scratch home, both the
per-call override (row 30 s, call 15 s) and the row default (15 s), each
returning in ~31 s with the box message, the partial-output contract, and a
durable `subagent/box {boxSeconds: 15, elapsedSeconds: 15, hit: true}` record
in the child's transcript. `scripts/check.sh` exit 1 pre-fix, 0 post-fix;
patches round-trip.
