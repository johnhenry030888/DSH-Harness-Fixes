# Versions — bug 013

- First analyzed broken: `@deepseek-ai/dsh-subagent` /
  `@deepseek-ai/dsh-subagent-fork-in-process` /
  `@deepseek-ai/dsh-subagent-in-process-driver` 0.1.5-rc.2 (installed bundle
  with fixes 007/008 applied), from drill v7 §7 and v8 §7 (2026-09-25/26).
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - all three patches apply to pristine published sources with their stacks
    applied, no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent;
  - live: cold first-turn fork child `31ee60c0` → `inheritedEventCount: 0` +
    visible context line + `INHERITED=0`; seeded fork child `c888b27c` →
    `inheritedEventCount: 75` + `INHERITED=75`;
  - `scripts/seed-announcement-check.mjs` verifies the host log in both
    directions (warn for 0, info for N) and the descriptor schema round-trip.
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-subagent-fork-in-process@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-subagent-in-process-driver@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `optionalCount`, `This layer inherited ${inheritedEventCount} completed event`,
  `inheritedEventCount: activationBoundary`,
  `inherits ${inheritedEventCount} completed events`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 013 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added a numeric seed count and a spawn announcement (then
  mark UPSTREAMED).
