# Versions — bug 034

- First analyzed broken: `@deepseek-ai/dsh-tool-subagent-control`,
  `@deepseek-ai/dsh-subagent`, `@deepseek-ai/dsh-agent-loop`,
  `@deepseek-ai/dsh-session` 0.1.5-rc.2 (installed bundle with fixes 001–033
  applied), from drill v21 §4.3, v23 §5 item 5, v25 §5 item 8 (negative
  boundary→reply) and v26 §5 item 5.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - the patches apply to the installed bundle (service stacks on 033; loop and
    control stack on 010/030) with no fuzz; `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent; the six-fix round trip is byte-identical to the installed
    files and to the baseline after reverse-apply;
  - `scripts/steer-check.mjs` FAIL pre-fix (builders absent), PASS post-fix
    with a 250 ms fake-clock ordering assertion;
  - live `scripts/steer-probe.sh` PASS: `deliveredAt 20:53:43.297Z →
    boundaryAt 20:53:43.435Z → reply 20:53:49.370`, with
    `boundarySeq: 24`.
- Pristine sources: `npm pack @deepseek-ai/dsh-tool-subagent-control@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-agent-loop@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-session@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version): the two
  record builders, the `subagent/steer` and `subagent/steer-boundary`
  appends, the `deliveredAt` option type, and the appended tool-result wording.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 034 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream stamps steer delivery itself (then mark UPSTREAMED).
