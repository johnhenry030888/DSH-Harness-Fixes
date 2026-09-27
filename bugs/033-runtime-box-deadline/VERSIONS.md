# Versions — bug 033

- First analyzed broken: `@deepseek-ai/dsh-subagent`,
  `@deepseek-ai/dsh-tool-subagent`, `@deepseek-ai/dsh-session` 0.1.5-rc.2
  (installed bundle with fixes 001–032 applied), from drill v23 §3, v24 §3 and
  v26 §3/F1/F2.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - the patches apply to the installed bundle (service stacks on 031/032/036;
    the tool patch on 019) with no fuzz; `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent; the six-fix round trip is byte-identical to the installed
    files and to the baseline after reverse-apply;
  - live `scripts/box-probe.sh` PASS: per-call `box_seconds: 15` overrides a
    30 s row, row `boxSeconds: 15` hits at 15 s, each call returns in ~31 s
    with the box message and a durable `subagent/box` record.
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-session@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `assertBoxSeconds`, `armOneShotBox`, `armBox`, the `subagent/box` append,
  the tool's `box_seconds`/`boxSeconds` surface, and `boxStopError`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 033 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added a native delegation deadline (then mark UPSTREAMED).
