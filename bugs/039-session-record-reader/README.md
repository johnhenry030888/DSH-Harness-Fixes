# Bug 039 — a supported, offline reader for session records and token usage

Severity: **high** (drill evidence was unreadable without a hand-rolled parser,
and that workaround produced wrong numbers twice). Deliverable: repo-side, **no
harness patch** — `scripts/dsh-records.mjs`, a documented offline client of the
installed session store (bug-020 precedent). Upstream: **NOT-FILED**.

## Symptoms

Every drill had to reconstruct record-level evidence by hand, and three failed
outright:

- **v23 §5** lost the steer split.
- **v26 §3/§6** lost the header/effort table and the share number.
- **v27 §3/§4/§6 F3** lost three acceptance rows and the whole share bar: the
  lead could not find the store (`ls ~/.dsh/storages/sessions/*.jsonl` →
  nothing) and no supported reader existed. The v27 report's own words:
  "no transcript store found at `~/.dsh/storages/sessions/*.jsonl` (nor
  recursively under `~/.dsh/storages/**`): every record-level acceptance (033
  box record, 034 boundaryAt, 035 headers, 037 effort fields, per-child
  catalogs, 17-name filter) is unreadable".

The workaround — hand-rolled `zstd -dc … | python3 …`, written fresh each run —
was wrong twice: v20's wrong merge-ledger parse and v26's wrong tail-window read.

## Where the records are

```
$DSH_HOME/sessions/--<cwd-slug>--/<sessionId>/session.v3.jsonl.zstd
```

`$DSH_HOME` defaults to `~/.dsh` (override with `--home` or `DSH_HOME`). The
bucket slug is `--` + the workspace cwd with its leading `/` removed and every
`/` replaced by `-` + `--`:

```
/home/john/Documents/DSH-Harness-Fixes  ->  --home-john-Documents-DSH-Harness-Fixes--
```

The slug is a hint only. The reader globs
`$DSH_HOME/sessions/*/<sessionId>/session.v3.jsonl.zstd`, because a drill may
create its own scratch home (and a child transcript lives in the *same* bucket
as its parent, `<childId>` without the `session-` prefix). Session ids are
accepted with or without a leading `session-`.

## Multi-frame caveat

`session.v3.jsonl.zstd` is **multi-frame** zstd: the host appends a frame per
write, so a real drill transcript is dozens to hundreds of frames. Node's
single-shot `zstdDecompressSync` silently stops at the first frame (observed
in v25: 198 B of a 47 KB transcript). `dsh-records.mjs` decompresses with
`zstd -dc` and falls back to an explicit frame-by-frame walk (force it with
`DSH_RECORDS_DECOMPRESS=node`); both paths read every frame and print the frame
count. Never hand-roll a single-shot decompress.

## Record schema

Each line is one JSON record; `seq`/`time` are monotonic within a session.
The `session` header record carries its metadata at the **top level** (not
under `data`); all other records carry `data`.

| record type | fields used by the reader |
| --- | --- |
| `session` | `id`, `version`, `createdAt`, `cwd`, `parentSession`, `origin`, `delegationDepth`, `agentPreset` |
| `request/header` | `data.header.config {provider, model, reasoningEffort, maxTokens}`, `data.header.tools[]` (`toolCount` = `tools.length`) |
| `assistant/message` | `data.usage {inputTokens, cacheReadTokens, outputTokens, totalTokens}`; `data.stream[].chunk.usage` repeats the same numbers (count `data.usage` only) |
| `subagent/descriptor` | `data {version, mode, provider, label, agentProvider, agentModel, agentReasoningEffort, toolFilter}` |
| `subagent/box` | `data {boxSeconds, elapsedSeconds, hit}` |
| `subagent/steer` | `data {messageId, target, senderSessionId, deliveredAt}` |
| `subagent/steer-boundary` | `data {messageId, deliveredAt, boundaryAt, boundarySeq}` |
| `subagent/catalog` | `data {version, childId, childCreatedAt, mode, label}` |
| `subagent/inspection-scope` | `data {scopeBasis, outcome, readTrees, conflicts[], droppedIncidental?}` |
| `tool-workflow/agent-start` | `data {runId, seq, label, phase, childId, requestedProvider, requestedModel, requestedEffort?, resolvedEffort?, effortSource?}` |
| `tool-workflow/agent-end` | the agent-start fields plus `outcome`, `error?`, `errorCode?` |
| `agent/inbox/spliced` | `data {target, start, inserted[]}` |

