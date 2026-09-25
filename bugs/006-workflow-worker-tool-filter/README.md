# Bug 006 — workflow workers bypass the delegation leaf policy

Severity: **high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

Children spawned through the `workflow` tool keep the full orchestration
surface. A worker's own catalog still contains `send_message`, `workflow`,
`create_goal`/`get_goal`/`update_goal`, `ralph`, `ask_user_question`,
`list_agents` and `interrupt_agent`.

- Drill v3 §3b: a workflow worker **ran a nested `workflow` successfully**
  (`workflow "x" completed (0 agents). Return value: 1`), and a `create_goal`
  call reached the goal tool (rejected only by its policy).
- Drill v4 §4b: the worker's enumerated catalog kept every one of those tools
  while direct-lane children (spawned by `tool-subagent` rows carrying
  `toolFilter`) correctly had none of them. The worker's catalog was
  `… send_message, subagent, subagent_fast, …, workflow` plus the MCP families
  (~120 names) versus the direct child's ~19 non-MCP tools.
- The `workflow-worker-thread` row accepts **no leaf-policy configuration at
  all**, so the gap cannot be closed from a preset.

## Root cause

`@deepseek-ai/dsh-workflow-worker-thread` starts every `agent()` child through
`this.subagents.start(this.provider, {…})` (`lib/index.js:485`) and never
passes a `toolFilter`. Its `Config` (`lib/index.js:849`) exposed only
`provider`, `maxConcurrentAgents`, `maxTotalAgents`, `maxItemsPerCall`,
`syncTimeoutMs`, `disposeGraceMs`, and `lib/worker.cjs` contains no
`toolFilter`/`restrict(` reference at all. `WorkerRun` had no field to carry a
filter to `startChild()`.

The delegation seam already supports exactly this: `SubagentRuntime.start`
passes `request.toolFilter` to the provider, the `spawn`/`fork` providers
advertise `capabilities.toolFilter`, and `applyChildComposition`
(`@deepseek-ai/dsh-subagent`) applies it as a scoped `restrict()` in the
child's creation window. Only the workflow engine never used it.

## Fix design

Deployment-owned configuration only, never model-authored data:

1. `WorkerThreadWorkflowEngine.Config` gains
   `toolFilter: { allow?: string[], deny?: string[] }` with the same shape as
   `@deepseek-ai/dsh-tool-subagent`'s `toolFilter`. The engine constructor
   rejects a filter that names neither `allow` nor `deny` (fail at mount, not
   at the first run).
2. `WorkerRun` carries the filter (`this.toolFilter`, constructor parameter)
   and `startChild()` passes it on **every** `subagents.start()` call:
   `...this.toolFilter !== void 0 ? { toolFilter: this.toolFilter } : {}`.
3. Unset default: no `toolFilter` key on the request, so behavior is
   byte-for-byte what it was before (verified live, see below).
4. The filter is **never** read from the model-authored `meta` or script args.
   The engine owns worker lifecycle, so the engine owns the worker's
   capability mask; letting a script choose its own mask would be fail-open.

Seam note: the same one-line `toolFilter` passthrough applies to the direct
delegation path; the engine is now merely a second caller of the same seam.

## Rejected alternatives

- **Read the filter from `meta`/script args.** Rejected: model-authored input
  must not select the child's capability mask (fail-open foot-gun); the mask is
  deployment policy.
- **Filter the worker's tool catalog inside `worker.cjs`.** Rejected: the
  worker thread only runs the script; it does not own child creation. The host
  `WorkerRun.startChild()` owns the `subagents.start()` lifecycle, so
  enforcement belongs there (same reasoning as bug 001's goal-round driver).
- **Add a `maxDepth` cap only.** Rejected: depth does not hide
  `send_message`, goal tools or `list_agents` from a leaf; the drill's gap is
  the capability surface, not recursion.
- **Change `@deepseek-ai/dsh-subagent` to filter workflow workers by provider
  name.** Rejected: the provider (`spawn`) is shared with direct lanes; the
  engine's row is the only place that knows this child is a worker.

## Files patched

- `@deepseek-ai/dsh-workflow-worker-thread/lib/index.js`
  (`patches/dsh-workflow-worker-thread-tool-filter.patch`).

## Acceptance evidence

- `scripts/check.sh` exits 1 before the fix and 0 after; `scripts/reapply.sh`
  is idempotent.
- Live (headless, temporary `--patch` overlay on the host row — the user's
  preset was never edited):
  - With `toolFilter.deny` set, a worker enumerated `workflow: ABSENT`,
    `send_message: ABSENT`, `create_goal: ABSENT`, `ralph: ABSENT`,
    `list_agents: ABSENT`, `ask_user_question: ABSENT`,
    `interrupt_agent: ABSENT`; a nested `workflow` call reported
    `ABSENT-TOOL`.
  - With the option unset, the same probe reported `workflow: PRESENT`,
    `send_message: PRESENT`, `create_goal: PRESENT`, `ralph: PRESENT`,
    `list_agents: PRESENT`, `interrupt_agent: PRESENT` — the v4 behavior,
    proving the default is unchanged.
