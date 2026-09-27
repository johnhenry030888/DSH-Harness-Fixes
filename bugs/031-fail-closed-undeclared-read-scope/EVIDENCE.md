# Evidence — bug 031

## Primary evidence (pre-fix)

- Drill **v25 §5** (guard probe 1): a read-only delegation with **no declared
  path** was **ADMITTED** while four writers were live; the identical call with
  the tree declared was **REFUSED** with `scope_granularity root`.
- Drill **v25 §7 friction #7 / §8 recommendation 6**: "an undeclared read-only
  scope is admitted while writers are live, so the guard is bypassable by
  omission."
- Drill **v26 §5** item 3: "(c) undeclared scope with four writers live →
  ADMITTED (G1 returned normally) — v25's bypass reproduced"; **Appendix A**
  reproduces the declared-scope refusal (A2) beside the bypass.
- Drill **v26 §7 friction F7**: "admitted a read-only delegation that declared
  no scope while four writers were live" → "invert the default: no declared
  scope ⇒ maximal scope."

## Fix markers (checked by `scripts/check.sh`)

- `dsh-subagent`: `const declared = readTrees !== void 0 && readTrees.length > 0;`,
  `const readerTrees = declared ? readTrees : parent.session.header.cwd === void 0 ? [] : [resolve(parent.session.header.cwd)];`,
  `refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace`,
  `const scopeBasis = declared ? "declared" : "maximal";`,
  `parent.session.append("subagent/inspection-scope", {`.
- `dsh-session`: `"subagent/inspection-scope",`, `"subagent/box",`,
  `"subagent/steer",`, `"subagent/steer-boundary",`.

## Before/after check output

```
$ DSH_AGENT_BASE=/tmp/opencode/shadow031 bash bugs/031-fail-closed-undeclared-read-scope/scripts/check.sh
missing: const declared = readTrees !== void 0 && readTrees.length > 0; (in lib)
missing: const readerTrees = declared ? readTrees : parent.session.header.cwd === void 0 ? [] : [resolve(parent.session.header.cwd)]; (in lib)
missing: refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace (in lib)
missing: const scopeBasis = declared ? "declared" : "maximal"; (in lib)
missing: parent.session.append("subagent/inspection-scope", { (in lib)
missing: "subagent/inspection-scope", (in lib)
missing: "subagent/box", (in lib)
missing: "subagent/steer", (in lib)
missing: "subagent/steer-boundary", (in lib)
bug-031 fix MISSING
exit=1

$ DSH_AGENT_BASE=<installed> bash bugs/031-.../scripts/check.sh
bug-031 fix PRESENT
exit=0
```

## Module-level behavioural probe

`scripts/guard-scope-check.mjs` extracts the shipped guard functions from the
installed bundle and drives them with fake live writers. Case A is the bug:
no declared read scope + a live writer must be refused with the maximal rule
and a `scopeBasis: "maximal"` record; case B/C/D/E/F cover the 032 overlap
rules (they share the predicate). Pre-fix output is the 023+026 stack without
this fix (`/tmp/opencode/snap/000-baseline/dsh-subagent/lib/index.js`).

```
$ node bugs/031-fail-closed-undeclared-read-scope/scripts/guard-scope-check.mjs /tmp/opencode/snap/000-baseline/dsh-subagent/lib/index.js   # pre-031/032
NOTE: pre-031 guard detected; running the same cases against it
ok: A: undeclared read scope is refused while a writer is live
ok: A: refusal keeps the retry guidance sentence
ok: B: declared disjoint scope is admitted
ok: C: declared overlap is refused
ok: C: refusal names the actual overlapping pair, not a collapsed ancestor
ok: D: disjoint declared paths are admitted
FAIL: A: refusal states the maximal rule and names the writer — subagent: refused a read-only delegation while write-capable agent "writer-a" is still running against the same target path "/drill" — the writer's declared work covers "/drill/sub/out/file.txt", which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
FAIL: A: parent session records scopeBasis=refused/maximal
FAIL: B: admitted declared delegation records scopeBasis=declared
FAIL: E: incidental /tmp + sentinel mentions do not refuse — subagent: refused a read-only delegation while write-capable agent "writer-e" is still running against the same target path "/tmp/review-notes.md" — the writer's declared work covers "/tmp", which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
FAIL: E: the writer's declared work falls back to its cwd, not the sentinel — ["/tmp","/tmp/v26_tstart"]
FAIL: F: declared descendant wins and the unrelated reader is admitted — subagent: refused a read-only delegation while write-capable agent "writer-f" is still running against the same target path "/drill/sub-b" — the writer's declared work covers "/drill", which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
GUARD-SCOPE-CHECK FAIL (6 failure(s))
exit=1

$ node bugs/031-fail-closed-undeclared-read-scope/scripts/guard-scope-check.mjs   # installed
ok: A: undeclared read scope is refused while a writer is live
ok: A: refusal states the maximal rule and names the writer
ok: A: refusal keeps the retry guidance sentence
ok: A: parent session records scopeBasis=refused/maximal
ok: B: declared disjoint scope is admitted
ok: B: admitted declared delegation records scopeBasis=declared
ok: C: declared overlap is refused
ok: C: refusal names the actual overlapping pair, not a collapsed ancestor
ok: D: disjoint declared paths are admitted
ok: E: incidental /tmp + sentinel mentions do not refuse
ok: E: the writer's declared work falls back to its cwd, not the sentinel
ok: F: declared descendant wins and the unrelated reader is admitted
GUARD-SCOPE-CHECK PASS
exit=0
```

## Patch round-trip

`/tmp/opencode/roundtrip.sh` applies 031→032→036→033→034→035 to the pre-batch
baseline and compares every touched file with the installed bundle, then
reverse-applies in the opposite order and compares with the baseline:

```
forward apply (031->032->036->033->034->035) == installed bundle: OK
reverse apply (035->034->033->036->032->031) == pre-batch baseline: OK
ROUNDTRIP PASS
```

`scripts/reapply.sh` was run twice on a shadow bundle (pre-fix state) and is
idempotent; the second run prints `already present -- nothing to do`.

## Verification limit (disclosed)

The probe drives the guard functions directly; the live four-writer bypass
itself is drill v25/v26 evidence (the drills' own transcripts), not re-run
here. The record is appended best-effort: a session append failure cannot
change the guard decision.