## Usage

```
node scripts/dsh-records.mjs --session <sessionId|--latest> [--home <dir>]
     [--json|--table] [--usage] [--records <type,type|all>]
     [--agent <childId>] [--children|--all]
```

- default output: header summary (toolCount, provider/model/reasoningEffort,
  header count), per-type record counts, and the interesting raw rows
  (`subagent/descriptor`, `subagent/box`, `subagent/steer`,
  `subagent/steer-boundary`, `tool-workflow/agent-start|agent-end`,
  `subagent/inspection-scope`);
- `--records all` (or a comma list) prints raw rows verbatim;
- `--usage` prints per-agent and drill-wide `input` / `cacheRead` / `output`
  totals plus model-call counts, counting each `assistant/message` usage once;
- `--children`/`--all` adds every child transcript the parent references
  (catalog / workflow agent-starts / guard conflicts) with mode, label, tool
  count, request-header effort, record count, wall seconds and box result;
- `--agent <childId>` reads one child beside the session;
- exit 0 = read; exit 1 = store/session/explicitly requested record type
  absent or malformed, printing the paths tried (default types that are merely
  absent are named, not fatal); exit 2 = usage error.

### Worked examples (one per drill use case)

Share table (the lead's `share%` is the drill's cache-inclusive share; the
`uncached%` column is the uncached-only basis):

```
node scripts/dsh-records.mjs --session 10f5becd-c2cf-40a9-bc4c-b1888acff7df --usage --children
```

Box hit, verbatim:

```
node scripts/dsh-records.mjs --session <sessionId> --agent <boxChildId> --records subagent/box --json
# -> {"boxSeconds":45,"elapsedSeconds":45,"hit":true}
```

Steer split (`deliveredAt` → `boundaryAt`/`boundarySeq`):

```
node scripts/dsh-records.mjs --session <sessionId> --agent <steerChildId> \
  --records subagent/steer,subagent/steer-boundary --json
```

Per-child header table (provider/model/effort per child, plus tools, wall,
box):

```
node scripts/dsh-records.mjs --session <sessionId> --children --table
```

Everything at once (raw rows, all types):

```
node scripts/dsh-records.mjs --session <sessionId> --records all
```

## Fix design

`scripts/dsh-records.mjs`:

1. **Resolution by glob, not by slug inference** — `sessions/*/<id>/…` plus
   `session-` normalization, so scratch homes and children both resolve; a
   missing session prints both patterns tried and exits 1.
2. **Frame-complete decompression** — `zstd -dc`, with a pure-Node fallback
   that walks frame headers/blocks and decompresses each frame separately; the
   frame count is reported so a truncating reader is visible.
3. **Deterministic summaries** — records sorted by `seq`/`time`, children in
   parent-reference order, no wall-clock reads. Offline, no model, no network.
4. **Single-count usage** — `assistant/message`'s `data.usage` is the only
   usage source; `data.stream[].chunk.usage` (the same numbers) is ignored, so
   the v21/v25 double-count trap cannot recur. `--usage --children` gives the
   per-agent table and the drill-wide totals/share in one call.
5. **Honest failure** — a requested absent record type, missing store, missing
   session or malformed line exits non-zero with the paths/types tried; absences
   are never rendered as a zero-filled table.

Rejected alternatives:

- **Add a model-facing tool.** The arithmetic must not change (178/161 tool
  counts are load-bearing for drills), and the reader needs no model.
- **Rely on `~/.dsh/storages/**`.** That is not where the transcripts live;
  the store above is (verified against the v27 drill session).
- **Wrap `zstd -dc` only.** A missing CLI must not silently truncate; the
  frame walk makes the fallback frame-complete too.

## Acceptance evidence

`EVIDENCE.md`: v27 drill session read live (header 178/opencode-go/
deepseek-v4.1-flash/max, 23-child table, usage totals that reproduce
`quality/measure.json` exactly for every child it had already snapshotted),
the missing-session and absent-type negatives, the scratch-home copy, and the
self-test's two-frame fixture. `scripts/check.sh` exits 0 when the reader,
its README markers and `scripts/records-selftest.sh` all hold.
