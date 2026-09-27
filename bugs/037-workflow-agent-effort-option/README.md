# Bug 037 — `agent(prompt, {effort})`: workflow stages cannot pin a per-stage effort

Severity: **medium** (an effort-pinned stage silently runs at the lead's
effort, and the drill's cost bars pay for it). Local fix: **APPLIED** to the
`dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

- **v16 F5 / v17 §2**: a stage-1 `workflow` child silently ran at the
  **lead's** `max` while its sibling recorded `null`; `agent()` could not
  express an effort at all.
- **v19 §5 item 2 / v25 §5 item 2**: an "effort-matched" pair ran unmatched —
  both `agent()` stages inherited the lead's effort and one adapter's header
  carried no key (closed by 035's record half, but the stages still could not
  be pinned).
- **v21 §7 R1**: "`agent()` accepts no effort → a pinned merge must leave the
  workflow", which paid a 72.8 s inter-stage handoff in v18 and lost both
  workflow time bars in v19 (the merge inherited the lead's `max`).

## Root cause

1. `dsh-workflow-worker-thread/lib/worker.cjs` lists `effort` in
   `DEFERRED_AGENT_OPTIONS`, so `readAgentOptions()` rejects it with
   `UNSUPPORTED_OPTION`; the supported set was `label, phase, schema,
   provider, model`.
2. The worker's `agent()` forwards only those five fields to
   `children.startAgent(...)`, and `ChildStartRequest` had no effort field, so
   the host's creation-time resolution could never see one.
3. The host already had half the plumbing from 035: `resolveChildEffort()`
   returns `{resolvedEffort, effortSource: "pinned"}` as soon as
   `request.agentOptions?.reasoningEffort` is present — but nothing ever set
   it.
4. The run record carried no requested value, and the tool description said
   "Anything else (`effort`/`isolation`/`agentType`) is rejected loudly".

## Fix design

1. **Option surface** (`worker.cjs`): `effort` moves from
   `DEFERRED_AGENT_OPTIONS` to `SUPPORTED_AGENT_OPTIONS`; its value must be a
   non-empty string and anything else is rejected pre-spawn with
   `INVALID_ARGUMENT` naming the option (`agent() option "effort" must be a
   non-empty string`). `isolation` and `agentType` stay deferred and keep
   rejecting loudly. The two option-list messages now read
   `label, phase, schema, provider, model, effort`.
2. **Pinned forwarding** (`worker.cjs` → `index.js`): `agent()` sends
   `agentOptions: { reasoningEffort: opts.effort }` on the child-start request;
   the host merges it into the child's creation `agentOptions` (beside
   `provider`/`model`), which reaches `resolveChildEffort()`'s first branch
   (`request.agentOptions?.reasoningEffort`) — so the child runs at the pinned
   level and the run record gets `{resolvedEffort, effortSource: "pinned"}`
   before its first request header exists.
3. **Requested value on the record**: the worker's `info` payload carries
   `requestedEffort`; the recorder appends it to both
   `tool-workflow/agent-start` and `agent-end` beside 035's
   `resolvedEffort`/`effortSource`, so the pinned route (`provider`/`model`/
   `effort`) is readable from the run record.
4. **Loud, early failure on an unadvertised effort** — route taken: the child
   is created with the pinned level and its **first request** rejects with the
   platform's own `UNSUPPORTED_REASONING_EFFORT` (`dsh-llm`'s ladder
   diagnostic), which bug 028's seam already carries as the child's
   `errorCode`; `agent()` rejects with a `WorkflowError` of that code and the
   run record shows both the attempt (`requestedEffort`/`resolvedEffort:
   "extreme"`, `effortSource: "pinned"`) and the failure (`outcome: "failed"`,
   `error`, `errorCode`). No silent fallback, and no ladder re-implementation:
   in the live probe the failed `agent-end` lands **22 ms** after its
   `agent-start`. (Pre-resolving the ladder inside the worker host was
   rejected — see below.)
5. **Types + documentation**: `ChildStartRequest` gains the `agentOptions` bag;
   `WorkflowAgentInfo` and the tool-workflow record types gain
   `requestedEffort`; the `agent()` description paragraph documents the option,
   the pinned route, the record fields, and the unadvertised-effort failure.

## Rejected alternatives

- **Accept `effort` only in `meta.phases[]` (per-phase pins).** Phases are
  display/progress vocabulary the engine imposes no execution structure on,
  and the drills pin per **call** (`agent(prompt, {effort})`); a phase pin
  could not express two stages of one phase at different efforts, so per call
  is the required surface.
- **Silently ignore an unknown effort.** The child would run at some other
  level while the record claimed the pin; that is exactly the v16/v19
  unfalsifiability this batch exists to remove.
- **Map an unknown effort down to the model default.** Same silent fallback
  in a nicer dress: the caller's intent is lost and the record becomes a lie.
  `dsh-llm` already refuses unsupported levels before provider I/O (`no
  clamping or aliasing`); 037 keeps that rejection visible instead of hiding
  it.
- **Pre-resolve the ladder in the worker host and fail the start with a new
  typed error channel.** `resolveChildEffort()` runs host-side, so the ladder
  *could* be checked there — but the child-start RPC only carries a rendered
  string back to the worker, so a stable code would require widening the
  protocol with a typed error channel (a new seam) for information the child's
  own failure already carries end-to-end via 028. The chosen route is
  behaviorally identical from the script's and the record's point of view and
  keeps the seam count unchanged.
- **Name the option `reasoningEffort` (the AgentOptions spelling).** The
  model-facing surface was already documented as `effort` (the deferred
  option), and the drills' pin vocabulary is `effort`; renaming would be a
  gratuitous break from the tool contract.

## Files patched

- `@deepseek-ai/dsh-workflow-worker-thread/lib/worker.cjs`
  (`patches/dsh-workflow-worker-thread-effort-option.patch`; stacks on
  006/028/035)
- `@deepseek-ai/dsh-workflow-worker-thread/lib/index.js`
  (`patches/dsh-workflow-worker-thread-effort-forward.patch`; same stack)
- `@deepseek-ai/dsh-workflow-worker-thread/lib/types/types.d.ts`
  (`patches/dsh-workflow-worker-thread-child-request-type.patch`)
- `@deepseek-ai/dsh-tool-workflow/lib/index.js`
  (`patches/dsh-tool-workflow-requested-effort.patch`; stacks on 028/035)
- `@deepseek-ai/dsh-tool-workflow/lib/types/types.d.ts`
  (`patches/dsh-tool-workflow-requested-effort-types.patch`)
- `@deepseek-ai/dsh-workflow/lib/types/types.d.ts`
  (`patches/dsh-workflow-requested-effort-type.patch`; stacks on 035)

## Acceptance evidence

`EVIDENCE.md`: the live `scripts/effort-option-probe.sh` runs one four-stage
workflow — stage-one pinned `opencode-go/longcat-2.0 @ low`, stage-two with no
route/effort, stage-three pinned at the unadvertised `extreme`, stage-four
`effort: 5` — and shows `requestedEffort: "low"`/`resolvedEffort: "low"`/
`effortSource: "pinned"` for stage-one, `"inherited"`/`max` for stage-two, the
named `UNSUPPORTED_REASONING_EFFORT` rejection for stage-three, and
`INVALID_ARGUMENT` naming `effort` for stage-four; stage-one's child header
carries `reasoningEffort: "low"`.
