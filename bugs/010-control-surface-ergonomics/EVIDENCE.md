# Evidence — bug 010

## Primary evidence (reports)

- `~/Desktop/orchestrator-drill-report.md` §7 friction 5, 7 and §8 friction 13:
  - `job_kill` / `job_output` on agent ids →
    `Error: unknown job 74b792ad-d58f-4fe6-9859-2ac8d4b45ef1` /
    `Error: unknown job 01bf8aff-…` ("make the error self-teaching");
  - after a kill, `list_agents` showed the stopped agent `[ready]` while an
    agent settled ~45 s earlier still showed `[running]` ("status is
    stale/lagging");
  - "The lead's own reasoning effort is not visible to the model."
- `~/Desktop/orchestrator-drill-report-v2.md` §8 F5, F9, F10, F11:
  - F5: agent ids are not job ids;
  - F10: "Lead's own reasoning effort is not visible to the model";
  - F11: "`ready` reads like 'not finished'; it actually means
    settled-and-resumable, while `running` covers both 'working' and 'blocked
    in a long tool call'".
- `~/Desktop/orchestrator-drill-report-v4.md` §0 ("My own reasoning effort is
  not visible to me"), §6 (job namespace), §9 friction 10.
- `~/Documents/Projects/DSH/ORCHESTRATOR-OPTIMIZATION-PLAN.md` §14.3 gap 4.

## Source references (pristine 0.1.5-rc.2)

- `@deepseek-ai/dsh-jobs-local/lib/index.js:305` — `expect(id)`:
  `throw new Error(\`unknown job ${id}\`)`.
- `@deepseek-ai/dsh-tool-subagent-control/lib/types/list-agents.js` —
  `statusOf()` sampled the live registry but returned a bare status; no
  timestamp in schema, projection or render.
- `@deepseek-ai/dsh-agent-loop/lib/index.js` — `ctx.systemPrompt.variable(
  "provider"/"model")` existed, but the runtime-context snapshot (rendered by
  `@deepseek-ai/dsh-system-prompt`) carried no route contribution.

## Live re-verification (2026-09-25, installed bundle with the fix)

### job hint (`scripts/job-hint-check.mjs`, installed `LocalJobRegistry`)

```json
{
  "agentId": "unknown job 3c4b4cd4-0f3b-43fc-983c-ad0ab9bafbc1 — that id looks like a subagent/agent id, not a job id; job ids are minted by the jobs service (for example \"bash-1\"), while agent ids belong to list_agents (inspect) and interrupt_agent (stop)",
  "plainUnknown": "unknown job not-a-job"
}
JOB-HINT-CHECK PASS
```

### list_agents timestamp + job hint, one live headless session

Lead task: delegate a background subagent, list agents, then call `job_output`
with the agent id. Lead's verbatim reply (exit 0):

```
Step 2 — `list_agents` returned every line verbatim:
7a07a23f-bac3-4d09-aa14-567e36a04a89 [running as of 2026-09-25T19:45:12.935Z] — READY probe

Step 3 — `job_output` with `job_id = 7a07a23f-bac3-4d09-aa14-567e36a04a89`
returned this exact error verbatim:
Error: unknown job 7a07a23f-bac3-4d09-aa14-567e36a04a89 — that id looks like a
subagent/agent id, not a job id; job ids are minted by the jobs service (for
example "bash-1"), while agent ids belong to list_agents (inspect) and
interrupt_agent (stop)
```

### Runtime-context route, from the session transcript

First step (nothing pinned yet, no request header):

```
This agent's effective route: provider "opencode-go", model
"deepseek-v4.1-flash", reasoning effort unresolved until the first request
(the adapter default applies).
```

After the first request (a `bash` call in the same turn):

```
This agent's effective route: provider "opencode-go", model
"deepseek-v4.1-flash", reasoning effort "high" (resolved).
```

The route line is a named runtime-context section (`agent:route`) in the
durable snapshot (`user/message`, source `@deepseek-ai/dsh-system-prompt`,
`sections[0].name = "agent:route"`).

The same transcript shows the resolved route as the *first* section of the
snapshot; the deployment's sandbox and approval contexts follow.
