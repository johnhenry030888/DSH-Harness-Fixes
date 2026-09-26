# Bug 017 — termination notices carry no `stopTime`

Severity: **low**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

`interrupt_agent` on a running child produces the settlement notice

```
Background subagent ee1df1eb-… was stopped before it finished.
Its closing message:
```

with no stop timestamp anywhere in the payload. Drill v9 and v10 both had to
measure the stop tail from the child's own last session write, and v10 could
not distinguish "work stopped" from "notice sent" inside the notice — only
the envelope `time` of the notice event existed, which dates *delivery*, not
the stop (drill v10 §8 kill, §10 friction #6; v9 §9 #2).

## Root cause

`createActivationObserver.capture()` (dsh-subagent) snapshots only
`stopReason` and the final assistant output; `terminal()` returns that
snapshot (or a bare `{stopReason: "error"}` on teardown failure), and
`createSettlementMessage()` builds the notice from `stopReason` + `output`
only. The session event envelope already carries `time`, and the child's own
epoch suffix is available at capture time (`child.session.snapshotEvents(boundary)`),
so the timing facts existed but were dropped.

## Fix design

Carry two timing facts end to end, without changing the existing sentence:

- `stopTime` — epoch milliseconds at which the Activation's terminal state
  was captured (`Date.now()` in `capture()`; `Date.now()` on the
  teardown-failure fallback). This is the "work stopped" moment.
- `lastActivityTime` — epoch milliseconds of the child's own last recorded
  session event in the settling epoch (`own.at(-1)?.time`), present only when
  the epoch logged an event. This is the child's last write.

Both ride:

1. the internal `terminal` object;
2. the `subagent/end` lifecycle event payload;
3. the `subagent-settled` notice message: numeric fields on the message
   `source` (machine-readable) and one extra text block,
   `Stop time: <ISO>; the child's last recorded activity: <ISO>.` — the
   original summary sentence is untouched;
4. the published types (`ActivationTerminal`, `SubagentRunEndInfo`,
   `SubagentSettledMessageSource`) gain optional `stopTime` /
   `lastActivityTime`.

For a kill, `stopTime` is captured immediately after teardown records the
child's `turn/end {aborted}`, so it lands within milliseconds of
`lastActivityTime` and is bounded by the cancellation window — not by when
the parent next runs.

## Rejected alternatives

- **Date the stop from the notice envelope (`user/message.time`).** That is
  exactly the datum that already existed and misleads: in the live check the
  envelope's `time` is 22.7 s after the stop because the notice is delivered
  at the parent's next step/wake, not at teardown.
- **A single `stopTime` only.** The task asked for the child's last-write time
  where cheap; `own.at(-1)?.time` is free at capture, and having both makes
  "manager recorded the stop" and "child actually last wrote" independently
  checkable (they differ by 23 ms live).
- **Render an ISO string into the source field.** Epoch ms matches every
  other durable timestamp (`session event.time`); the ISO text is provided
  beside it for humans and models.
- **Emit a notice for one-shot runs too.** One-shot children return their
  result through the tool call; the notice (and `interrupt_agent` targeting)
  is the continuable Activation's contract. Out of scope.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/subagent-stop-time.patch`, stacks on 007 → 013 → 018 → 019)
- `@deepseek-ai/dsh-subagent/lib/types/types.d.ts`
  (`patches/subagent-run-end-info-types.patch`)
- `@deepseek-ai/dsh-subagent/lib/types/lifecycle.d.ts`
  (`patches/subagent-activation-terminal-types.patch`)
- `@deepseek-ai/dsh-subagent/lib/types/continuation-messages.d.ts`
  (`patches/subagent-settled-source-types.patch`)

The published unbundled twin `lib/types/continuation-messages.js` is not
reachable through the package's export map (only the bundled `lib/index.js`
runs), so it is deliberately left untouched.

## Acceptance evidence

See `EVIDENCE.md`. Live (headless profile, generic continuable `subagent`:
child runs `sleep 120`, lead waits 15 s, `interrupt_agent`, waits 20 s): the
durable notice event carries

```json
"source": {"kind":"subagent-settled","form":"notice",
  "summary":"Background subagent ce1df1eb-… was stopped before it finished.",
  "senderSessionId":"ce1df1eb-…",
  "stopTime":1790414939218,"lastActivityTime":1790414939195}
```

`stopTime` is 23 ms after `lastActivityTime`, and the child's own final
`turn/end {aborted, reason: parent}` has `time = 1790414939195` — the
`lastActivityTime` value exactly. The notice envelope's `time` is
`1790414961931`, i.e. 22.7 s later, confirming the payload no longer conflates
stop with delivery.
