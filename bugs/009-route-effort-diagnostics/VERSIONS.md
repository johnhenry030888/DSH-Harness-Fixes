# Versions — bug 009

- First analyzed broken: `@deepseek-ai/dsh-tool-subagent` and
  `@deepseek-ai/dsh-llm` 0.1.5-rc.2 (installed bundle, 2026-09-25), with drill
  evidence from v1/v2/v3/v4 reports. Upstream 0.1.6-alpha.2 still throws the
  identical route text and the ladder-less effort text.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-25):
  - both patches apply with no fuzz (the `dsh-tool-subagent` patch stacks on
    bugs 007 and 008 of the same file);
  - `node --check` clean;
  - `scripts/check.sh` exit 0 with the fix, exit 1 on pristine copies;
  - `scripts/reapply.sh` idempotent, re-applying bugs 007/008 first when
    needed;
  - live headless runs: invented id → "does not serve a model with id";
    served-but-not-allowed id → "the provider serves this model id, but it is
    outside the Session's allowed routes"; unsupported effort → ladder
    `— supported: low, high, max`.
- Pristine sources for diffing: `npm pack
  @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2` and `npm pack
  @deepseek-ai/dsh-llm@0.1.5-rc.2` from the registry.
- Fix markers checked by `scripts/check.sh` (never the version):
  - `does not serve a model with id` and
    `the provider serves this model id, but it is outside the Session's allowed routes`
    in `dsh-tool-subagent`;
  - `function describeReasoningEfforts(` and
    `supported: ${describeReasoningEfforts(reasoning)}` in `dsh-llm`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 009 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate (code
  moved?) or check whether upstream split the error classes / added the effort
  ladder (then mark UPSTREAMED in root `STATUS.md`).
