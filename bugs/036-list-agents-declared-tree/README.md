# Bug 036 — `list_agents` shows the session cwd, not the delegation's declared tree

Severity: **medium** (six drills misread where a lane was working; settled rows
carry no tree or policy at all). Local fix: **APPLIED** to the
`dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

Six drills (v16 F2, v17 §5, v20 F2, v21 §5 item 4, v22 §5 item 4, v26 §5 item
4) saw live rows render `[writes in /home/john/Documents/Projects/DSH]` — the
child's session cwd — while the delegation's declared target was a drill
subpath. v26 additionally found settled rows carrying **no tree and no
file-policy field at all**, so the ordering rule's key property was invisible
exactly when it mattered. v26 §6 item 4: "at 19:09:42 all 11 direct children
were `ready`, and every row carried only id + status + label — no file-policy
field and no working-tree field at all."

## Root cause

`dsh-tool-subagent-control/lib/types/list-agents.js` `project()` set
`tree: live.session.header.cwd` (~62 pre-fix) and rendered it (~156), and it
sampled `filePolicy` only when a live agent existed. The ordering guard already
had the honest harvester (`declaredTreesOf` in `dsh-subagent`, bug 026); the
display simply never used it.

## Fix design

1. **Share the guard's harvester.** `dsh-subagent`'s internal
   `declaredWorkOfSession(session)`/`declaredWorkOf(agent)` is exposed on the
   service as `ctx.subagents.declaredWorkOf(agent)`, returning
   `{trees, basis}` with `basis: "declared" | "cwd" | "unknown"`; the type is
   added to `lib/types/index.d.ts`.
2. **Render the declared tree with its basis.** `project()` now resolves the
   live agent's session (or the durable Session store entry for a settled
   child) and emits `tree` (the first declared path), `trees` (all of them),
   and `treeBasis`; the row renders `[writes in <path> (declared)]`. The
   session cwd remains only the fallback when the prompt declares nothing, and
   is labelled `(cwd)`.
3. **Predictable policy presence.** Live rows keep the 023 `filePolicy`
   sample; a settled row carries no `filePolicy`, and the tool description now
   states that absence explicitly. `checkedAt`, `id`, `status`, and the label
   shape are unchanged; the new fields are optional additions.

## Rejected alternatives

- **Write a second path harvester in the control tool.** Two harvesters drift;
  the drills' own complaint is that the display and the guard disagreed.
- **Expose the raw session and let the tool scan it.** Duplicates the bounded
  24-event scan and the incidental/most-specific rules; the service owns the
  policy.
- **Keep `tree: cwd` and add `declaredTree` beside it.** Leaves the wrong
  field as the default a model reads first; the declared path replaces it and
  the basis label removes the ambiguity.
- **Drop `tree` for settled rows entirely.** Loses the declared path when the
  durable session is loaded; the fix renders it when resolvable and documents
  the absence otherwise.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-declared-work-service.patch`; stacks on 031/032)
- `@deepseek-ai/dsh-subagent/lib/types/index.d.ts`
  (`patches/dsh-subagent-declared-work-types.patch`)
- `@deepseek-ai/dsh-tool-subagent-control/lib/types/list-agents.js`
  (`patches/dsh-tool-subagent-control-declared-tree.patch`; stacks on 023)

## Acceptance evidence

`EVIDENCE.md`: live `scripts/list-agents-probe.sh` shows a live child told to
write `/tmp/orch-drill-036/declared/sub/file.txt` rendering
`[writes in /tmp/orch-drill-036/declared/sub/file.txt (declared)]` with
`checkedAt` and `filePolicy`; `scripts/check.sh` exit 1 pre-fix, 0 post-fix;
patches round-trip.
