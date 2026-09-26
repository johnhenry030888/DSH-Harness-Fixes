# Versions — bug 019

- First analyzed broken: `@deepseek-ai/dsh-tool-subagent` /
  `@deepseek-ai/dsh-subagent` / `@deepseek-ai/dsh-subagent-in-process-driver`
  0.1.5-rc.2 (installed bundle with fixes 007–018 applied), from drill v7 §7
  overreach note (friction #13) and v8 §7.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - all three patches apply to pristine published sources with their stacks
    applied, no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent;
  - live (temporary `orchestrator-ro` preset): a read-only child's `edit` fails
    with the named, path-aware refusal (child id included); its `bash` append is
    denied by the read-only sandbox; an unconstrained child still writes; the
    lead-owned file hash is unchanged;
  - `scripts/read-only-check.mjs` covers the guard and the free-child no-op.
- Pristine sources: `npm pack @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-subagent-in-process-driver@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `readOnly: z.boolean().default(false)`, `read-only child`,
  `allowed write paths: none`, `mode: "read-only"`,
  `readOnly: descriptor.readOnly`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 019 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added a structural write scope (then mark UPSTREAMED).
