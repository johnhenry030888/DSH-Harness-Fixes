# Versions — bug 024

- First analyzed broken: `@deepseek-ai/dsh-tool-workflow`,
  `@deepseek-ai/dsh-llm`, `@deepseek-ai/dsh-llm-pi-ai`, and
  `@deepseek-ai/dsh-tool-subagent` 0.1.5-rc.2 (installed bundle with fixes
  001–022 applied), from drill v11 §8.2/§10 friction #2 and the optimization
  plan §22.3 residual 1.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - every patch applies to pristine published sources with its own stack
    applied (007→008→009→011→012→019 for tool-subagent; 009→012 for llm;
    003→005→012 for llm-pi-ai; 014→014b for tool-workflow), no fuzz;
  - `node --check` clean on all four JS files;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice); the shadow-bundle round trip is byte-identical;
  - live headless: `run-end` carried
    `failedAgents: 2` + `error` + `requestedProvider`/`requestedModel` for a
    run with two rejected pins; the workflow and direct paths produced the
    identical canonical sentence with `MODEL_NOT_CONFIGURED` /
    `UNKNOWN_MODEL`.
- Pristine sources: `npm pack` of the four packages at 0.1.5-rc.2.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `modelResolutionDiagnostic`, `MODEL_NOT_CONFIGURED` / `UNKNOWN_MODEL`
  constants, both classifier throw sites, `failedAgents: failure.count`.
- Superseded checks: bug 009's and bug 012's `check.sh` were updated to
  assert their classes wherever they now render (dsh-llm's shared formatter),
  per the STATUS.md precedent for 012 superseding 009's wording. Their fix
  patches are untouched.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 024 is MISSING,
  run `scripts/reapply.sh`; if a patch no longer applies, re-investigate or
  check whether upstream unified the diagnostics and/or added run-end failure
  fields (then mark UPSTREAMED).
