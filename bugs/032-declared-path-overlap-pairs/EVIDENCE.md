# Evidence — bug 032

## Primary evidence (pre-fix)

- Drill **v21 §4.2**: a refusal reported the writer's declared work as a
  common ancestor rather than the subpath it would edit.
- Drill **v23 §4.2**: same collapse, again from a refusal message.
- Drill **v26 §5** + **Appendix A2**: the declared-scope refusal reported the
  writer's declared work as the drill ROOT although the genuine declared
  targets were its subpaths.
- Drill **v26 §5** + **Appendix A3** (verbatim): `refused a read-only
  delegation while write-capable agent "ccf76e8c-…" is still running against
  the same target path "/tmp" - the writer's declared work covers
  "/tmp/v26_tstart", which overlaps the read scope this delegation's prompt
  declares.` — the writer had merely written a timestamp sentinel there.
- Drill **v26 §7 friction F6**: "refused a read-only delegation whose declared
  scope was the drill root, reporting the writer's declared work as
  `/tmp/v26_tstart`" → "compute the overlap on the writer's declared *trees*,
  not on any path a writer ever touched."
- Drill **v26 §8 recommendation 5**: "Fix the guard in both directions
  (F6/F7): default an undeclared scope to maximal, and compute overlaps on
  declared trees."

## Fix markers (checked by `scripts/check.sh`)

- `const DECLARED_PATH_INCIDENTAL =`, `function mostSpecificPaths(paths)`,
  `if (DECLARED_PATH_INCIDENTAL.test(context)) continue;`,
  `return mostSpecificPaths([...found]);`
- `function declaredWorkOfSession(session)`, `function declaredWorkOf(agent)`,
  `const writerWork = declaredWorkOf(candidate);`
- `the writer's declared work covers ${writerTree} (scopeBasis: ${first.scopeBasis}, writerBasis: ${first.writerBasis})`
  and `writerBasis`.

## Before/after check output

```
$ (pre-032: 031 applied) DSH_AGENT_BASE=/tmp/opencode/shadow032 bash bugs/032-.../scripts/check.sh
missing: const DECLARED_PATH_INCIDENTAL = (in lib)
missing: function mostSpecificPaths(paths) (in lib)
missing: if (DECLARED_PATH_INCIDENTAL.test(context)) continue; (in lib)
missing: return mostSpecificPaths([...found]); (in lib)
bug-032 fix MISSING
exit=1

$ (installed) bash bugs/032-.../scripts/check.sh
bug-032 fix PRESENT
exit=0
```

## Module-level behavioural probe

`scripts/guard-pair-check.mjs` drives the installed guard with fake writers.
The pre-fix run is the 031-applied state without this patch
(`/tmp/opencode/shadow032/dsh-subagent/lib/index.js`); it reproduces the v26
false refusals (sentinel mention, root collapse) and the probe's fallback
extraction lets the same cases run against the older harvester.

```
$ node bugs/032-declared-path-overlap-pairs/scripts/guard-pair-check.mjs /tmp/opencode/shadow032/dsh-subagent/lib/index.js   # pre-032 (031 applied)
NOTE: pre-032 harvester detected; running the same cases against it
ok: 1: overlapping declared paths are refused
ok: 1: the refusal names both declared paths
ok: 2: disjoint declared paths are admitted
FAIL: 3: incidental /tmp + sentinel mentions are admitted — subagent: refused a read-only delegation while write-capable agent "writer-sentinel" is still running against the same target path "/tmp/v26_rows/app" — the writer's declared work covers "/tmp" (scopeBasis: declared, writerBasis: declared), which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
FAIL: 3: the sentinel is not harvested as declared work — ["/tmp","/tmp/v26_tstart"]
FAIL: 4: the declared ancestor collapses to the declared descendant — ["/drill/orchestrator-drill-v26","/drill/orchestrator-drill-v26/state/build/a.py"]
FAIL: 4: an unrelated reader is admitted — subagent: refused a read-only delegation while write-capable agent "writer-root" is still running against the same target path "/drill/orchestrator-drill-v26/app/agg.py" — the writer's declared work covers "/drill/orchestrator-drill-v26" (scopeBasis: declared, writerBasis: declared), which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
FAIL: 4: the genuine overlap is still refused, naming the real path — subagent: refused a read-only delegation while write-capable agent "writer-root" is still running against the same target path "/drill/orchestrator-drill-v26/state/build/a.py" — the writer's declared work covers "/drill/orchestrator-drill-v26" (scopeBasis: declared, writerBasis: declared), which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
FAIL: 5: the A3 shape (writer that only touched /tmp/v26_tstart) is admitted — subagent: refused a read-only delegation while write-capable agent "ccf76e8c-808e-4812-9abf-11b4d52c5102" is still running against the same target path "/tmp" — the writer's declared work covers "/tmp/v26_tstart" (scopeBasis: declared, writerBasis: declared), which overlaps the read scope this delegation's prompt declares. A review must not overlap a lane that may still mutate what it reads. Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged; a read-only lane whose declared paths do not overlap any live writer's is admitted.
GUARD-PAIR-CHECK FAIL (6 failure(s))
exit=1

$ node bugs/032-declared-path-overlap-pairs/scripts/guard-pair-check.mjs   # installed
ok: 1: overlapping declared paths are refused
ok: 1: the refusal names both declared paths
ok: 2: disjoint declared paths are admitted
ok: 3: incidental /tmp + sentinel mentions are admitted
ok: 3: the sentinel is not harvested as declared work
ok: 4: the declared ancestor collapses to the declared descendant
ok: 4: an unrelated reader is admitted
ok: 4: the genuine overlap is still refused, naming the real path
ok: 5: the A3 shape (writer that only touched /tmp/v26_tstart) is admitted
GUARD-PAIR-CHECK PASS
exit=0
```

## Patch round-trip

```
forward apply (031->032->036->033->034->035) == installed bundle: OK
reverse apply (035->034->033->036->032->031) == pre-batch baseline: OK
ROUNDTRIP PASS
```

`scripts/reapply.sh` chains bug 031 first and is idempotent (verified twice on
a shadow bundle).

## Verification limit (disclosed)

The exact v25/v26 prompt texts were not archived (`state/guard-evidence.md`
does not exist), so cases 3–5 reconstruct the Appendix A2/A3 shapes from the
quoted refusal texts. Path extraction remains lexical: a declared target named
only through a shell variable is covered once the delegating model expands it
in the prompt.
