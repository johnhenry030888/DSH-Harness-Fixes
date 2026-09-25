# Versions — bug 007

- First analyzed broken: `@deepseek-ai/dsh-subagent` / `@deepseek-ai/dsh-tools`
  / `@deepseek-ai/dsh-tool-subagent` 0.1.5-rc.2 (installed bundle,
  2026-09-25), with drill evidence from `orchestrator-drill-report-v3.md`
  (2026-09-25). Upstream 0.1.6-alpha.2 still throws on unknown names and has
  no tolerant branch or row-identified validation.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-25):
  - both patches apply to the pristine published sources with no fuzz (the
    `dsh-tool-subagent` patch is the first of a stack completed by bugs 008
    and 009);
  - `node --check` clean on both files;
  - `scripts/check.sh` exit 0 with the fix, exit 1 on pristine copies;
  - `scripts/reapply.sh` idempotent;
  - `scripts/tolerance-check.mjs` passes against the installed bundle;
  - live v3-list delegation spawns and drops all 17 restrictable names from the
    child's catalog; a bogus name fails with the loader row id.
- Pristine sources for diffing: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`
  and `npm pack @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2` from the registry.
- Fix markers checked by `scripts/check.sh` (never the version):
  - `function restrictChildTools(` and
    `cannot be restricted in its scope (dropped from the filter)` in
    `dsh-subagent`;
  - `function assertKnownToolFilterNames(`, `absent from the child catalog`,
    and `assertKnownToolFilterNames(runtimeCtx.tools, scopeOf(parent.ctx),
    config, rowLabel)` in `dsh-tool-subagent`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 007 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate (code
  moved?) or check whether upstream made `restrict()` tolerant / added
  mount-time validation (then mark UPSTREAMED in root `STATUS.md`).
