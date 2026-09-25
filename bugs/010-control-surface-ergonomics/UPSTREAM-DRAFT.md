# UPSTREAM DRAFT — control-surface ergonomics (jobs hint, list_agents status, own route)

Status: NOT-FILED.

---

**Packages:** `@deepseek-ai/dsh-jobs-local`,
`@deepseek-ai/dsh-tool-subagent-control`, `@deepseek-ai/dsh-agent-loop`,
`@deepseek-ai/dsh-system-prompt` (all 0.1.5-rc.2)

## 1. `job_output`/`job_kill` on an agent id

`expect(id)` throws the bare `unknown job <id>` for any miss, including a
subagent UUID (three drills hit this). Suggested: when the id has the UUID
shape, append a teaching hint —

> that id looks like a subagent/agent id, not a job id; job ids are minted by
> the jobs service (for example "bash-1"), while agent ids belong to
> `list_agents` (inspect) and `interrupt_agent` (stop)

Non-UUID unknown ids keep the original message.

## 2. `list_agents` status is presented as a durable outcome

`statusOf()` samples the live Agent registry at read time, but the row shows a
bare `running`/`idle`/`ready`, so a caller cannot tell a sample from an
outcome (v1 saw `[ready]` for a just-killed agent and `[running]` for one that
had settled). Suggested: add a per-listing `checkedAt` ISO timestamp to the
schema, entries and rendered line (`<id> [running as of <iso>] — <label>`), and
say in the description that a settlement notice is the authoritative
completion signal. Status values stay unchanged.

Rejected: inventing `working`/`awaiting-tool`/`settled-resumable` states — the
live registry only exposes `idle`/`running`, and deriving more would guess.

## 3. The agent cannot see its own resolved model/effort

Every drill asked and could not answer; the route was inferred from persona
prose. Suggested: register a runtime-context contribution (new centrally
ordered `AGENT_ROUTE` slot in `dsh-system-prompt`) from `dsh-agent-loop` that
renders, per agent:

> This agent's effective route: provider "opencode-go", model
> "deepseek-v4.1-flash", reasoning effort "high" (resolved).

Pinned efforts render `(pinned)`, adapter defaults `(adapter default)`, and
before the first request with nothing pinned the line says `unresolved until
the first request (the adapter default applies)` rather than guessing. The
route becomes visible from the second step onward (the snapshot is committed
per pre-step).

## Local patch

`bugs/010-control-surface-ergonomics/` carries all four patches plus
`job-hint-check.mjs` and live evidence.
