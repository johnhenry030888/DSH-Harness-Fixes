# Upstream draft — bug 022

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `agent-preset/selected` cannot say how the preset arrived: direct
composition and a picker switch log the same shape

**Body:**

Two different mount paths produce the same durable session log:

1. a session created directly on a preset (the API's create call names it);
2. a session created on the default preset and then moved by the preset
   picker (which always calls `AgentPresets.select`).

Both can read `line 0 agentPreset: "standard"` followed by
`agent-preset/selected {"agentPreset":"orchestrator"}` — and an intermittent
mount race (the v6/011 regression) is exactly the kind of event you want to
diagnose from the log months later. Today the event carries only the target
id, and a direct mount writes no event at all.

Proposal: one write path for the event
(`setSessionAgentPreset(session, agentPreset, mountPath, rowMount)`) and two
recorded paths:

- `mount()` appends `{agentPreset, mountPath: "direct", rowMount: "mounted"}`
  after the standing composition binds;
- `swap()` appends `{agentPreset, mountPath: "switch", rowMount: "mounted"}`.

The projection keeps reading only `agentPreset`, so replay is unchanged; a
failed mount rolls back before any event and keeps its existing caller-facing
refusal (this is why no `failed` event is written: the projection would adopt
the target id for a session that never left its old composition). The
`agent-preset/selected` type augmentation gains
`mountPath: 'direct' | 'switch'` and `rowMount?: 'mounted'`.
