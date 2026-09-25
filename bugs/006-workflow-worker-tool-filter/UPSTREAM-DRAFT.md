# UPSTREAM DRAFT — workflow workers bypass the delegation leaf policy

Status: NOT-FILED.

---

**Package:** `@deepseek-ai/dsh-workflow-worker-thread` (0.1.5-rc.2, also
0.1.6-alpha.2)

## Summary

`workflow`'s `agent()` children are started with no `toolFilter`. Direct-lane
children (spawned by `@deepseek-ai/dsh-tool-subagent` rows) get the row's leaf
policy, but workflow workers keep the full orchestration surface:
`send_message`, `workflow` (nested), the goal tools, `ralph`,
`ask_user_question`, `list_agents`, `interrupt_agent`. A worker in drill v3
successfully ran a nested `workflow`; v4 measured the whole surface still
present.

The delegation seam already supports the fix end to end —
`SubagentRuntime.start()` forwards `request.toolFilter`, both in-process
providers advertise `capabilities.toolFilter`, and
`applyChildComposition()` applies it as a scoped `restrict()`. The workflow
engine simply never passes one, and its `Config` has no field for it.

## Reproduction

On a preset, run a workflow whose `agent()` asks the child to enumerate
candidates:

```
workflow → agent("From your available tools, reply PRESENT/ABSENT for:
workflow, send_message, create_goal, ralph, list_agents, ask_user_question,
interrupt_agent")
```

Observed (v4, and reproduced here on a pristine 0.1.5-rc.2): all seven are
PRESENT; a nested `workflow` call from the worker succeeds.

## Suggested fix

Add a deployment-owned `toolFilter` (`{ allow?: string[]; deny?: string[] }`)
to `WorkerThreadWorkflowEngine.Config`, validate that it names `allow` or
`deny`, and pass it on every `subagents.start()` call in
`WorkerRun.startChild()`. Do **not** read it from the model-authored `meta` or
script args — the engine owns worker lifecycle, so the engine owns the
worker's capability mask. The unset default must stay byte-identical to
today's behavior (no filter on the request).

A local patch implementing exactly this is in
`bugs/006-workflow-worker-tool-filter/` (verified against the published
0.1.5-rc.2 sources; live probe shows the denied tools absent and the nested
`workflow` unavailable, with the unset default unchanged).
