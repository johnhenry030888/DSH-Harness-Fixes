# Bug 030 — a steer cannot interrupt the child's in-flight tool call

Severity: **medium** (a long tool call is effectively un-steerable: worst case
62 s, exactly when a lead most wants to redirect). Local fix: **APPLIED** to
the `dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

Drill v12 §8: steering behind short steps measured **8.97 s** and **11.86 s**,
but a steer behind a 60 s bash call measured **61.95 s** — the message waited
for the call to end (the tool timeout then killed it). Steer latency is
bounded below by *(the child's current tool call + one model turn)*, so a child
inside a long call is effectively un-steerable.

## Root cause

`AgentLoop.steer()` submitted the message at the nearest **step** boundary
(`send(input, "next-step", true)`) and latched nothing: while a tool call was
executing, the message sat in the inbox until the call returned. The tool-call
cancellation seam already existed (`ToolRuntime` honours `exec.signal`, the
same path `interrupt_agent` uses), but steering never reached it.

## Fix design

Cancel-then-replan in the agent loop (the component that owns the step):

- `AgentLoop` tracks `inFlightToolCalls` around `executeToolCalls()` in
  `step()`;
- `steer()` still inserts the message at `next-step` and then calls
  `cancelInFlightToolCall()`: when a tool call is in flight it latches
  `phase.wakeRequested = true` **before** aborting the phase with reason
  `{ kind: "steered" }`;
- the abort drains the running calls (started calls settle with the runtime's
  cancelled result, unstarted calls get synthetic aborted results) and the
  driver's containment path (which sees the latched wake) replays the pending
  steer in one fresh turn instead of stranding it;
- steering between tool calls (model streaming) is unchanged — the step
  boundary is imminent, and no tokens are wasted on an abort.

Documentation: the `send_message` tool description states the cancel-then-replan
contract, and every child's `subagent:layer` banner states it too (the seam is
the shared `exec.signal`; a tool that ignores its cancellation signal is named
as the residual case rather than silently waited on).

## Rejected alternatives

- **A per-step AbortController.** Cleaner in theory, but it re-plumbs the step
  machine and every signal consumer (stream attempt, tool scheduler, retry) for
  one behaviour; the phase controller already is the cancellation seam every
  consumer honours, and the containment path already replays pending inbox
  work after an abort.
- **Wait for the call and claim "bounded".** That is the bug.
- **Send `interrupt_agent` then re-queue the steer.** Two lifecycle operations
  from the tool layer, loses the advisory ordering, and turns steering into a
  stop/start.
- **Force-host a new Agent.** Overkill; the message would lose the child's
  context.

## Files patched

- `@deepseek-ai/dsh-agent-loop/lib/index.js`
  (`patches/dsh-agent-loop-steer-cancels-tool-call.patch`; stacks on bug 010)
- `@deepseek-ai/dsh-tool-subagent-control/lib/index.js`
  (`patches/dsh-tool-subagent-control-steer-description.patch`; raw pristine)
- `@deepseek-ai/dsh-agent/lib/types/runtime-types.d.ts`
  (`patches/dsh-agent-steer-interrupt-types.patch`; raw pristine)
- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-steer-cancellation.patch`; stacks on bugs
  007/013/017/018/019/023/026/027/028/029 of the same file)

## Acceptance evidence

See `EVIDENCE.md`. Live: a child running a 60 s blocking command accepted a
steer in ≤~5 s, the tool call settled as cancelled (not a timeout), and the
child acted on the steer in the next step.
