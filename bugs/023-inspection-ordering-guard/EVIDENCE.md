# Evidence — bug 023

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v10.md` §21.2 (in the optimization
  plan) / v10 report §6: `subagent_verify` mutated in place and the
  concurrently-running reviewer reported **3 failed** tests that were really
  the verifier's mutation; the reviewer diagnosed the interference itself.
- `~/Desktop/orchestrator-drill-report-v11.md` §6.2: the lead dispatched
  review-A while verify-A was still live (`review-A` recorded as an
  **overlapped run, not as the sequencing proof**), saved only because the
  verifier mutated a private copy; §6.3 records
  `concurrent_writer_observed: no` for the re-review.
- Drill v11 §10 friction #1 and §11 recommendation 1: "The harness does not
  stop the lead from dispatching a review while a verify lane is still live …
  Expose a per-tree 'inspection in progress / settled' state … and have
  `subagent_review` warn or refuse when a same-tree write-capable verify child
  is live."

## Fix markers (checked by `scripts/check.sh`)

- `dsh-subagent`: `function treesOverlap(left, right)`,
  `function inspectionConflicts(ctx, parent, readOnlyRequested)`,
  `function assertInspectionOrdering(ctx, parent, readOnlyRequested)`,
  `"INSPECTION_CONFLICT"`,
  `assertInspectionOrdering(this.ctx, spec.request.parent, spec.request.readOnly)`,
  `assertInspectionOrdering(this.ctx, request.parent, request.readOnly)`,
  `sandboxPolicy?.overrideOf(candidate.session) === "read-only"`.
- `dsh-tool-subagent-control/lib/types/list-agents.js`:
  `filePolicy: sandboxPolicy.overrideOf(live.session) === 'read-only' ? 'read-only' : 'writes'`,
  `entry.filePolicy`, `const sandboxPolicy = ctx.get('sandboxPolicy');`.

## Module-level check

`node bugs/023-inspection-ordering-guard/scripts/inspection-check.mjs`
(extracts the shipped `treesOverlap` from the installed bundle and evaluates
it):

```
ok: same path
ok: child beneath parent
ok: parent above child
ok: sibling with shared prefix string   (/work/project vs /work/project-2 → false)
ok: unrelated trees
ok: missing cwd is conservative
ok: missing cwd on the other side
ok: trailing separators normalize
INSPECTION-CHECK PASS
```

## Live verification (2026-09-26, installed bundle, headless profile)

The headless profile mounts no agent presets, so a temporary `--patch` overlay
(`scripts/fixture/ro-row.patch.yml`, live copy in
`/tmp/opencode/batch4/p23-live/`) added one `@deepseek-ai/dsh-tool-subagent`
row with `readOnly: true` — the same `config.readOnly` → composition →
`sandbox/mode` read-only path the Orchestrator `tool-subagent-review` row
uses. The user's presets were untouched.

Session transcript root:
`~/.dsh/sessions/--tmp-opencode-batch4-p23-live--/`

- Lead `session-1dd23223-9bbc-43b6-81ff-34c4df483313`
- Writer (write-capable `subagent`, continuable, `sleep 40`):
  `b72a493a-ea4c-4926-8a1f-fc468c44302d`
- Read-only lane (the second, successful call):
  `0bb8ffc0-3e18-4638-8a69-a9b4c70fab01`

### (1) same tree, writer live → refusal naming the child

Lead `tool/result` (seq 23), verbatim:

```
Error: subagent: refused a read-only delegation while write-capable agent
"b72a493a-ea4c-4926-8a1f-fc468c44302d" is still running against the same tree
"/tmp/opencode/batch4/p23-live" — a read-only review must not overlap a lane
that may still mutate it. Wait for the child's settlement notice, or
interrupt_agent it, then retry the same read-only call unchanged; trees
outside this path prefix are unaffected.
```

with the structured error payload `{"name": "SubagentError", "code":
"INSPECTION_CONFLICT"}`.

### (2) inspection state is observable before dispatch

Lead `list_agents` result (seq 28), verbatim:

```
b72a493a-ea4c-4926-8a1f-fc468c44302d [running as of 2026-09-26T12:21:58.846Z] — writer [writes in /tmp/opencode/batch4/p23-live]
```

The writer's own session shows why it counts as write-capable — its session
carries the delegated policy pin, not the read-only override:

```
session {"cwd":"/tmp/opencode/batch4/p23-live","parentSession":"session-1dd23223-…","origin":"subagent","delegationDepth":1}
subagent/descriptor {"version":3,"mode":"continuable","provider":"spawn","label":"writer",…}
sandbox/mode {"mode":"danger-full-access","source":"delegation"}
```

### (3) after settlement, the same call proceeds cleanly

Writer's settlement notice arrived at 2026-09-26T12:22:42.200Z (closing
message `WRITER-DONE`). The identical read-only call then returned `READY`
(seq 44), and its session records the read-only lane:

```
subagent/descriptor {"version":3,"mode":"one-shot","provider":"spawn","label":"review attempt 2","readOnly":true,…}
sandbox/mode {"mode":"read-only","source":"delegation"}
```

## Commands

```bash
node bugs/023-inspection-ordering-guard/scripts/inspection-check.mjs
bash bugs/023-inspection-ordering-guard/scripts/check.sh

# live (temp overlay only; presets untouched)
cd /tmp/opencode/batch4/p23-live
dsh --profile headless --patch ./ro-row.patch.yml "<start writer; call subagent_ro_p23; list_agents; wait; retry>"

# transcript slices (read-only)
zstd -dc ~/.dsh/sessions/--tmp-opencode-batch4-p23-live--/session-1dd23223-9bbc-43b6-81ff-34c4df483313/session.v3.jsonl.zstd \
  | grep -o 'refused a read-only delegation[^"]*'
zstd -dc ~/.dsh/sessions/--tmp-opencode-batch4-p23-live--/session-1dd23223-9bbc-43b6-81ff-34c4df483313/session.v3.jsonl.zstd \
  | grep -o 'writer \[[^]]*\]'
```
