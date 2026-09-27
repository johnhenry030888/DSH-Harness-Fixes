# Versions — bug 039

- First analyzed broken: `dsh` 0.1.5-rc.2 (installed bundle, 39 fixes applied),
  from drill v27 §3/§4/§6 F3: "no transcript store found at
  `~/.dsh/storages/sessions/*.jsonl` (nor recursively under
  `~/.dsh/storages/**`)". The same failure mode cost v23 §5 (steer split) and
  v26 §3/§6 (header/effort table, share number).
- Verified working locally on 0.1.5-rc.2 (2026-09-28) against:
  - the real v27 drill session
    `session-10f5becd-c2cf-40a9-bc4c-b1888acff7df` (2 190 953 B decompressed,
    265 records, 113 zstd frames) — header summary, per-type counts, raw rows,
    23-child table, usage totals;
  - its `quality/measure.json` snapshot: the first 15 parent model responses
    reproduce `inputTokens_uncached 134 464 / cacheReadTokens 1 286 656 /
    outputTokens 76 753` **exactly**, and every one of the 20 children that had
    settled by the snapshot matches its per-child totals exactly (the three
    still-running lanes differ, as they must);
  - a scratch DSH_HOME copy (one session directory copied under a fresh
    `sessions/--scratch-copy--/`);
  - the two-frame self-test fixture and the forced `node` frame-loop fallback.
- There is no bundle patch: the reader consumes the store the installed bundle
  already writes (`patches/00-no-bundle-change.md`).
- After a `dsh` update: run `scripts/check-all.sh`. If bug 039 is MISSING, run
  `scripts/reapply.sh` (restores the executable bits and re-runs the check); if
  the self-test fails, re-read the store path/shape in README.md against the
  new bundle.
