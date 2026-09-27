# Evidence — bug 033

## Primary evidence (pre-fix)

- Drill **v23 §3** (verify lane): a 300 s box ran to ~600 s, `SELF_ABORT` was
  written, and **0 of 19 mutants executed**; §7 friction #2 / §8
  recommendation 3: "Put the box in the driver … a hard self-abort".
- Drill **v24 §3**: three lanes overran 2×/1.6×/1.8×, two interrupted, two
  returned nothing; the lane whose job ran inside a deadline-checked loop
  finished **19 mutants in 13 s**.
- Drill **v26 §3** + **§7 F1/F2**: two in-driver lanes produced **nothing at
  all** after 662 s and 323 s; the run lost one of two sweeps and the entire
  token/share/measurement bundle. §8 recommendation 2: "Make the in-driver box
  external. … A `timeout <box>` wrapper plus a mandatory first-line progress
  write converts an opaque hang into a partial table, which is the only thing
  a wave can use."

## Fix markers (checked by `scripts/check.sh`)

- `dsh-subagent`: `function assertBoxSeconds(boxSeconds)`,
  `function armOneShotBox(run, boxSeconds, logger)`,
  `armOneShotBox(await provider.start(resolved), request.boxSeconds, this.ctx.logger)`,
  `armBox(parent, childId, boxSeconds)`,
  `if (request.boxSeconds !== void 0) this.armBox(parent, childId, request.boxSeconds);`,
  `activation.handle.agent.session.append("subagent/box", record);`,
  `hit its ${box.boxSeconds} s box and was interrupted after ${box.elapsedSeconds} s`,
  `const box = own.findLast((event) => event.type === "subagent/box")?.data;`.
- `dsh-subagent/lib/types/types.d.ts`: `readonly boxSeconds?: number;`.
- `dsh-tool-subagent`: `boxSeconds: z.natural().min(5)`, `box_seconds: {`,
  `const boxSeconds = args.box_seconds ?? config.boxSeconds;`,
  `function boxStopError(run, result)`, and the result message.
- `dsh-session`: `"subagent/box",`.

## Before/after check output

```
$ (pre-033: 031/032/036 applied) DSH_AGENT_BASE=/tmp/opencode/shadow033 bash bugs/033-.../scripts/check.sh
missing: function assertBoxSeconds(boxSeconds) (in lib)
missing: function armOneShotBox(run, boxSeconds, logger) (in lib)
missing: armOneShotBox(await provider.start(resolved), request.boxSeconds, this.ctx.logger) (in lib)
missing: armBox(parent, childId, boxSeconds) (in lib)
missing: if (request.boxSeconds !== void 0) this.armBox(parent, childId, request.boxSeconds); (in lib)
missing: activation.handle.agent.session.append("subagent/box", record); (in lib)
missing: hit its ${box.boxSeconds} s box and was interrupted after ${box.elapsedSeconds} s (in lib)
missing: const box = own.findLast((event) => event.type === "subagent/box")?.data; (in lib)
missing: readonly boxSeconds?: number; (in types)
missing: boxSeconds: z.natural().min(5) (in lib)
missing: box_seconds: { (in lib)
missing: const boxSeconds = args.box_seconds ?? config.boxSeconds; (in lib)
missing: boxSeconds (in lib)
missing: function boxStopError(run, result) (in lib)
missing: hit its ${String(box.boxSeconds)} s box and was interrupted after ${String(box.elapsedSeconds)} s; partial output follows: (in lib)
bug-033 fix MISSING
exit=1

$ (installed) bash bugs/033-.../scripts/check.sh
bug-033 fix PRESENT
exit=0
```

## Live probe (scratch `DSH_HOME`, real `~/.dsh` untouched)

`scripts/box-probe.sh` boots the shipped headless profile through `dsh
--patch` in a scratch home and runs two variants; each asserts the tool
result, the wall clock, and the child's durable record.

```
variant per-call — row boxSeconds=30, expected hit at 15s
    | Error: agent "3ad07043-9123-401a-af7c-e7f8f038a99f" hit its 15 s box and was interrupted after 15 s; partial output follows:
    | Error: agent "3ad07043-9123-401a-af7c-e7f8f038a99f" hit its 15 s box and was interrupted after 15 s; partial output follows:
  PASS  the tool result reports the 15 s box hit
  PASS  the result carries the partial-output contract
  PASS  the call returned in 32237 ms (box, not the 120 s sleep)
    subagent/box records: [{'boxSeconds': 15, 'elapsedSeconds': 15, 'hit': True}]
  PASS  the child transcript carries the durable subagent/box record

variant row — row boxSeconds=15, expected hit at 15s
    | `Error: agent "2152e4c5-dddf-4481-8e5b-ebcc3896dfaf" hit its 15 s box and was interrupted after 15 s; partial output follows:
    | Error: agent "2152e4c5-dddf-4481-8e5b-ebcc3896dfaf" hit its 15 s box and was interrupted after 15 s; partial output follows:
  PASS  the tool result reports the 15 s box hit
  PASS  the result carries the partial-output contract
  PASS  the call returned in 30846 ms (box, not the 120 s sleep)
    subagent/box records: [{'boxSeconds': 15, 'elapsedSeconds': 15, 'hit': True}]
  PASS  the child transcript carries the durable subagent/box record

bug-033 live probe: PASS (both variants)
scratch home kept for inspection: /tmp/orch-drill-033
```

The probe's timing assertion (≥ 14 s, ≤ 90 s) proves the box, not the child's
120 s sleep, ended the call; the row variant proves the row default and the
per-call variant proves the per-call override.

## Patch round-trip

```
forward apply (031->032->036->033->034->035) == installed bundle: OK
reverse apply (035->034->033->036->032->031) == pre-batch baseline: OK
ROUNDTRIP PASS
```

`scripts/reapply.sh` chains 036 (and thus 031/032) and 019, and is idempotent
(verified twice on a shadow bundle).

## Verification limits (disclosed)

- The settlement-notice wording for a **continuable** child is covered by the
  markers and the observer/notice code path; the live probe exercises the
  foreground path because the tool result is where the acceptance text lives.
  (The continuable path uses the same record and interrupt call.)
- A provider without a local in-process agent (`localAgent === undefined`)
  records the box but cannot cancel; the shipped `spawn` provider always has
  one.
