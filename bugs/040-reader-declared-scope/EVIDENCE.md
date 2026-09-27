# Evidence — bug 040

Patch: `patches/dsh-subagent-reader-declared-scope.patch` against
`@deepseek-ai/dsh-subagent/lib/index.js` (readable-wrapper form:
`--- pristine/subagent/lib/index.js` / `+++ installed/subagent/lib/index.js`).

## Primary evidence (pre-fix)

Drill **v27 §6 F2** (verbatim): "a reader that declares `/tmp/` as its read
scope is classified `declared no read scope … (scopeBasis: maximal)`, so it is
refused as maximally scoped while writers are live; only an outside-the-root
tree (e.g. the archive dir) demonstrated admission". The delegation prompt is
quoted in the report and reproduced verbatim in probe case C.

## Module probe (pre-fix vs post-fix)

`scripts/guard-reader-scope-check.mjs [bundle index.js]` drives the guard
functions directly with fake live writers (offline, no host, no model).

Pre-fix (pristine 39-fix bundle):

```
NOTE: pre-040 guard detected; running the same cases against it
ok: B: an overlapping /tmp pair is refused
ok: D: incidental /tmp + sentinel writer mentions do not refuse
ok: D: the writer's declared work still falls back to its cwd
ok: E: an empty declaration is still maximal
ok: E: the maximal record carries no dropped caveat
ok: F: a filtered declaration is still refused as maximal
ok: G: `only read /tmp/x` declares /tmp/x
ok: G: `scope: /tmp/a, /tmp/b` declares both paths
FAIL: A: a declared /tmp read scope is admitted while a writer is live — subagent: refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace, and write-capable agent "writer-a" is still running (scopeBasis: maximal, writerBasis: declared). A read-only review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted, and declaring its read scope narrows this rule to those paths.
FAIL: A: the record says scopeBasis declared and readTrees [/tmp/dsh040-lane] — {"scopeBasis":"maximal","outcome":"refused","readTrees":[],"conflicts":[{"agentId":"writer-a","writerTree":"/drill/sub/out/file.txt","writerBasis":"declared"}]}
FAIL: B: the refusal names the real pair and keeps scopeBasis declared — subagent: refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace, and write-capable agent "writer-b" is still running (scopeBasis: maximal, writerBasis: declared). A read-only review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted, and declaring its read scope narrows this rule to those paths.
FAIL: B: the refusal is recorded as declared/refused — {"scopeBasis":"maximal","outcome":"refused","readTrees":[],"conflicts":[{"agentId":"writer-b","writerTree":"/tmp/dsh040-lane","writerBasis":"declared"}]}
FAIL: C: the v27 F2 reader declaration is admitted, not refused as maximal — subagent: refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace, and write-capable agent "writer-c" is still running (scopeBasis: maximal, writerBasis: declared). A read-only review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted, and declaring its read scope narrows this rule to those paths.
FAIL: C: the declared scope is the scratch tree, not empty — []
FAIL: C: the record is scopeBasis declared with no dropped caveat — {"scopeBasis":"maximal","outcome":"refused","readTrees":[],"conflicts":[{"agentId":"writer-c","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/app","writerBasis":"declared"}]}
FAIL: F: the refusal names the dropped incidental path — subagent: refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace, and write-capable agent "writer-f" is still running (scopeBasis: maximal, writerBasis: declared). A read-only review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted, and declaring its read scope narrows this rule to those paths.
FAIL: F: the record carries droppedIncidental — {"scopeBasis":"maximal","outcome":"refused","readTrees":[],"conflicts":[{"agentId":"writer-f","writerTree":"/drill/sub/out/file.txt","writerBasis":"declared"}]}
GUARD-READER-SCOPE-CHECK FAIL (9 failure(s))
PRE=1
```

Post-fix (installed, patched):

```
ok: A: a declared /tmp read scope is admitted while a writer is live
ok: A: the record says scopeBasis declared and readTrees [/tmp/dsh040-lane]
ok: B: an overlapping /tmp pair is refused
ok: B: the refusal names the real pair and keeps scopeBasis declared
ok: B: the refusal is recorded as declared/refused
ok: C: the v27 F2 reader declaration is admitted, not refused as maximal
ok: C: the declared scope is the scratch tree, not empty
ok: C: the record is scopeBasis declared with no dropped caveat
ok: D: incidental /tmp + sentinel writer mentions do not refuse
ok: D: the writer's declared work still falls back to its cwd
ok: E: an empty declaration is still maximal
ok: E: the maximal record carries no dropped caveat
ok: F: a filtered declaration is still refused as maximal
ok: F: the refusal names the dropped incidental path
ok: F: the record carries droppedIncidental
ok: G: `only read /tmp/x` declares /tmp/x
ok: G: `scope: /tmp/a, /tmp/b` declares both paths
ok: G: a scratch-suffixed cue path has no dropped caveat
GUARD-READER-SCOPE-CHECK PASS
POST=0
```

