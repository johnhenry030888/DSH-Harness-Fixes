# Versions — bug 014

- First analyzed broken: `@deepseek-ai/dsh-workflow-worker-thread` /
  `@deepseek-ai/dsh-tool-workflow` / `@deepseek-ai/dsh-subagent-in-process-driver`
  0.1.5-rc.2 (installed bundle with fixes 006/013 applied), from drill v6 §7,
  v7 §7 and v8 §7.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - all five patches apply to pristine published sources with their stacks
    applied, no fuzz;
  - `node --check` clean on every patched JS/CJS file;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent;
  - live: a rejected pin inside a workflow records `error` +
    `requestedProvider`/`requestedModel` on `tool-workflow/agent-end` (and the
    route on `agent-start`).
- Pristine sources: `npm pack @deepseek-ai/dsh-subagent-in-process-driver@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-workflow-worker-thread@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-tool-workflow@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-workflow@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `turnDiagnostic`, `diagnostic: result.diagnostic`,
  `requestedProvider: opts.provider`, `error: result.diagnostic ??`,
  `agent.error === void 0 ? {} : { error: agent.error }`,
  `requestedProvider?: string;`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 014 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream enriched the workflow agent events (then mark UPSTREAMED).
