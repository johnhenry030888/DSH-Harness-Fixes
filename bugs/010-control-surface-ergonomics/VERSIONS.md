# Versions — bug 010

- First analyzed broken: `@deepseek-ai/dsh-jobs-local`,
  `@deepseek-ai/dsh-tool-subagent-control`, `@deepseek-ai/dsh-agent-loop` and
  `@deepseek-ai/dsh-system-prompt` 0.1.5-rc.2 (installed bundle, 2026-09-25),
  with drill evidence from the v1/v2/v4 reports. Upstream 0.1.6-alpha.2 has
  none of the four changes.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-25):
  - all four patches apply to the pristine published sources with no fuzz;
  - `node --check` clean on all four files;
  - `scripts/check.sh` exit 0 with the fix, exit 1 on pristine copies;
  - `scripts/reapply.sh` idempotent;
  - `scripts/job-hint-check.mjs` passes against the installed
    `LocalJobRegistry`;
  - live headless session: timestamped `list_agents` row, teaching job hint,
    and the `agent:route` runtime-context section in the durable transcript.
- Pristine sources for diffing: `npm pack @deepseek-ai/dsh-jobs-local@0.1.5-rc.2`,
  `@deepseek-ai/dsh-tool-subagent-control@0.1.5-rc.2`,
  `@deepseek-ai/dsh-agent-loop@0.1.5-rc.2`,
  `@deepseek-ai/dsh-system-prompt@0.1.5-rc.2`.
- Fix markers checked by `scripts/check.sh` (never the version):
  - `AGENT_ID_LIKE` and `looks like a subagent/agent id, not a job id` in
    `dsh-jobs-local`;
  - `checkedAt` and the render timestamp in `dsh-tool-subagent-control`;
  - `function renderAgentRoute(` and `This agent's effective route:` in
    `dsh-agent-loop`;
  - `AGENT_ROUTE: 105` in `dsh-system-prompt`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 010 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate (code
  moved?) or check whether upstream added the hint/timestamp/route context
  (then mark UPSTREAMED in root `STATUS.md`).