Cases: A declared `/tmp/dsh040-lane` (scratch word before the path) + writer
elsewhere → admitted/declared; B the same declaration + writer on that path →
refused naming the pair; C the exact v27 F2 prompt → admitted/declared
(`readTrees ["/tmp/dsh-v27-sentinel.txt"]`); D the v26 A3 writer (only mentions
`/tmp` + `/tmp/v26_tstart`) → writer still falls back to cwd and the disjoint
reader is admitted; E genuinely empty declaration → maximal; F a filtered
declaration (`sentinel /tmp/v26_tstart only`) → maximal refusal that names
`1 path mention was ignored as incidental/scratch: "/tmp/v26_tstart"` and a
record carrying `droppedIncidental`; G cue forms `only read /tmp/x` and
`scope: /tmp/a, /tmp/b`.

## Patch round-trip

- forward: pristine + patch == installed (byte-identical, `cmp` clean);
- reverse: installed − patch == pristine (byte-identical);
- `node --check` clean; `patch --dry-run` clean; `reapply.sh` idempotent
  ("already present").

## Live case (scratch headless home + read-only delegation row)

`scripts/reader-scope-probe.sh` (real `dsh`, real model, scratch
`/tmp/orch-drill-040/home`): a write-capable background child declaring
`/tmp/dsh040-live/writer.txt` while three read-only delegations run.

```
    | The refusal here is an Error, not an INSPECTION_CONFLICT code explicitly. The step says: "If it is refused with INSPECTION_CONFLICT, quote the refusal verbatim as RESULT-DISJOINT-REFUSED: <message>." The refusal message doesn't include the literal "INSPECTION_CONFLICT" string. But it is clearly a refusal of a read-only delegation while a write-capable agent is running. Step 2's read scope was /tmp/dsh040-live/readers, which is disjoint from the writer's /tmp/dsh040-live/writer.txt... wait, but the refusal in step 3 is for the writer.txt scope. Let me re-check: step 2 returned normally: READ-ADMITTED-DISJOINT. Good.
    | Step 3 result: refused with an error. The instruction says quote failure as RESULT-OVERLAP: <result or error message>. So I quote the error message. Whether to label it as refused... The step 3 says "Quote the result verbatim as RESULT-OVERLAP: <result or error message>." So RESULT-OVERLAP: Error: subagent: refused...
    | RESULT-DISJOINT: READ-ADMITTED-DISJOINT
    | RESULT-OVERLAP: Error: subagent: refused a read-only delegation while write-capable agent "a2e5c18f-7cae-4021-b011-5360a7b4f377" is still running against the same target path "/tmp/dsh040-live/writer.txt" — the writer's declared work covers "/tmp/dsh040-live/writer.txt" (scopeBasis: declared, writerBasis: declared), which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
    | RESULT-AFTER: READ-ADMITTED-AFTER
  PASS  disjoint /tmp declaration admitted while the writer is live
  PASS  overlapping declaration refused
  PASS  refusal names the declared writer pair
  PASS  refusal keeps scopeBasis declared
  PASS  the same declaration admitted after settlement
  PASS  no maximal-scope refusal in the run
  -- durable subagent/inspection-scope records (via bug-039 reader)
  PASS  refused record is scopeBasis declared
  PASS  refused record carries the declared pair
  PASS  admitted record for /tmp/dsh040-live/readers
  PASS  admitted record for /tmp/dsh040-live/writer.txt after settlement
READER-SCOPE-PROBE PASS
```

Raw tool results from the parent transcript (via the bug-039 reader,
`--records tool/result --json`):

```
READ-ADMITTED-DISJOINT
```

```
Error: subagent: refused a read-only delegation while write-capable agent "a2e5c18f-7cae-4021-b011-5360a7b4f377" is still running against the same target path "/tmp/dsh040-live/writer.txt" — the writer's declared work covers "/tmp/dsh040-live/writer.txt" (scopeBasis: declared, writerBasis: declared), which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
```

```
READ-ADMITTED-AFTER
```

Durable `subagent/inspection-scope` records from the same live run:

```
{"scopeBasis":"declared","outcome":"admitted","readTrees":["/tmp/dsh040-live/readers"],"conflicts":[]}
{"scopeBasis":"declared","outcome":"refused","readTrees":["/tmp/dsh040-live/writer.txt"],"conflicts":[{"agentId":"a2e5c18f-7cae-4021-b011-5360a7b4f377","readerTree":"/tmp/dsh040-live/writer.txt","writerTree":"/tmp/dsh040-live/writer.txt","writerBasis":"declared"}]}
{"scopeBasis":"declared","outcome":"admitted","readTrees":["/tmp/dsh040-live/writer.txt"],"conflicts":[]}
```

The refusal names the live writer (`a2e5c18f…`), the declared pair and
`scopeBasis: declared`; after settlement the identical call is admitted. Pre-fix
the disjoint call was refused as maximal (probe case C / v27 F2).

## Batch 6–7 guards still pass

```
$ node bugs/031-fail-closed-undeclared-read-scope/scripts/guard-scope-check.mjs
031=0
$ node bugs/032-declared-path-overlap-pairs/scripts/guard-pair-check.mjs
032=0
```

Both probes were updated minimally to extract the new reader-side helper in
their source-block lists (the guard refactor moved the reader harvest behind
`declaredReadScopePaths`/`declaredPromptScope`); their assertions are
unchanged.
