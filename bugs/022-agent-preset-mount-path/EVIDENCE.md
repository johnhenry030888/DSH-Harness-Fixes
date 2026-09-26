# Evidence — bug 022

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v9.md` §7 #6 and
  `~/Desktop/orchestrator-drill-report-v10.md` §10 #9: session line 0 reads
  `agentPreset: "standard"` and the next preset event is
  `agent-preset/selected {"agentPreset":"orchestrator"}` for both the
  operator's "direct on Orchestrator" session and the lead's switch-path
  session; the v10 brief's direct creation could not be confirmed from the
  log.
- Source: only `AgentPresets.swap()` appended the event, as
  `{ agentPreset }`; `AgentPresets.mount()` recorded nothing.

## Fix markers (checked by `scripts/check.sh`)

- `function setSessionAgentPreset(session, agentPreset, mountPath, rowMount)`
- `setSessionAgentPreset(session, preset.id, "direct", "mounted");`
- `setSessionAgentPreset(agent.session, preset.id, "switch", "mounted");`
- the pre-022 bare
  `agent.session.append("agent-preset/selected", { agentPreset: preset.id });`
  is gone;
- `mountPath: 'direct' | 'switch';` in
  `dsh-agent-presets/lib/types/session.d.ts`.

## Live verification (2026-09-26, installed bundle, headless profile)

The headless profile mounts no `agent-presets` plugin, so a temporary
`--patch` overlay inserted it plus a probe plugin
(`scripts/fixture/preset.patch.yml`, `scripts/fixture/probe.js`; live copies
in `/tmp/opencode/p22-live/`). Two temporary user presets were copied from
the shipped ones (`p22-tmp` ← `standard`, `p22-alt` ← `minimal`); both were
deleted after the run and the user's `orchestrator` preset was never touched.

The probe calls the same service methods the web host calls:
`agentPresets.mount(agent.ctx, 'p22-tmp')` on `agent/created` (direct), and
`agentPresets.select(agent, 'p22-alt')` (switch).

Direct run (probe mounts only), session
`session-dfa78142-6896-4e13-8ad9-c191ef6671e3`:

```
EVENT seq=6 time=1790415397994
data={"agentPreset": "p22-tmp", "mountPath": "direct", "rowMount": "mounted"}
```

Switch run (probe selects only), session
`session-cc2c51c6-857b-47c8-853c-ae4dd4dd5f39`:

```
EVENT seq=6 time=1790415439806
data={"agentPreset": "p22-alt", "mountPath": "switch", "rowMount": "mounted"}
```

Both headless runs printed `pong` (exit 0), i.e. the session still composed
and ran under the recorded preset; `mount()` and `select()` both resolve with
the event written only after the mount succeeded.

First attempt (honest note): a probe that awaited `mount()` and then called
`select()` lost the race against headless's immediate first turn —
`select` refused with `session "…" has already started; its agent preset is
fixed`, which is the pre-existing blank-session lock, not a 022 regression.
The switch probe was re-run without the preceding mount and recorded cleanly.

## Commands

```bash
# live (temp overlay + temp presets; cleaned up afterwards)
dsh --profile headless --patch /tmp/opencode/p22-live/preset.patch.yml "Reply with exactly the single word: pong"

zstd -dc ~/.dsh/sessions/--home-john-Documents-DSH-Harness-Fixes--/session-dfa78142-6896-4e13-8ad9-c191ef6671e3/session.v3.jsonl.zstd \
  | grep -o '"agentPreset": "p22-tmp"[^}]*}'
zstd -dc ~/.dsh/sessions/--home-john-Documents-DSH-Harness-Fixes--/session-cc2c51c6-857b-47c8-853c-ae4dd4dd5f39/session.v3.jsonl.zstd \
  | grep -o '"agentPreset": "p22-alt"[^}]*}'
```
