# Bug 010 — control-surface ergonomics

Severity: **medium/low**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2
bundle. Upstream: **NOT-FILED**.

Three independent control-surface defects from the drill series.

## 010a — `job_output`/`job_kill` on an agent id

**Symptoms.** Passing a subagent id (a UUID) to `job_output`/`job_kill`
returns `unknown job <uuid>` with no hint; three drills hit this (v1 §7
friction 5, v2 §8 F5, v4 §9 friction 10). The persona/drill text implies the
tools are interchangeable with `list_agents`.

**Root cause.** `@deepseek-ai/dsh-jobs-local/lib/index.js:305` —
`expect(id)` threw the bare `unknown job ${id}`. Agent ids and job ids are
different namespaces by design (`job ids are service-minted labels such as
`bash-1`), but the error did not say so.

**Fix.** On a miss, if the id has the UUID shape the subagent runtime mints,
append a teaching hint:

```
unknown job <uuid> — that id looks like a subagent/agent id, not a job id;
job ids are minted by the jobs service (for example "bash-1"), while agent ids
belong to list_agents (inspect) and interrupt_agent (stop)
```

Non-UUID unknown ids keep the original message exactly.

**Rejected.** Accepting agent ids in the job tools — the namespaces are
deliberately separate (a job is a process, an agent is a conversation); the
ergonomic gap is the diagnostic, not the API.

## 010b — `list_agents` status reads as a durable outcome

**Symptoms.** v1 §7 friction 7: after a kill the stopped agent showed
`[ready]` while an agent that had settled ~45 s earlier still showed
`[running]`. v2 §8 F11: `ready` reads like "not finished"; `running` covers
both "working" and "blocked in a long tool call". v4 repeated it.

**Root cause.** `@deepseek-ai/dsh-tool-subagent-control/lib/types/list-agents.js`
already sampled the live Agent registry at read time, but presented the sample
as a bare status word with no timestamp, so a caller could not tell a
read-time sample from a durable outcome.

**Fix.** Each child row now carries `checkedAt` (ISO timestamp of the registry
sample, one stamp per listing) in the schema, the JSON entries and the rendered
line (`<id> [running as of 2026-09-25T19:45:12.935Z] — <label>`), and the tool
description states the sampling contract and that a settlement notice is the
authoritative completion signal. Status values are unchanged, so no consumer
breaks.

**Rejected.** Distinguishing `working` / `awaiting-tool` / `settled-resumable`
(F11's suggestion) — the live registry only exposes `idle`/`running`, and
deriving more would guess; the timestamp makes the existing vocabulary honest.
Also rejected: blocking the tool on `whenIdle()` to "make it truthful" — that
would turn a discovery call into a wait.

## 010c — the agent cannot see its own resolved model/effort

**Symptoms.** Every drill asked the lead for its own model/effort and could not
answer; it was inferred from persona prose (v1 §7, v2 §8 F10, v4 §0). "My own
reasoning effort is not visible to me."

**Root cause.** The runtime-context snapshot carried sandbox and approval
policy but no route; the loop's `provider`/`model` prompt *variables* are only
usable by sections that reference them, and no such section existed.

**Fix.** A new centrally ordered runtime-context contribution
(`AGENT_ROUTE: 105` in `@deepseek-ai/dsh-system-prompt`) registered by
`@deepseek-ai/dsh-agent-loop` renders, for every agent:

```
This agent's effective route: provider "opencode-go", model
"deepseek-v4.1-flash", reasoning effort "high" (resolved).
```

- pinned effort → `"low" (pinned)`;
- resolved from the durable request header with adapter defaults →
  `"high" (adapter default)` / `"high" (resolved)`;
- before the first request with nothing pinned → `unresolved until the first
  request (the adapter default applies)` — deliberately not guessed.

Because the snapshot is committed before each model request, the effort is
visible from the second step onward (and after any first tool call); the first
step honestly reports it as unresolved.

**Rejected.** Reading the model-selection plugin's private `selection` object —
not a public seam; guessing the deployment default — could be wrong for a
session whose route was changed by the model picker.

## Files patched

- `@deepseek-ai/dsh-jobs-local/lib/index.js`
  (`patches/dsh-jobs-local-agent-id-hint.patch`)
- `@deepseek-ai/dsh-tool-subagent-control/lib/types/list-agents.js`
  (`patches/dsh-tool-subagent-control-status-timestamp.patch`)
- `@deepseek-ai/dsh-agent-loop/lib/index.js`
  (`patches/dsh-agent-loop-route-context.patch`)
- `@deepseek-ai/dsh-system-prompt/lib/index.js`
  (`patches/dsh-system-prompt-route-order.patch`)

## Acceptance evidence

- `scripts/check.sh` exit 1 before, 0 after; `reapply.sh` idempotent;
  `node --check` on all four files.
- `scripts/job-hint-check.mjs` (installed `LocalJobRegistry`): UUID → hint with
  `list_agents`/`interrupt_agent`; non-UUID → exact original message.
- Live headless: `list_agents` rendered
  `7a07a23f-… [running as of 2026-09-25T19:45:12.935Z] — READY probe`;
  `job_output` on that agent id returned the teaching hint.
- Live headless transcript: the runtime-context snapshot contains
  `This agent's effective route: provider "opencode-go", model
  "deepseek-v4.1-flash", reasoning effort "high" (resolved).` after the first
  request, and the unresolved form on the first step.
