# Evidence — bug 006

## Primary evidence (reports)

- `~/Desktop/orchestrator-drill-report-v3.md` §3a/§3b, §8 friction 1–2:
  - `dsh-workflow-worker-thread/lib/worker.cjs` contains **no `toolFilter` and
    no `restrict(` reference at all** (source-level check quoted in §3b).
  - Worker probe verbatim: `workflow(meta={"name":"x",...}, script="return 1")`
    → `SUCCEEDED` → `workflow "x" completed (0 agents). Return value: 1`.
  - `send_message(agent_id="probe-nonexistent", message="hi")` →
    `Error: subagent "probe-nonexistent" is unavailable` (tool present).
  - `create_goal(objective="x")` →
    `Error: this goal operation requires a direct human turn on a top-level agent`
    (tool present, policy-denied).
- `~/Desktop/orchestrator-drill-report-v4.md` §4b: the worker's self-reported
  catalog keeps `send_message`, `workflow`, `create_goal`, `get_goal`,
  `update_goal`, `ralph`, `ask_user_question`, `list_agents`,
  `interrupt_agent`; the direct child's catalog has none of them.
- `~/Desktop/orchestrator-drill-evidence-v3.json` / `-v4.json`
  (`structural_workflow_worker`).
- `~/Documents/Projects/DSH/ORCHESTRATOR-OPTIMIZATION-PLAN.md` §13.5 gap 1 and
  §14.2 finding 1 ("the single largest hole; needs an engine-side change").

## Source references (pristine 0.1.5-rc.2)

- `@deepseek-ai/dsh-workflow-worker-thread/lib/index.js`
  - `startChild()` `subagents.start(this.provider, {…})` — no `toolFilter`.
  - `WorkerThreadWorkflowEngine.Config` — no `toolFilter` field.
  - `lib/worker.cjs` — no `toolFilter`/`restrict(` reference.
- `@deepseek-ai/dsh-subagent/lib/index.js`
  - `SubagentRuntime.start()` forwards `request.toolFilter` (line ~3145).
  - `applyChildComposition()` applies it as a scoped `restrict()` (line ~542).
- `@deepseek-ai/dsh-subagent-spawn-in-process/lib/index.js`
  - `capabilities = { … toolFilter: true … }` (the provider supports it).

## Live re-verification (2026-09-25, installed bundle with the fix)

Host row overridden for the run only, via a temporary `--patch` overlay
(`/tmp/opencode/livecheck/006.yml`); no file under `~/.dsh` was edited:

```yaml
- id: workflow-worker-thread
  config:
    provider: spawn
    toolFilter:
      deny: [workflow, send_message, create_goal, get_goal, update_goal, ralph,
             ask_user_question, list_agents, interrupt_agent, list_subagent_models]
```

Run A (filter set), headless, worker catalog probe (verbatim):

```
workflow: ABSENT
send_message: ABSENT
create_goal: ABSENT
ralph: ABSENT
list_agents: ABSENT
ask_user_question: ABSENT
interrupt_agent: ABSENT
```

Nested `workflow` attempt from inside the worker (verbatim reply):
`"ABSENT-TOOL"` — the tool is not in the worker's catalog.

Run B (no overlay, option unset), same probe (verbatim):

```
workflow: PRESENT
send_message: PRESENT
create_goal: PRESENT
ralph: PRESENT
list_agents: PRESENT
ask_user_question: ABSENT
interrupt_agent: PRESENT
```

(`ask_user_question` is absent from the plain headless host composition for
workers; v4's orchestrator preset mounts it. Its absence here is a property of
the composition under test, not of the filter — the other six rows prove the
default is unchanged.)

Commands: `dsh --profile headless [--patch …] "<probe task>"`, exit 0.
