# Upstream draft — bug 011

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `agent/created` listener throws abort agent creation (a synchronous
rejection is not contained)

**Body:**

`agents.announce()` contains *asynchronous* `agent/created` listener rejections
(and `agent/disposed` throws/rejections), but a **synchronous** throw propagates
out of the dispatch loop, through `announce()`, through `register()`'s generator
effect, and aborts agent creation. The effect rollback then drops registrations
the row made in that agent's own layer.

Reproduction (0.1.5-rc.2): a `tool-subagent` row registers

```js
ctx.on("agent/created", ({ agent }) => {
    assertKnownToolFilterNames(ctx.tools, scopeOf(agent.ctx), config, rowLabel);
});
```

A standing preset composition mounts its rows concurrently
(`EntryGroup.update` uses `Promise.allSettled`). If this listener runs before a
sibling row has applied, a sibling's tool looks unknown, the check throws, and
the agent creation rolls back — losing, in our observation, the
`modelSelectionSettings` row's own-layer `subagent` + `list_subagent_models`
registrations (lead: 176 tools instead of 178) while sibling pins survived. One
mount in six.

Two independent issues:

1. **A synchronous listener throw should not abort agent creation.** Either
   contain it like the async case (log and continue), or make the contract
   explicit that a listener may veto creation and document the rollback
   semantics.
2. **The registry's containment is asymmetric** — a listener that returns a
   rejected promise is logged, the same listener throwing synchronously tears
   down the creation. That asymmetry is easy to miss when writing a listener.

Workaround we ship locally: the validation listener catches its own failure,
logs a row/agent-named diagnostic, and defers to the row's pre-spawn check (the
point where the catalog is complete), which remains a hard failure. Happy to
send a patch if the maintainers want the boot arm to stay a hard failure instead
— that would need the registry to contain sync throws, or an explicit
`agent/created`-veto contract.
