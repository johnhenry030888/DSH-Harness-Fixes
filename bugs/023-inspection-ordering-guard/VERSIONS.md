# Versions — bug 023

- First analyzed broken: `@deepseek-ai/dsh-subagent` and
  `@deepseek-ai/dsh-tool-subagent-control` 0.1.5-rc.2 (installed bundle with
  fixes 001–022 applied), from drill v10 §6 (in-place verifier corrupted a
  concurrent reviewer's evidence) and drill v11 §6.2/§10 friction #1/§11
  recommendation 1.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - the `dsh-subagent` patch applies to pristine published sources with its
    stack (bugs 007/013/017/018/019) applied, no fuzz; the list-agents patch
    applies with bug 010 applied;
  - `node --check` clean on both files;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice); the shadow-bundle round trip is byte-identical to the
    installed files;
  - `scripts/inspection-check.mjs` PASS (prefix semantics incl. the
    `/work/project` vs `/work/project-2` sibling case);
  - live on a temporary headless overlay: a read-only spawn was refused with
    `INSPECTION_CONFLICT` naming the still-running writer, `list_agents`
    showed `[writes in …]`, and after the writer's settlement notice the
    identical read-only call returned `READY`.
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-tool-subagent-control@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `function treesOverlap(left, right)`,
  `function inspectionConflicts(ctx, parent, readOnlyRequested)`,
  `function assertInspectionOrdering(ctx, parent, readOnlyRequested)`,
  `"INSPECTION_CONFLICT"`, both creation-path call sites, and the
  `filePolicy`/`tree` list_agents fields.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 023 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added a structural write scope / inspection lock (then mark
  UPSTREAMED).
