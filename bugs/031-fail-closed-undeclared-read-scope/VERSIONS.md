# Versions — bug 031

- First analyzed broken: `@deepseek-ai/dsh-subagent` and
  `@deepseek-ai/dsh-session` 0.1.5-rc.2 (installed bundle with fixes 001–030
  applied), from drill v25 §5 (undeclared read scope admitted) and drill v26
  §5/Appendix A (bypass reproduced beside the declared-scope refusal).
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - the `dsh-subagent` patch applies to the installed guard (023/026 stack) with
    no fuzz; the `dsh-session` patch applies to pristine published sources;
  - `node --check` clean on both files;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice); the six-fix round trip is byte-identical to the
    installed files and byte-identical to the baseline after reverse-apply;
  - `scripts/guard-scope-check.mjs` FAIL (6 cases) pre-fix, PASS post-fix;
  - the durable `subagent/inspection-scope` record is asserted in the probe.
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-session@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version): the maximal
  reader fallback, the "declared no read scope … whole workspace" refusal, the
  `scopeBasis` record append, and the four new session event types.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 031 is MISSING, run
  `scripts/reapply.sh`; if the guard patch no longer applies, re-investigate or
  check whether upstream made the undeclared case fail-closed (then mark
  UPSTREAMED).
