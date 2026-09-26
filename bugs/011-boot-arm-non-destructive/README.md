# Bug 011 — fix 007's boot arm removes the lead's generic delegation tool (mount race)

Severity: **high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

After the 006–010 batch an Orchestrator session's lead mounted with **176 tools and
neither `subagent` nor `list_subagent_models`**, while all eight pinned lanes and
`workflow` were present. Children still had both names, so only the lead's
model-selection row's own-layer registrations were lost. The failure reproduced
once in six observed mounts (drill v6 session `c9f92826`, created on `standard`
then switched to `orchestrator`); three later switch-path mounts were clean.

The throw itself is on record in this project's own live check
(`/tmp/opencode/lc007a.err`, 2026-09-25 21:33):

```
dsh: tool-subagent: row "include:tool-subagent" toolFilter names tools absent
from the child catalog: "list_subagent_models", "subagent_fast", … —
correct the name or remove it from the filter
```

## Root cause

Fix 007 added a validation arm in `@deepseek-ai/dsh-tool-subagent`:

```js
if (config.toolFilter !== void 0) ctx.on("agent/created", ({ agent }) => {
    assertKnownToolFilterNames(ctx.tools, scopeOf(agent.ctx), config, rowLabel);
});
```

Its doc comment claimed "a cordis `agent/created` listener rejection is contained
and logged by the Agent registry". That is only true for **asynchronous**
rejections: `agents.announce()` (`@deepseek-ai/dsh-agent/lib/index.js:546-556`)
catches a returned promise, but a **synchronous** throw propagates out of the
`for (const callback of this.ctx.events.dispatch(...))` loop, through
`announce()`, through `register()`'s generator effect, and aborts agent creation.
The effect rollback then drops the row's own-layer registrations — exactly the
`subagent` + `list_subagent_models` pair a `modelSelectionSettings` row installs
per agent (`installScoped` → `candidate.ctx.inject(...)`) — while sibling rows'
pins survive.

The race: a standing composition mounts its rows concurrently
(`EntryGroup.update` uses `Promise.allSettled`), so a boot arm that runs before a
sibling row has applied sees that sibling's tool as unknown. The check is
correct; its placement in a synchronous, creation-aborting listener is not.

## Fix design

1. The boot arm **never throws**: it catches its own validation failure and logs a
   named diagnostic (row id, agent id, offending names), then defers.
2. The **pre-spawn arm** in the row's own `execute` is unchanged and remains the
   hard failure — it runs when the catalog is complete and fails *that row's
   spawns* with the row id.
3. The check still tolerates the row's own registrations (`toolName`,
   `list_subagent_models`) regardless of ordering; that was already true and is
   unchanged.
4. Re-verification is by **repetition** on the real switch path (three sessions),
   plus a bogus-name probe proving the row-level failure still fires.

## Rejected alternatives

- **Wrap the listener in `Promise.resolve()` / make it async.** A promise
  rejection is contained, but the validation would then race the catalog anyway
  and the diagnostic would be logged by the registry's generic
  `agent/created listener rejected` line without the row id. The explicit
  try/catch names the row and states the deferral.
- **Move the check to `tools/change`.** `tools/change` fires for every tool
  registry change, including a child's own registrations; a standing
  composition's incompleteness is not distinguishable there without more state.
- **Delete the boot arm.** It is the only signal for a row that never spawns;
  keeping it as a named diagnostic preserves the v3 protection's audit trail.
- **Make `agents.announce()` contain synchronous throws.** That changes the
  Agent registry's creation contract for every listener (a listener could
  legitimately reject a creation) to serve one caller.

## Files patched

- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-boot-arm-non-destructive.patch`, stacks on 007/008/009)

## Acceptance evidence

See `EVIDENCE.md`. Summary: three sessions created on `standard` and switched to
`orchestrator` each mounted **178 tools with `subagent` + `list_subagent_models`**
(sessions `62c4ace0`, `bfcdbb55`, `bddb308e`); a bogus filter name still fails its
own spawn with the row id; no `agent/created` rejection appears.
