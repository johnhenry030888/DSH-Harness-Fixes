# Versions — bug 014b

- First analyzed broken: `@deepseek-ai/dsh-tool-workflow` 0.1.5-rc.2
  (installed bundle with fix 014 applied), from drill v9 §9 #2 and v10 §8 /
  friction #4.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - the patch applies to pristine published sources both raw and with bug
    014's recorder patch applied, no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice);
  - live: the headless lead quoted the new run-record passage from the
    `workflow` tool description verbatim.
- Pristine sources: `npm pack @deepseek-ai/dsh-tool-workflow@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `read the run record, never the return value`,
  `a rejected route and a child that produced nothing are both`,
  `when the child failed before producing output`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 014b is MISSING,
  run `scripts/reapply.sh`; if the patch no longer applies, check whether
  upstream made `agent()` return a discriminated failure (then mark
  UPSTREAMED).
