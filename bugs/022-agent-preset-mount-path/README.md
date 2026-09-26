# Bug 022 — the agent-preset session event cannot say how the preset was mounted

Severity: **low** (diagnostic). Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2
bundle. Upstream: **NOT-FILED**.

## Symptoms

A session that starts on Orchestrator through the web UI records

```
line 0: {"type":"session", …, "agentPreset":"standard"}
line 5: agent-preset/selected {"agentPreset":"orchestrator"}
```

and this shape is the **same** whether the session was created directly on
the Orchestrator preset (API `session.create {agentPreset}`) or created on
the default and then moved by the preset picker. The v6/011 mount race is
intermittent, so a retrospective diagnosis cannot tell which mount path a
given session took — the v10 brief's "create this session directly on the
Orchestrator preset" instruction could not even be verified from the log
(v9 §7 #6, v10 §10 #9).

## Root cause

`agent-preset/selected` was appended by exactly one writer —
`AgentPresets.swap()` (the switch path) — as a bare
`{agentPreset}` payload; a direct composition mount (`AgentPresets.mount()`)
recorded nothing at all, relying on the session header. The event therefore
carried no provenance, and the two paths that both end in a
`standard → orchestrator` log shape were indistinguishable.

## Fix design

One write path for the event, with the mount provenance on it:

- `setSessionAgentPreset(session, agentPreset, mountPath, rowMount)` — the
  single appender. The `agentPreset` field keeps its meaning (the
  projection's state); `mountPath` (`"direct" | "switch"`) and `rowMount`
  (`"mounted"`) are diagnostic and never change which composition a session
  runs.
- `mount()` (direct composition at creation, including resume/fork
  composition and the child `composeFrom` callers' parent mount) appends
  `mountPath: "direct"`, `rowMount: "mounted"` after the standing mount
  binds successfully; a failed mount still rolls back before any event is
  written.
- `swap()` (a blank session moved onto another preset) appends
  `mountPath: "switch"`, `rowMount: "mounted"`.
- `SubagentSettledMessageSource`-style type parity: the
  `'agent-preset/selected'` augmentation in
  `dsh-agent-presets/lib/types/session.d.ts` declares the new fields.

With this, the two paths are mechanically distinguishable in the durable log:
a direct creation records one `direct` event (no prior default), the web
create-then-pick flow records `direct` for the default followed by `switch`
for the picker choice — exactly the sequence the 011 investigations needed.

## Rejected alternatives

- **Record a `failed` row-mount outcome in the event.** The projection's
  `apply` sets `agentPreset` from every `agent-preset/selected` event, so a
  failure event carrying the target id would corrupt the effective preset of
  a session that is actually still on its old composition. A failed mount
  keeps its existing surface (the caller's refusal); fix 011's deferral
  warning remains the partial-mount signal. Only the success outcome
  (`rowMount: "mounted"`) is recorded.
- **Derive `mountPath` from the session header instead of recording it.**
  The header names the creation-time preset, not the path: the web's
  create-on-default-then-pick flow has the same header as a direct API
  creation until the picker runs, which is the ambiguity being fixed.
- **A separate event type.** A second event would need its own projection
  rules and ordering guarantees against `agent-preset/selected`; one event
  with classified fields keeps the projection total and replay-safe.
- **Change the web UI to pass `agentPreset` at creation.** Doesn't help
  already-recorded sessions and doesn't make the existing event honest;
  recording provenance is the minimal seam fix.

## Files patched

- `@deepseek-ai/dsh-agent-presets/lib/index.js`
  (`patches/agent-presets-mount-path.patch`)
- `@deepseek-ai/dsh-agent-presets/lib/types/session.d.ts`
  (`patches/agent-presets-session-types.patch`)

`dsh-agent-presets` carries no earlier local patch, so both patches apply to
pristine 0.1.5-rc.2 sources directly.

## Acceptance evidence

See `EVIDENCE.md`. Live on the headless profile with `agent-presets` inserted
by a temporary `--patch` overlay and a probe plugin driving both paths:

- direct mount: `{"agentPreset":"p22-tmp","mountPath":"direct","rowMount":"mounted"}`;
- switch: `{"agentPreset":"p22-alt","mountPath":"switch","rowMount":"mounted"}`.

Both events replay through the unchanged `agentPreset` projection, and
`check.sh` exits 1 pre-fix / 0 post-fix.

**Verification limit (disclosed):** the real web create-then-pick flow could
not be exercised without restarting the user's running `dsh web`, so the live
proof drives the same `AgentPresets.mount()` / `AgentPresets.select()` methods
the web host calls, from a headless session. No web process was touched.
