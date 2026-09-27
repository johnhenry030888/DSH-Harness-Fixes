# Bug 031 — the ordering guard is fail-open on an undeclared read scope

Severity: **high** (the 023/026 ordering guard is bypassable by omission, which
is exactly the scheduling mistake it exists to prevent). Local fix:
**APPLIED** to the `dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

Drill v25 §5 (guard probe 1) and drill v26 §5 item 3 + Appendix A: a read-only
delegation that declares **no** read scope was **admitted while four
write-capable children were live** (probe G1 "returned normally"), while the
identical call with a declared tree was refused. The guard therefore only
protected callers who happened to state a scope: omitting it — the easiest
thing for a model to do — disabled the rule.

Drill v26 §5 item 3 records the same finding as a reproduced bypass:
"(c) undeclared scope with four writers live → ADMITTED (G1 returned
normally) — v25's bypass reproduced."

## Root cause

`dsh-subagent/lib/index.js` `inspectionConflicts()` (pre-fix, after 023/026)
fell back to the parent workspace when the requested delegation declared no
paths:

```js
const readerTrees = readTrees !== void 0 && readTrees.length > 0 ? readTrees : [parent.session.header.cwd];
```

and then only compared that cwd against each writer's declared work. That made
"no declared scope" mean "the parent cwd only", not "the whole workspace", so a
caller could slip past the guard by naming nothing. The refusal text also never
said which rule had fired, so a caller could not tell a declared-scope refusal
from the fallback.

## Fix design

`dsh-subagent/lib/index.js`:

1. **Maximal default.** A read-only delegation whose prompt declares no read
   scope is treated as covering the whole workspace: `inspectionConflicts()`
   now records `scopeBasis: "maximal"` and returns **every** live
   write-capable direct child as a conflict, regardless of declared trees.
2. **Explicit refusal.** `assertInspectionOrdering()` throws the required
   message — `refused a read-only delegation that declared no read scope: it
   is treated as covering the whole workspace, and write-capable agent "<id>"
   is still running` — followed by the existing retry guidance (wait for the
   settlement notice, or `interrupt_agent`, then retry unchanged) and a note
   that declaring the read scope narrows the rule to those paths.
3. **Durable basis record.** Every read-only delegation evaluation appends
   `subagent/inspection-scope` to the parent session with
   `{scopeBasis, outcome, readTrees, conflicts}`, so a transcript reader can
   tell which rule fired without parsing prose.
4. **Declared scopes keep today's behaviour** (023/026): the overlap is
   computed on declared paths and a disjoint reader is admitted.

`dsh-session/lib/index.js` gains the durable event types the guard and its
dependents append: `subagent/inspection-scope`, `subagent/box`,
`subagent/steer`, `subagent/steer-boundary` (the last three are consumed by
bugs 033/034; one seam, one patch).

## Rejected alternatives

- **Require a declared path on every read-only delegation (reject empty
  scopes).** Breaks every caller that legitimately reviews a workspace without
  naming it, and turns a scheduling guard into a prompt-format rule. The
  maximal default refuses only while a writer is actually live.
- **Refuse all undeclared read-only delegations unconditionally.** Over-broad:
  the guard's own contract is transient (a settled writer holds no claim), so
  the refusal must disappear after settlement, which the conflict scan
  provides.
- **Keep the cwd fallback and reword the message.** Does not close the bypass:
  a writer whose declared work lies outside the parent cwd would still be
  ignored.
- **Add `scopeBasis` only to the error object.** Errors do not survive the
  transcript; the durable `subagent/inspection-scope` record is what a drill
  can read after the fact.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-fail-closed-scope.patch`; stacks on bugs
  007/013/017/018/019/023/026/027/028/029/030 of the same file)
- `@deepseek-ai/dsh-session/lib/index.js`
  (`patches/dsh-session-known-subagent-events.patch`; raw pristine)

## Acceptance evidence

`EVIDENCE.md`: module-level `scripts/guard-scope-check.mjs` drives the guard
functions directly and shows the pre-fix message/record failures vs the fixed
pass; `scripts/check.sh` exit 1 pre-fix, 0 post-fix; patches round-trip
against the installed bundle.
