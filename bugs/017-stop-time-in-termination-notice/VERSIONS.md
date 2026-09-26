# Versions — bug 017

- First analyzed broken: `@deepseek-ai/dsh-subagent` 0.1.5-rc.2 (installed
  bundle with fixes 007 → 013 → 018 → 019 applied), from drill v9 §9 #2 and
  v10 §8/§10 #6.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - the runtime patch applies to the stacked pristine sources
    (`npm pack` + 007/013/018/019 patches, `diff -q` confirmed identical to
    the installed file before the fix); the three type patches apply to
    pristine `.d.ts` files, no fuzz;
  - `node --check` clean on the patched JS;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice);
  - live: interrupt of a child inside `sleep 120` produced the notice with
    `stopTime` 23 ms after `lastActivityTime`, which equals the child's own
    aborted `turn/end.time` exactly; the notice envelope `time` was 22.7 s
    later.
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2` plus the
  bug 007/013/018/019 patches from this repository.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `const lastActivityTime = own.at(-1)?.time;`, `stopTime: Date.now(),`,
  `Stop time: ${new Date(stopTime).toISOString()}`,
  `readonly stopTime?: number;`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 017 is MISSING,
  run `scripts/reapply.sh`; if the patch no longer applies, check whether
  upstream added stop timing to the settlement notice (then mark UPSTREAMED).
