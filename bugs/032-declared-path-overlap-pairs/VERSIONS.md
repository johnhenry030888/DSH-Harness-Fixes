# Versions — bug 032

- First analyzed broken: `@deepseek-ai/dsh-subagent` 0.1.5-rc.2 (installed
  bundle with fixes 001–031 applied), from drill v21 §4.2 / v23 §4.2 / v26 §5
  and Appendix A2/A3.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - the patch applies to the 031-applied guard with no fuzz; `node --check`
    clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent; the six-fix round trip is byte-identical to the installed file
    and to the baseline after reverse-apply;
  - `scripts/guard-pair-check.mjs` FAIL (5 cases) pre-fix, PASS post-fix,
    including the v26 A3 sentinel reconstruction.
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version): the
  incidental-context filter, `mostSpecificPaths`, the shared
  `declaredWorkOfSession`/`declaredWorkOf` harvester, and the pair-naming
  refusal text.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 032 is MISSING, run
  `scripts/reapply.sh` (it chains 031 first); if the patch no longer applies,
  re-investigate or check whether upstream added declared-tree overlap (then
  mark UPSTREAMED).
