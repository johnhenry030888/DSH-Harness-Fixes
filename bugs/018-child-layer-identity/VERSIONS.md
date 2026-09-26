# Versions — bug 018

- First analyzed broken: `@deepseek-ai/dsh-subagent` /
  `@deepseek-ai/dsh-system-prompt` 0.1.5-rc.2 (installed bundle with fixes
  007/013 and 010 applied), from drill v7 §9 friction #11 and v8 §7 (seeded-fork
  impersonation) and v8 §4 (worker descriptor without `toolFilter`).
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - both patches apply to pristine published sources with their stacks applied,
    no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent;
  - live: a cold fork child, a seeded fork child and a workflow worker each
    answered `LAYER=continuation of <parent>` + all 17 `REMOVED` names from
    their own context; the worker descriptor now declares the 17-name
    `toolFilter` (also closes optional 015).
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-system-prompt@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `subagent:layer`, `NOT the orchestrator lead`,
  `This layer's toolFilter removed`, `"toolFilter"` in
  `ONE_SHOT_DESCRIPTOR_KEYS`, `SUBAGENT_LAYER: 118`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 018 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream made child layers self-describing (then mark UPSTREAMED).
