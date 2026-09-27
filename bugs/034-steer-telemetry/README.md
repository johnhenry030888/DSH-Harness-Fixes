# Bug 034 — steer telemetry: `deliveredAt` and a step-boundary stamp

Severity: **medium** (every drill since v18 had to reconstruct the steer split
from the child's own log or give up; one measurement was impossible). Local
fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

- **v21 §4.3**: the steer split had to be reconstructed from the child's log.
- **v23 §5 item 5**: the boundary→reply half was not measurable.
- **v25 §5 item 8**: boundary→reply came out **negative** (−0.306 s) because
  the child's message timestamp precedes its `step/start`.
- **v26 §5 item 5**: only the 14 s total was measurable; `send_message`
  returned "message delivered" with no timestamp and no record id.

## Root cause

`send_message` (`dsh-tool-subagent-control`) returned only a message id and
rendered a bare confirmation; `dsh-subagent`'s delivery path created the child
message with no durable delivery record; and the agent loop's inbox claim —
the step boundary where a steer is actually adopted — appended nothing. The
three timestamps therefore did not exist anywhere in the transcript.

## Fix design

1. **Delivery stamp** (`dsh-tool-subagent-control`): `send_message` stamps
   `deliveredAt` (ISO 8601, millisecond precision) before the call, passes it
   through `SubagentSendMessageOptions.deliveredAt`, returns it in the tool
   result object, and appends it to the confirmation text
   (`message delivered to agent <id> — deliveredAt <iso>`; the original wording
   is preserved, not replaced).
2. **Durable child record** (`dsh-subagent`): `submitAdmitted()` marks a steer
   message's source (`steer: true`, `deliveredAt`) and appends
   `subagent/steer {messageId, target, senderSessionId, deliveredAt}` to the
   child. `sendMessage()` forwards the caller's stamp so the tool result and
   the child record carry the same value; a caller without one (browser
   prompt) is stamped at admission.
3. **Boundary stamp** (`dsh-agent-loop`): `ReactLoopInbox.claim()` — the step
   boundary that consumes pending input — appends
   `subagent/steer-boundary {messageId, deliveredAt, boundaryAt, boundarySeq}`
   for every claimed message whose source is a steer. The record is
   diagnostic: a failed append cannot break the step.
4. **Monotonicity**: `deliveredAt <= boundaryAt <= reply`, with `boundarySeq`
   locating the boundary in the child's log. Delivery semantics, the 030
   `interruptToolCall` behaviour, and the `message delivered to agent …`
   wording are unchanged.

## Rejected alternatives

- **Change `sendMessage()` to return `{messageId, deliveredAt}`.** Widens the
  typed seam, its typert host declaration, and every consumer for one stamp;
  the caller-supplied option keeps the contract and lets the tool return the
  exact value the child recorded.
- **Let the child model emit its own timestamps.** The drills proved child
  self-reports unreliable, and the boundary must exist even if the child never
  mentions it.
- **Stamp the boundary in `preStep()` instead of `claim()`.** `preStep` runs
  before the system prompt assembly and can be rejected; `claim()` is the one
  place a message is actually consumed.
- **Reuse `agent/inbox/spliced`'s envelope `time` as the boundary.** The
  splice happens at delivery, not adoption; v25 measured exactly that
  conflation as a negative split.

## Files patched

- `@deepseek-ai/dsh-tool-subagent-control/lib/index.js`
  (`patches/dsh-tool-subagent-control-delivered-at.patch`; stacks on bug 030)
- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-steer-delivery-record.patch`; stacks on 033 and thus
  031/032/036)
- `@deepseek-ai/dsh-subagent/lib/types/types.d.ts`
  (`patches/dsh-subagent-steer-options-type.patch`; stacks on bug 033)
- `@deepseek-ai/dsh-agent-loop/lib/index.js`
  (`patches/dsh-agent-loop-steer-boundary-stamp.patch`; stacks on 010/030)
- `@deepseek-ai/dsh-session/lib/index.js` (the `subagent/steer` and
  `subagent/steer-boundary` event types are provisioned by bug 031's
  `dsh-session-known-subagent-events.patch`)

## Acceptance evidence

`EVIDENCE.md`: `scripts/steer-check.mjs` drives the real `claim()` method with
a fake advancing clock (pre-fix extraction fails; post-fix all cases pass);
the live `scripts/steer-probe.sh` steers a `sleep 60` child and shows the
ordered triple `deliveredAt 20:53:43.297Z → boundaryAt 20:53:43.435Z → reply
20:53:49.370`, all three values in the transcript.
