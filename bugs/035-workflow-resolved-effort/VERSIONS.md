# Versions — bug 035

- First analyzed broken: `@deepseek-ai/dsh-tool-workflow`,
  `@deepseek-ai/dsh-workflow-worker-thread`, `@deepseek-ai/dsh-llm`,
  `@deepseek-ai/dsh-llm-pi-ai`, `@deepseek-ai/dsh-llm-deepseek`,
  `@deepseek-ai/dsh-workflow` 0.1.5-rc.2 (installed bundle with fixes 001–034
  applied), from drill v16 F5, v17 §2, v19 §5 item 2 and v25 §5 item 2.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - every patch applies with no fuzz (`dsh-llm`/`dsh-llm-pi-ai` stack on 024,
    `dsh-tool-workflow`/`dsh-workflow-worker-thread`/`dsh-workflow` on 028,
    `dsh-llm-deepseek` raw pristine); `node --check` clean on all five JS
    files;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent; the six-fix round trip is byte-identical to the installed
    files and to the baseline after reverse-apply;
  - live `scripts/effort-probe.sh` PASS: three `agent-start` records with
    `resolvedEffort`/`effortSource` (`default`, `default`, `inherited:max`),
    and every child header carries `reasoningEffort` with longcat-2.0 showing
    `"default"`.
- Pristine sources: `npm pack @deepseek-ai/dsh-tool-workflow@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-workflow-worker-thread@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-llm@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-llm-pi-ai@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-llm-deepseek@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-workflow@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version): the
  `effortFields` helper and its two append sites, the worker-thread
  `resolveChildEffort` + `childEfforts`, the `"default"` sentinel in
  `dsh-llm`, and the sentinel handling in both adapters.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 035 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added resolved-effort fields (then mark UPSTREAMED).
