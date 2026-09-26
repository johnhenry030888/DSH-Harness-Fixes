# Bug 018 — a child layer keeps the lead's system prompt while its tools are filtered

Severity: **high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

A child layer (fork or worker) keeps the **orchestrator-lead system prompt** —
lane map included, telling it to use `subagent_fork`, `list_agents` and the goal
tools — while its live catalog is the filtered one. Two escalation levels:

- **v7:** the fork child tried those tools and got `unknown tool`; bare
  `subagent` returned `subagent depth 2 exceeds maxDepth 1`. Nothing in its
  context named the removed tools.
- **v8, live and worse:** the **seeded** second-turn fork inherited the lead's
  entire turn-1 context, **self-identified as the orchestrator lead**, and began
  re-running the drill (`subagent_fork`, `subagent_fast`) before the lead
  interrupted it. Containment held, but the child spent its turn impersonating
  the parent.

The same asymmetry showed up as descriptors missing their `toolFilter` (v7
#6/#12, v8 #4): the depth-1 child declared the 17-name filter, the workflow
worker's descriptor was only `{"version":3,"mode":"one-shot","provider":"spawn"}`.

## Root cause

- The child's only layer-level statement was the trailing
  `You are a delegated subagent: your permission scope was fixed …` context —
  which says nothing about identity or removed tools, and (for a seeded fork)
  arrives *after* a full copy of the parent's lead prompt.
- `applyChildComposition` applied the `toolFilter` via `tools.restrict()` but
  never told the child what was removed.
- `SubagentRuntime.start` snapshotted a one-shot descriptor with
  `{version, mode, provider, label?}` only — `toolFilter` was continuable-only.

## Fix design

Make the layer self-describing and self-locating:

1. **Leading layer banner** (`subagent:layer`, context order 118, before the
   delegation-scope line): names the parent session, states the agent is a
   continuation/subagent of that parent and **not** the orchestrator lead, and
   names the tools the filter removed (deny lists) or the effective set (allow
   lists). `restrictChildTools` now returns what it applied.
2. **Descriptors declare the filter**: `ONE_SHOT_DESCRIPTOR_KEYS` accepts
   `toolFilter`, the snapshot writes it, and `SubagentRuntime.start` records
   `request.toolFilter` — so one-shot forks and workflow workers carry the same
   audit block as continuable children. This also covers the optional 015.
3. The banner is a runtime-context contribution, not a persona/system-prompt
   replacement: a child-appropriate system prompt is a larger change (the lead
   prompt is composed by the preset the child joins), so it is recorded here as
   the follow-up rather than half-done.

## Rejected alternatives

- **Swap the child's system prompt for a child-appropriate one.** The child
  joins the parent's preset (`composeFrom`), which is what gives it the parent's
  tool rows; a separate child prompt means a separate preset composition. The
  banner fixes the observable failure (identity + removed tools) without
  re-architecting preset inheritance.
- **A filter-based only message ("some tools were removed").** The drill's
  acceptance requires the child to state *which* tools; naming them is the
  point.
- **Rewrite `tools.restrict()` to inject the notice.** The delegation seam owns
  child composition and has the label/filter context; the tools registry stays
  a policy primitive.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-layer-banner-and-descriptor-filter.patch`, stacks on
  007/013)
- `@deepseek-ai/dsh-system-prompt/lib/index.js`
  (`patches/dsh-system-prompt-layer-order.patch`, stacks on 010)

## Acceptance evidence

See `EVIDENCE.md`. A cold fork child, a seeded fork child and a workflow worker
each answered, from their own context and without probing:

```
LAYER=continuation of session-<parent>
REMOVED=send_message, list_agents, interrupt_agent, subagent_fast, subagent_mech,
        subagent_build, subagent_build2, subagent_verify, subagent_review,
        subagent_vision, subagent_fork, workflow, ralph, create_goal, get_goal,
        update_goal, ask_user_question
```

and the worker's `subagent/descriptor` now declares the 17-name `toolFilter`.
The `unknown tool` signal is *not* required (model-dependent per v8 §7); both
children answered from context, which is the stronger path.
