# Versions — bug 008

- First analyzed broken: `@deepseek-ai/dsh-subagent-fork-in-process` 0.1.5-rc.2
  (installed bundle, 2026-09-25), with drill evidence from
  `orchestrator-drill-report-v4.md` (2026-09-25). Upstream 0.1.6-alpha.2 still
  passes no seed diagnostic and keeps the ambiguous wording.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-25):
  - both patches apply with no fuzz (the `dsh-tool-subagent` wording patch
    stacks on bug 007's patch of the same file);
  - `node --check` clean;
  - `scripts/check.sh` exit 0 with the fix, exit 1 on pristine copies;
  - `scripts/reapply.sh` idempotent, re-applying bug 007 first when its marker
    is missing;
  - `scripts/seed-check.mjs` passes: empty seed → warning naming the parent and
    `inherits 0 events`; completed turn → 4-event seed, no warning;
  - live mid-turn fork: child session `isSeeded:false`, no `session/end-seed`.
- Pristine sources for diffing: `npm pack
  @deepseek-ai/dsh-subagent-fork-in-process@0.1.5-rc.2` and `npm pack
  @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2` from the registry.
- Fix markers checked by `scripts/check.sh` (never the version):
  - `reportSeed(parent, inheritedEventCount)`, `inherits 0 events`,
    `new ForkInProcessProvider(config.providerName, ctx.logger)` in the fork
    package;
  - `seeded with the parent's completed turns up to the last` and
    `gives the child NO prior conversation` in `dsh-tool-subagent`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 008 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate (code
  moved?) or check whether upstream added the seed diagnostic / reworded the
  fork description (then mark UPSTREAMED in root `STATUS.md`).
