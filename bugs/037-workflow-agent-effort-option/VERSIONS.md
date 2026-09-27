# Versions — bug 037

- First analyzed broken: `@deepseek-ai/dsh-workflow-worker-thread`,
  `@deepseek-ai/dsh-tool-workflow`, `@deepseek-ai/dsh-workflow` 0.1.5-rc.2
  (installed bundle with fixes 001–036 applied), from drill v16 F5, v17 §2,
  v19 §5 item 2, v21 §7 R1, v25 §5 item 2 and v26 §6 item 2.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - the six patches apply with no fuzz onto the 001–036 stack
    (`worker.cjs` on 006/028/035; `worker-thread/lib/index.js` on 006/028/035;
    `dsh-tool-workflow` on 028/035; the three type files on 035 where they
    overlap); `node --check` clean on all three JS files;
  - `scripts/check.sh` exit 1 with the patches reversed, 0 on the installed
    bundle; `scripts/reapply.sh` chains 006 → 028 → 035 then applies the six
    files and is idempotent (verified twice on the installed bundle);
  - the six-file round trip is byte-identical to the installed files and to
    the pre-037 baseline after reverse-apply (`ROUNDTRIP PASS`);
  - live `scripts/effort-option-probe.sh` PASS: `requestedEffort`/
    `resolvedEffort`/`effortSource` = `low`/`low`/`pinned` (stage-one),
    inherited `max` (stage-two), `extreme`/`pinned` + failed
    `UNSUPPORTED_REASONING_EFFORT` (stage-three), `INVALID_ARGUMENT` (stage-four);
    child headers carry `reasoningEffort` `low` and `max`.
- Pristine sources: `npm pack @deepseek-ai/dsh-workflow@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-tool-workflow@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-workflow-worker-thread@0.1.5-rc.2`
  (tarballs under `/tmp/opencode/pristine-check/`). The stored patches are cut
  against the **installed 001–036 stack**, which is what the reapply chain
  reconstructs before applying them; a pristine-source-only bundle needs the
  prerequisite chain first.
- Fix markers (checked by `scripts/check.sh`, never the version): the
  `effort` forwarding/validation in `worker.cjs`, the `agentOptions`
  merge in the worker host, the `requestedEffort` record appends plus the
  description sentence in `dsh-tool-workflow`, and the three type fields.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 037 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added an `effort` option to `agent()` (then mark
  UPSTREAMED).
