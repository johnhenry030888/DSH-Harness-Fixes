# Evidence — bug 011

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v6.md` §1 and §12-B: lead session
  `session-c9f92826-e4f3-45b9-bc28-09391a1bc011` (created on `standard`, switched
  to `orchestrator`, seq 4) advertises **176 tools**; `'subagent' in names →
  False`; `'list_subagent_models' in names → False`; all eight pins + `workflow`
  present. Reproduced once in six mounts; v1/v4 (pre-batch) and v7/v8 (post-batch,
  both paths) were 178.
- `/tmp/opencode/lc007a.err` (this project's own bug-007 live check, 2026-09-25
  21:33) — the boot arm throwing synchronously:
  `dsh: tool-subagent: row "include:tool-subagent" toolFilter names tools absent
  from the child catalog: …`.
- Source: `@deepseek-ai/dsh-agent/lib/index.js:546-556` (`announce()` contains
  promise rejections only; a synchronous throw escapes through
  `register()`'s generator effect).
- Source: `@deepseek-ai/dsh-agent` `EntryGroup.update` (`Promise.allSettled` over
  rows) — the concurrency that makes the boot arm's view incomplete.

## Fix markers (checked by `scripts/check.sh`)

- `boot toolFilter validation deferred for agent` and
  `the row's pre-spawn check re-validates` in
  `dsh-tool-subagent/lib/index.js`.
- The `agent/created` listener's first statement is `try {`; the bare
  `assertKnownToolFilterNames(...)` call is gone.

## Live re-verification (2026-09-26, installed bundle, `dsh web` on 3080)

### Switch path, three sessions (drill-v6 acceptance)

All three were created on `standard` and switched to `orchestrator` in the UI,
then asked one question; the numbers below are read from each session's own
`request/header.tools` (not self-report):

| session | created preset | selected preset | tools | `subagent` | `list_subagent_models` | `workflow` |
| --- | --- | --- | --- | --- | --- | --- |
| `session-62c4ace0-e231-4de9-8146-21dcd41846d9` | standard | orchestrator | **178** | yes | yes | yes |
| `session-bfcdbb55-f0ed-471d-a5f9-226211cbdcce` | standard | orchestrator | **178** | yes | yes | yes |
| `session-bddb308e-68e1-4ef3-ad74-4aeb3fd14d75` | standard | orchestrator | **178** | yes | yes | yes |

All eight pins (`subagent_build`, `subagent_build2`, `subagent_fast`,
`subagent_fork`, `subagent_mech`, `subagent_review`, `subagent_verify`,
`subagent_vision`) and `workflow` are present in all three. Transcripts:
`~/.dsh/sessions/--home-john-Documents-Projects-DSH--/<id>/session.v3.jsonl.zstd`.

A fourth switch-path session (`session-cf26ff18-759a-47e1-aec7-72b083285e82`,
standard → orchestrator) was created on the **restarted host** after the final
installed bundle was in place — also 178 tools with both names.

Direct path (created on orchestrator) is unchanged at 178 — drill v8 §1 recorded
both paths at 178, and the same deployment served the direct path again in the
v9 probes (session `dc37f2a3` on orchestrator).

### Bug 007's protection intact (bogus filter name)

Temporary preset copy `orchestrator-bogus` (`~/.dsh/.agent-presets/`, the user's
preset untouched) with `subagnt_fast` prepended to the generic row's deny list.
Session `session-cc817fa7-ca24-4b06-81e3-dbdd9fd741c1` (standard → orchestrator-bogus):

- The session **mounted** (178 tools, both names present) — pre-fix this
  configuration aborted agent creation at boot (bug 007 `EVIDENCE.md`, "Bogus
  name" section).
- Its first `subagent` call failed verbatim, naming the row:
  `Error: tool-subagent: row "include:agent-presets:tool-subagent" toolFilter
  names a tool absent from the child catalog: "subagnt_fast" — correct the name
  or remove it from the filter`.

### No `agent/created` rejection

`grep -iE "agent/created listener (rejected|threw)"` over the web host log for the
whole session run: no matches. The boot arm's deferral diagnostic
(`boot toolFilter validation deferred for agent`) also produced no line — the
catalog was complete on every mount in this run; the deferral path itself is
exercised by the module-level probe in this folder's check history and by the
`orchestrator-bogus` mount, which no longer aborts creation.

## Commands

```bash
# tool count and name presence from a session transcript
zstd -dc ~/.dsh/sessions/--home-john-Documents-Projects-DSH--/session-<id>/session.v3.jsonl.zstd \
  | python3 -c "import sys,json
for l in sys.stdin:
    d=json.loads(l)
    if d.get('type')=='request/header':
        names=[t['name'] for t in d['data']['header']['tools']]
        print(len(names), 'subagent' in names, 'list_subagent_models' in names)"
```
