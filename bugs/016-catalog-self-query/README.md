# Bug 016 — no self-query for the agent's own tool catalog

Severity: **low** (wrong self-reports propagate into plans and audits). Local
fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

No surface let an agent measure its own catalog, so counts were guessed:

- drill v10: the **lead** hand-counted **177** where the header recorded
  **178**;
- drill v9/v12: children claimed 137 and 157 where their headers recorded 161
  (the 027 banner now injects that number, but there was still no way to ask);
- drill v12 §5.1: a child conceded "161" was an unverifiable hand count.

## Root cause

The advertised catalog is assembled per request from `ToolRuntime.view(scope)`
and reaches the model only as the request's tool array (or a generated PTC
SDK prompt). No tool exposed that view to the agent itself; the closest
surface, `list_subagent_models`, only answered LLM-route questions.

## Fix design

`list_subagent_models` gains a third, mutually exclusive mode:

```
list_subagent_models({ catalog: true })
→ {"count":178,"names":["agent_route",…]}
```

The JSON string is produced by `listAgentCatalog(ctx, exec)`, which resolves
the **calling agent's** scoped context (`exec.agent.ctx`), reads
`tools.view(scopeOf(runtimeCtx)).visible`, and returns the count plus sorted
names. This is the same view the restriction filter (`restrictChildTools`) and
the 027 banner read, so all three agree with the request header in native
presentation.

Why this tool: `list_subagent_models` is registered in every agent layer
(lead and child) and is deliberately exempt from `tools.restrict()`, so every
caller in the shipped Orchestrator preset — including workers that deny
`list_agents` — can query it without preset changes. Do not break the name
that preset rows already configure.

## Rejected alternatives

- **A new global `list_tools` tool.** It would inflate every deployment's
  advertised catalog by one exactly where the catalog is the measurement
  (178→179 breaks the mount arithmetic the drills rely on and makes
  `161 = 178 − 17` false). A self-inventory query must not change the inventory
  it measures.
- **Extend `list_agents`.** Children in the shipped preset deny `list_agents`,
  so the child half of the acceptance could only be met by editing the user's
  preset; the tool's strict `oneOf` row schema also has no room for a scalar
  catalog row.
- **Report the count through a runtime-context line.** That is 027's job for
  children; the lead has no banner and needs an on-demand query, and bytes on
  every request are the cost this mode avoids.
- **Answer from the last `request/header` event.** Requires reading session
  history for a live fact; the registry view is O(#tools) and authoritative.

## Files patched

- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-catalog-query.patch`; stacks on bugs
  007/008/009/011/012/019/024 of the same file)

## Acceptance evidence

See `EVIDENCE.md`. Live: the lead and a child each called
`list_subagent_models({catalog:true})` and the returned counts equal their own
`request/header` tool arrays (shown side by side); the 027 banner and the query
agree.
