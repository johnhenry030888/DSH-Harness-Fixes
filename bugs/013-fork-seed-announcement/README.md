# Bug 013 — fix 008's cold-fork announcement is not observable

Severity: **medium**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

A mid-turn fork's child descriptor says `isSeeded:false` (correct) but carried
**no `inheritedEventCount`**, and neither the child nor the parent transcript
received any notice. In the second turn the seed **is** real — the child answers
from inherited context before any tool call — but the disclosure is a count-less
`session/end-seed {"inherited": true}` in a log the lead cannot see, absent from
the descriptor, the child's context, and the lead's tool result.

Drill v8 measured the fixture (pre-fix):

| probe | child | `isSeeded` | seed marker | descriptor count | notice |
| --- | --- | --- | --- | --- | --- |
| fork 5.1 (mid-turn) | `57197a0f` | false | `session/end-seed` seq 28 `{}` | none | none |
| fork 5.2 attempt 1 (tool-mediated reply) | `cfbca693` | false | none | none | none |
| fork 5.2 attempt 2 (real new turn) | `e764b113` | true | seq **708** `{"inherited": true}` | none | none |
| token-recall probe | `b119a95f` | true | seq 708 | none | none |

Precondition recorded in v8 §7: a reply delivered through `ask_user_question` is
a tool result inside the current turn and creates no `turn/end`, so the fork
stays cold — a seeded fork needs the parent turn to have **ended**.

## Root cause

- `dsh-subagent-in-process-driver`'s `readResult` and descriptor path never
  recorded the activation boundary; the `SubagentDescriptor` schema
  (`dsh-subagent`) had no seed field at all.
- The fork provider's `reportSeed` (bug 008) returned early for a non-empty seed
  and logged only into `ctx.logger`, which the model never sees.

## Fix design

1. **Numeric count on the descriptor.** `subagent/descriptor` gains an optional
   `inheritedEventCount` (non-negative safe integer, 0 = cold, N = seeded):
   - the in-process driver enriches every one-shot descriptor with its
     `activationBoundary` (0 for spawn children, `seed.length` for one-shot
     forks);
   - the continuable manager builds the descriptor after `prepareContinuable`
     and stamps the same value; `coldResume` reuses the persisted prefix count;
   - `parseSubagentDescriptor`/`foldSubagentDescriptor` validate it on read.
2. **Announcement that reaches someone.**
   - the fork provider logs in **both** directions (`warn` for 0, `info` for N),
     naming the parent session;
   - the child's runtime context carries one visible line:
     `This layer inherited N completed events from parent agent "<id>" (0 means
     it started cold …)`.
3. The corrected tool description from bug 008 is kept.

## Rejected alternatives

- **Session header field.** `dsh-session`'s header deliberately treats the
  exact prefix length as Session state, not header metadata
  (`dsh-session/lib/types/types.d.ts:72-76`); the durable descriptor is the
  right home.
- **A new session event type.** A new event needs format/projection work and is
  invisible to the child's context anyway; the descriptor is already projected
  into the child's own log and read by tooling.
- **Parent settlement notice only.** A one-shot fork's settlement is a tool
  result the recorder cannot enrich with provider-private state; the child's
  runtime context reaches the party that matters (the child) and the child's
  reply reaches the lead.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-seed-count-descriptor.patch`, stacks on 007)
- `@deepseek-ai/dsh-subagent-fork-in-process/lib/index.js`
  (`patches/dsh-subagent-fork-in-process-seed-announcement.patch`, stacks on 008)
- `@deepseek-ai/dsh-subagent-in-process-driver/lib/index.js`
  (`patches/dsh-subagent-in-process-driver-seed-count.patch`)

## Acceptance evidence

See `EVIDENCE.md`. Cold first-turn fork child `31ee60c0`:
`inheritedEventCount: 0` in the descriptor, the context line, and the child
answered `INHERITED=0` from context alone. Seeded fork child `c888b27c`:
`inheritedEventCount: 75`, the context line, and `INHERITED=75`. The host log is
verified in both directions by `scripts/seed-announcement-check.mjs` (the web
host's logger sink is not stdout).
