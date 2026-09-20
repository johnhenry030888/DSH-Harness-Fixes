# Versions -- bug 001

- First seen broken: `0.1.1-rc.2` (installed bundle inspected 2026-09-05).
- Fix applied locally to: `0.1.1-rc.2`.
- Re-verified and re-applied to: `0.1.5-rc.2` (2026-09-20). Both patches were
  regenerated against pristine `0.1.5-rc.2` sources (`npm pack
  @deepseek-ai/dsh-goal-round-driver@0.1.5-rc.2` and
  `@deepseek-ai/dsh-tools@0.1.5-rc.2`); they apply with no fuzz, `node --check`
  is clean, and a pristine->reapply round-trip reproduces the fixed bytes
  exactly.
- Fix markers checked by `scripts/check.sh`:
  - `GOAL_ROUND_ASK_DENIAL` + `installAskGuard` in
    `dsh-goal-round-driver/lib/index.js`
  - `awaiting a binding and returning a constant` in `dsh-tools/lib/index.js`
- Pristine sources for diffing: `npm pack <pkg>@<version>` from the registry.
- After a `dsh` update: run `scripts/check.sh`. If MISSING, run
  `scripts/reapply.sh`; if the patch no longer applies, re-investigate (code
  moved?) or check whether upstream fixed it (mark UPSTREAMED in STATUS.md).
