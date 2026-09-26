# Bug 026 — the 023 ordering guard tests the session cwd, not the delegation's target path

Severity: **medium** (false refusals block a lane for the wrong reason; the
message's "outside this path prefix" claim names a prefix that was never the
test). Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle. Upstream:
**NOT-FILED**.

## Symptoms

Drill v12 §6.4 (the deliberate 023 probe) refused a read-only review with:

```
Error: subagent: refused a read-only delegation while write-capable agent
"8253c281-8e81-48bd-bf04-cc0a35425369" is still running against the same tree
"/home/john/Documents/Projects/DSH" — a read-only review must not overlap a
lane that may still mutate it. … trees outside this path prefix are unaffected.
```

The refusal was correct for the deliberate probe, but the prefix it tested
(`/home/john/Documents/Projects/DSH`, the session's cwd) was **not the tree the
read-only lane would read** (the drill directory under `~/Desktop`). A review
aimed entirely outside a live writer's tree would still have been refused, for
the wrong reason, and the guard's own scope sentence named a prefix that never
participated in the decision (drill v12 §10 friction #2, §11 recommendation 3).

## Root cause

Bug 023's `inspectionConflicts()` compared `parent.session.header.cwd` with
`candidate.session.header.cwd`. In-process children always inherit the parent's
cwd (`childSessionMeta`), so the predicate is really "is the parent's cwd equal
to itself" — it can never express the lane's actual read scope. The only
per-delegation statement of *what a lane will touch* is the delegation prompt
itself; the guard never looked at it.

## Fix design

The guard now keys on the declared target paths, not the session cwd:

1. `declaredTreePaths(text)` extracts absolute filesystem paths from arbitrary
   instruction text (URLs stripped; well-known system roots dropped; paths
   normalized and deduped).
2. `declaredPromptTrees(prompt)` reads the *requested* delegation's own prompt
   — the lane's declared read scope. When a prompt declares no paths, the
   parent workspace stays the conservative fallback (bug 023's behaviour).
3. `declaredTreesOf(agent)` reads a live writer's **first delegation prompt**
   (a bounded scan of its first 24 events, since creation bookkeeping precedes
   the prompt) and treats the **workspace only as the fallback when the prompt
   declares no path** — a writer naming one subdirectory must not block every
   read-only lane under the session cwd.
4. `inspectionConflicts(ctx, parent, readOnlyRequested, readTrees)` reports one
   `{agent, readerTree, writerTree}` per live `running`, non-read-only child
   whose declared work overlaps the requested read scope.
5. `assertInspectionOrdering(..., prompt)` names the tested target path (the
   reader's overlapping path) and the writer's overlapping path in the
   refusal, and states the actual scope rule: a read-only lane whose declared
   paths do not overlap any live writer is admitted.

Transient behaviour is unchanged: only `status === "running"` writers conflict,
so the identical call succeeds after the settlement notice. Both creation
paths (`start()` and `startContinuable()`) pass the request prompt.

## Rejected alternatives

- **A new explicit `targetPath` field on the delegation request/row.** Adds a
  configuration surface every caller must learn, and the v13 drill's existing
  preset rows carry none — the guard would still name the session cwd for
  every current lane. The prompt is already the lane's authoritative statement
  of what it will read; derive from it.
- **Intersect writer *write* paths with reader *read* paths exactly.** The
  harness records no write paths at all (only cwd + the read-only flag), so
  "write paths" could only be guessed. Declared paths on both sides are the
  honest approximation, and they are what the drill's evidence (and friction
  #2's suggestion) points at.
- **Keep the cwd test and only reword the message.** Does not remove the false
  refusal; the message would just lie more precisely.
- **Parse the prompt on the tool side (`dsh-tool-subagent`) and pass paths in.**
  Splits one policy across two packages; the service owns the lifecycle and
  already receives the full request.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-target-path-ordering.patch`; stacks on bugs
  007/013/017/018/019/023 of the same file)

## Acceptance evidence

See `EVIDENCE.md`. In one live Orchestrator session (scratch `DSH_HOME` with a
copy of the preset; the user's `~/.dsh` untouched):

- a read-only review whose prompt names tree A is refused while a writer whose
  prompt names tree A is live — the message names tree A;
- a read-only review whose prompt names tree B is admitted while the only live
  writer declares tree A;
- the refused tree-A call retried unchanged after settlement succeeds.

**Verification limit (disclosed):** path extraction is lexical. A prompt that
names its target only through a shell variable already expanded by the
delegating model is covered (the expanded absolute path appears in the text);
a prompt that names no absolute path at all falls back to the parent workspace,
which is bug 023's conservative behaviour, not a new false-negative class.
