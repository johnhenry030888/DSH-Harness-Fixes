# Versions — bug 036

- First analyzed broken: `@deepseek-ai/dsh-tool-subagent-control` and
  `@deepseek-ai/dsh-subagent` 0.1.5-rc.2 (installed bundle with fixes 001–035
  applied), from drill v16 F2, v17 §5, v20 F2, v21 §5 item 4, v22 §5 item 4
  and v26 §5 item 4.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - the patches apply with no fuzz (service on 031/032, list-agents on 023);
    `node --check` clean on both JS files;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent; the six-fix round trip is byte-identical to the installed
    files and to the baseline after reverse-apply;
  - live `scripts/list-agents-probe.sh` PASS: the row renders
    `[writes in /tmp/orch-drill-036/declared/sub/file.txt (declared)]` with
    `checkedAt` and `filePolicy`.
- Pristine sources: `npm pack @deepseek-ai/dsh-tool-subagent-control@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version): the service
  `declaredWorkOf` method and its type, the list-agents `declaredWorkOf` call,
  `treeBasis`, and the session lookup.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 036 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream renders declared trees itself (then mark UPSTREAMED).
