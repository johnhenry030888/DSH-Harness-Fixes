# Upstream draft — bug 039

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** Publish the session transcript store and its record schema (and ship
an offline reader) so record-level evidence stops being unreadable

**Body:**

Three consecutive drills lost record-level acceptance evidence because the
transcript store is undocumented and no supported reader exists:

- v23 §5: the steer split was lost.
- v26 §3/§6: the per-child header/effort table and the share number were lost.
- v27 §6 F3 (verbatim): "no transcript store found at
  `~/.dsh/storages/sessions/*.jsonl` (nor recursively under
  `~/.dsh/storages/**`): every record-level acceptance (033 box record, 034
  boundaryAt, 035 headers, 037 effort fields, per-child catalogs, 17-name
  filter) is unreadable". The lead could not find the store, and the
  hand-rolled `zstd -dc | python3` workaround had already produced two wrong
  parses (v20 merge ledger, v26 tail window).

The store **is** written and stable in practice:

```
$DSH_HOME/sessions/--<cwd-slug>--/<sessionId>/session.v3.jsonl.zstd
```

(`--` + cwd with the leading `/` removed and `/` → `-` + `--`; children live
in the same bucket under `<childId>/`). It is multi-frame zstd — appends add
frames — and Node's single-shot `zstdDecompressSync` silently truncates at the
first frame (observed: 198 B of a 47 KB transcript).

Proposal:

1. Document the path/slug rule and the record schema in the tool docs.
2. Ship (or bless) an offline reader that resolves by glob
   (`sessions/*/<id>/…`), decompresses every frame (`zstd -dc`, frame-loop
   fallback), and prints the request/header summary, per-type counts, the
   subagent box/steer/steer-boundary and workflow rows, and usage totals
   counting each `assistant/message` usage once (`data.stream[].chunk.usage`
   duplicates it).
3. Make absences honest: a missing store/session/requested type exits
   non-zero naming the paths tried, never a zero-filled table.

A reference implementation and its evidence are attached
(`dsh-records.mjs` + README); it needs no model and registers no tool.
