# Bug 023 — the verify→review ordering rule has no mechanical guard

Severity: **medium**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

Nothing stopped the lead from dispatching a `readOnly: true` review lane while
a write-capable verify lane was still running against the same tree. Drill v10
did exactly that and the reviewer reported **3 test failures that were really
the verifier's in-place mutation**; drill v11 repeated the scheduling mistake
(§6.2 of the drill v11 report records review-A as an overlapped run), harmlessly
only because the v11 verifier mutated a private copy under `quality/.mutation/`.
The rule — *never overlap a destructive step with an observation of the same
tree* — existed only as persona prose (drill v11 §10 friction #1, §11
recommendation 1).

## Root cause

The harness had no notion of an inspection state to query or enforce:

- `ctx.subagents.start()` / `startContinuable()` created every child without
  consulting the other live children, so a read-only delegation was admitted
  in parallel with any writer;
- `list_agents` rows exposed mode/label/status but neither the child's file
  policy nor its working tree, so a lead could not even *see* that a live
  child was still allowed to mutate the tree;
- the one durable discriminator that did exist — the per-child `sandbox/mode`
  fold written by bug 019 for read-only lanes — was never read on the
  delegation path.

## Fix design

The lifecycle owner (`@deepseek-ai/dsh-subagent`) gains three things, all
derived from state the runtime already holds:

1. `treesOverlap(left, right)` — path-prefix overlap of two working trees;
   a missing cwd is treated as overlapping (conservative).
2. `inspectionConflicts(ctx, parent, readOnlyRequested)` — the live direct
   children of `parent` that are **running** (status `running`, i.e. a driver
   is active right now, including inside a long tool call) and whose resolved
   sandbox policy is **not** `read-only` (`ctx.sandboxPolicy.overrideOf(child.session)`,
   the same `sandbox/mode` fold the enforcement dialects consume), with an
   overlapping tree. A settled child holds no claim: the settlement notice is
   the handoff.
3. `assertInspectionOrdering(...)`, called at the top of *both* creation
   paths (`SubagentRuntime.start` for one-shot children and
   `SubagentRuntime.startContinuable` for continuable children), throws a
   `SubagentError` with code `INSPECTION_CONFLICT` naming every conflicting
   child id and the tree, and tells the caller to wait for the settlement
   notice (or `interrupt_agent`) and retry the same read-only call unchanged.

The guard fires only when the requested child is `readOnly: true`. A
write-capable spawn is never affected, a read-only spawn against a different
cwd prefix is never affected, and a read-only spawn proceeds normally once the
writer's turn has ended.

Observability half: `list_agents` rows gain `filePolicy` (`read-only` ×
`writes`, sampled from the same sandbox-policy fold) and `tree` (the child's
session cwd), rendered inline as `… — writer [writes in /path]`. The tool
description states the guard so a lead can plan around it.

## Rejected alternatives

- **Warn instead of refuse.** A warning cannot ride the existing tool result
  without widening the strict `oneOf` output schemas of every delegation tool,
  and a warning that only lands in a log does not mechanically stop the
  evidence corruption that motivated the fix. The acceptance allows either;
  refusal is observable, deterministic, and machine-routable via
  `error.code: INSPECTION_CONFLICT`.
- **Track inspection claims in a separate registry.** The live Agent registry
  plus the sandbox-policy projection already carry both facts (status,
  read-only-ness) durably; a second registry would have to re-derive
  lifecycle edges and could drift from settlement.
- **Guard at the delegation tool (`dsh-tool-subagent`) instead.** Each lane is
  a separate tool instance and only sees its own config; the service owns
  every child's lifecycle, so the service is the seam-clean home (bug 001's
  driver precedent).
- **Match trees per subdirectory.** The only per-child tree fact the harness
  records is the session cwd (children inherit the parent's workspace), so
  the honest predicate is cwd-prefix overlap. Anything finer would have to
  parse the free-text prompt; unrelated *workspaces* are unaffected.
- **Guard builders too.** The hazardous overlap is destructive-inspection vs
  observation. Any live `writes` child can still mutate the tree, so the
  guard keys on write-capability, not on a "verify" lane name the harness
  does not have.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-inspection-guard.patch`; stacks on bugs
  007/013/017/018/019 of the same file)
- `@deepseek-ai/dsh-tool-subagent-control/lib/types/list-agents.js`
  (`patches/dsh-tool-subagent-control-inspection-state.patch`; stacks on
  bug 010)

## Acceptance evidence

See `EVIDENCE.md`. Live on a temporary headless overlay adding a `readOnly:
true` one-shot row (the Orchestrator `tool-subagent-review` row shape; the
user's presets untouched):

- with a write-capable `subagent` still running against the session tree, the
  read-only call was refused with a `SubagentError` naming the writer id and
  the tree, and `list_agents` showed
  `b72a493a-… [running as of …] — writer [writes in /tmp/opencode/batch4/p23-live]`;
- after the writer's settlement notice, the *identical* read-only call
  returned `READY` — no flag, no workaround.

**Verification limit (disclosed):** the headless profile mounts no agent
presets, so the real Orchestrator preset cannot be opened there; the live
proof drives the same `config.readOnly → composition → sandbox/mode` path the
Orchestrator row uses, through a temporary `--patch` overlay (the bug 021
precedent). The path-prefix "unrelated trees" arm is covered by the
module-shaped guard logic and by construction (different cwd → different
prefix), not by a second live workspace.
