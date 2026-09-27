# Evidence — bug 039

Reader: `scripts/dsh-records.mjs` (repo-side; no bundle patch, see
`patches/00-no-bundle-change.md`).

## Primary evidence (pre-fix)

- Drill **v27 §6 F3** (verbatim): "no transcript store found at
  `~/.dsh/storages/sessions/*.jsonl` (nor recursively under
  `~/.dsh/storages/**`): every record-level acceptance (033 box record, 034
  boundaryAt, 035 headers, 037 effort fields, per-child catalogs, 17-name
  filter) is unreadable".
- Drill **v23 §5**: the steer split was lost to the same missing reader.
- Drill **v26 §3/§6**: the header/effort table and the share number were lost.
- The hand-rolled workaround (`zstd -dc … | python3 …`) produced wrong numbers twice:
  v20 merge ledger, v26 tail window.

## Acceptance 1 — a real drill session read live

Session `session-10f5becd-c2cf-40a9-bc4c-b1888acff7df` (the v27 lead session
named by the drill's own `quality/measure.json` `parent_path`), default home:

```
$ node bugs/039-session-record-reader/scripts/dsh-records.mjs --session 10f5becd-c2cf-40a9-bc4c-b1888acff7df --usage --children
```

```
session session-10f5becd-c2cf-40a9-bc4c-b1888acff7df
path /home/john/.dsh/sessions/--home-john-Documents-Projects-DSH--/session-10f5becd-c2cf-40a9-bc4c-b1888acff7df/session.v3.jsonl.zstd
records 265 (multi-frame: 113 frame(s) via zstd -dc)
cwd /home/john/Documents/Projects/DSH
request headers 1: toolCount=178 provider=opencode-go model=deepseek-v4.1-flash reasoningEffort=max

record counts:
  request/header               1
  turn/start                   1
  turn/end                     1
  tool/call                    49
  tool/result                  49
  subagent/descriptor          0
  subagent/box                 0
  subagent/steer               0
  subagent/steer-boundary      0
  agent/inbox/spliced          32
  tool-workflow/agent-start    3
  tool-workflow/agent-end      3
  session                      1
  agent-preset/selected        2
  permission/preset            1
  sandbox/mode                 1
  approval/policy              1
  subagent/model-selection-policy 1
  step/start                   20
  system/message               1
  user/message                 23
  request/context              1
  session/title                1
  assistant/message            20
  step/end                     20
  subagent/catalog             23
  subagent/inspection-scope    7
  tool-workflow/run-start      1
  tool-workflow/run-end        1
  deliverables/presented       1

records: absent default types in this session: subagent/descriptor, subagent/box, subagent/steer, subagent/steer-boundary (counted as 0 above)
records (tool-workflow/agent-start,tool-workflow/agent-end,subagent/inspection-scope): 13 row(s)
  [seq 67 2026-09-27T22:16:09.712Z] subagent/inspection-scope {"scopeBasis":"maximal","outcome":"refused","readTrees":[],"conflicts":[{"agentId":"19b4b78b-fbfb-4188-8ce8-818b1ff07575","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"3996dbe9-64bf-4602-841f-a17bd7a49fe3","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"ee6bb693-ff71-40c3-a528-6ecb32985222","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"}]}
  [seq 68 2026-09-27T22:16:09.723Z] subagent/inspection-scope {"scopeBasis":"declared","outcome":"refused","readTrees":["/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/quality"],"conflicts":[{"agentId":"19b4b78b-fbfb-4188-8ce8-818b1ff07575","readerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/quality","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"3996dbe9-64bf-4602-841f-a17bd7a49fe3","readerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/quality","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"ee6bb693-ff71-40c3-a528-6ecb32985222","readerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/quality","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"}]}
  [seq 69 2026-09-27T22:16:09.733Z] subagent/inspection-scope {"scopeBasis":"declared","outcome":"refused","readTrees":["/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/app"],"conflicts":[{"agentId":"19b4b78b-fbfb-4188-8ce8-818b1ff07575","readerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/app","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"3996dbe9-64bf-4602-841f-a17bd7a49fe3","readerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/app","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"ee6bb693-ff71-40c3-a528-6ecb32985222","readerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/app","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"}]}
  [seq 70 2026-09-27T22:16:09.741Z] subagent/inspection-scope {"scopeBasis":"maximal","outcome":"refused","readTrees":[],"conflicts":[{"agentId":"19b4b78b-fbfb-4188-8ce8-818b1ff07575","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"3996dbe9-64bf-4602-841f-a17bd7a49fe3","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"},{"agentId":"ee6bb693-ff71-40c3-a528-6ecb32985222","writerTree":"/home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012","writerBasis":"declared"}]}
  [seq 102 2026-09-27T22:17:42.985Z] tool-workflow/agent-start {"runId":"985d74ca-158f-4a6e-8e63-2ad0c6f6fe60","seq":1,"label":"pinned-stage","phase":"effort-probe","childId":"148ae65d-e685-495e-ae6b-bccd62f0306b","requestedProvider":"opencode-go","requestedModel":"deepseek-v4.1-flash","requestedEffort":"max","resolvedEffort":"max","effortSource":"pinned"}
  [seq 103 2026-09-27T22:17:47.132Z] tool-workflow/agent-end {"runId":"985d74ca-158f-4a6e-8e63-2ad0c6f6fe60","seq":1,"outcome":"completed","requestedProvider":"opencode-go","requestedModel":"deepseek-v4.1-flash","requestedEffort":"max","resolvedEffort":"max","effortSource":"pinned"}
  [seq 105 2026-09-27T22:17:47.281Z] tool-workflow/agent-start {"runId":"985d74ca-158f-4a6e-8e63-2ad0c6f6fe60","seq":2,"label":"unpinned-stage","phase":"effort-probe","childId":"b3b6ee49-a6a7-47af-9a80-0110cde28ba2","requestedProvider":"opencode-go","requestedModel":"deepseek-v4-flash","resolvedEffort":"default","effortSource":"default"}
  [seq 106 2026-09-27T22:17:48.839Z] tool-workflow/agent-end {"runId":"985d74ca-158f-4a6e-8e63-2ad0c6f6fe60","seq":2,"outcome":"completed","requestedProvider":"opencode-go","requestedModel":"deepseek-v4-flash","resolvedEffort":"default","effortSource":"default"}
  [seq 108 2026-09-27T22:17:49.005Z] tool-workflow/agent-start {"runId":"985d74ca-158f-4a6e-8e63-2ad0c6f6fe60","seq":3,"label":"unsupported-effort-stage","phase":"effort-probe","childId":"5c451f19-0a59-4e4c-b6b6-940a9803c586","requestedProvider":"opencode-go","requestedModel":"deepseek-v4-flash","requestedEffort":"medium","resolvedEffort":"medium","effortSource":"pinned"}
  [seq 109 2026-09-27T22:17:49.064Z] tool-workflow/agent-end {"runId":"985d74ca-158f-4a6e-8e63-2ad0c6f6fe60","seq":3,"outcome":"failed","error":"provider \"opencode-go\" model \"deepseek-v4-flash\" does not support reasoning effort \"medium\" — supported: off, low, high, max (UNSUPPORTED_REASONING_EFFORT)","errorCode":"UNSUPPORTED_REASONING_EFFORT","requestedProvider":"opencode-go","requestedModel":"deepseek-v4-flash","requestedEffort":"medium","resolvedEffort":"medium","effortSource":"pinned"}
  [seq 126 2026-09-27T22:18:21.404Z] subagent/inspection-scope {"scopeBasis":"declared","outcome":"admitted","readTrees":["/home/john/Documents/dsh-drill-archive/evidence"],"conflicts":[]}
  [seq 191 2026-09-27T22:26:30.478Z] subagent/inspection-scope {"scopeBasis":"maximal","outcome":"admitted","readTrees":[],"conflicts":[]}
  [seq 192 2026-09-27T22:26:30.485Z] subagent/inspection-scope {"scopeBasis":"maximal","outcome":"admitted","readTrees":[],"conflicts":[]}

usage (model calls 127, counting each assistant/message once):
  agent                                  input      cacheRead   output    calls  share%  uncached%
  session-10f5becd-c2cf-40a9-bc4c-b1888acff7df 164201     2023168     104246    20     35.67   25.28    
  7d420665-b8e6-44bd-8de7-39446ca2a6b9   32059      89984       1817      4      1.99    4.94     
  19b4b78b-fbfb-4188-8ce8-818b1ff07575   42254      345344      11872     10     6.32    6.51     
  3996dbe9-64bf-4602-841f-a17bd7a49fe3   8344       118848      1410      4      2.07    1.28     
  ee6bb693-ff71-40c3-a528-6ecb32985222   15816      375424      5370      11     6.38    2.44     
  bb142d0e-66a8-4fd1-9b3e-1843d9137b93   1904       113408      553       4      1.88    0.29     
  be6ad92c-7e2f-4eff-bb69-5ef38b3a7eaa   1366       58560       159       2      0.98    0.21     
  8144e117-abfe-4917-9a58-fa460ba2b983   3210       117568      331       4      1.97    0.49     
  148ae65d-e685-495e-ae6b-bccd62f0306b   28302      0           6         1      0.46    4.36     
  b3b6ee49-a6a7-47af-9a80-0110cde28ba2   29011      0           21        1      0.47    4.47     
  5c451f19-0a59-4e4c-b6b6-940a9803c586   0          0           0         0      0       0        
  a91bc87a-b4f6-4ee4-9460-a04a8d1a465c   35298      122944      5576      5      2.58    5.44     
  d051f736-9059-413f-8cc7-c8daddea8e02   34265      272512      4806      9      5       5.28     
  b3fbde10-3ee7-426b-8542-53e0bf40b36e   28974      28642       848       2      0.94    4.46     
  affcc92a-484b-4249-b16a-a9108ae966ac   12677      127872      1523      4      2.29    1.95     
  5ece681a-1b29-4934-8da5-932389f3f6c9   39298      104192      2627      4      2.34    6.05     
  03ecbe73-877a-4354-abe8-4b151465a265   1980       28672       108       1      0.5     0.3      
  5b0e2f09-973e-4343-b8ad-a393f3fb9bda   28829      162560      28465     4      3.12    4.44     
  f85ebc8f-0083-4114-9191-3caa1eb57cec   28419      113         53        1      0.47    4.38     
  efca72b4-0f14-4d63-941d-2320c9c68fc7   42971      143157      6982      5      3.04    6.62     
  582b3c1a-ea2d-4609-82ed-145f615dbc39   1762       28672       105       1      0.5     0.27     
  beb55c94-ed4f-419b-a7fe-bf34d3205d5a   51284      873984      25479     19     15.09   7.9      
  66fb5c09-6e8b-467c-a6c4-29372ca9acab   15806      319872      4615      10     5.47    2.43     
  c7896e7b-56ab-46d4-8deb-0eaa26668bcd   1406       27648       24238     1      0.47    0.22     
  TOTAL                                  649436     5483144     231210    127   

children (23, referenced by this session):
  child                                  mode         tools records effort   wall s  box                label
  7d420665-b8e6-44bd-8de7-39446ca2a6b9   continuable  4     36      low      25.57   -                  Candidate A derivation
  19b4b78b-fbfb-4188-8ce8-818b1ff07575   continuable  14    74      high     160.953 -                  Build report.py module B
  3996dbe9-64bf-4602-841f-a17bd7a49fe3   continuable  4     36      low      40.656  -                  Candidate B derivation
  ee6bb693-ff71-40c3-a528-6ecb32985222   continuable  12    73      medium   90.177  -                  Build stats.py module A
  bb142d0e-66a8-4fd1-9b3e-1843d9137b93   continuable  3     41      low      53.387  -                  Steer target lane
  be6ad92c-7e2f-4eff-bb69-5ef38b3a7eaa   continuable  2     27      low      45.266  45s hit=true       Box deadline probe lane
  8144e117-abfe-4917-9a58-fa460ba2b983   continuable  3     34      low      299.845 -                  Narrow-scope writer lane
  148ae65d-e685-495e-ae6b-bccd62f0306b   one-shot     0     19      max      4.209   -                  -
  b3b6ee49-a6a7-47af-9a80-0110cde28ba2   one-shot     0     19      default  1.629   -                  -
  5c451f19-0a59-4e4c-b6b6-940a9803c586   one-shot     0     12      -        0.131   -                  -
  a91bc87a-b4f6-4ee4-9460-a04a8d1a465c   continuable  6     43      medium   107.573 -                  Pinned merge with conflict
  d051f736-9059-413f-8cc7-c8daddea8e02   continuable  10    64      low      133.914 -                  Independent accounting lane
  b3fbde10-3ee7-426b-8542-53e0bf40b36e   continuable  1     24      high     7.436   -                  Disjoint external scope probe
  affcc92a-484b-4249-b16a-a9108ae966ac   continuable  9     49      high     171.879 -                  Mutation sweep A
  5ece681a-1b29-4934-8da5-932389f3f6c9   continuable  7     45      low      171.983 -                  Mutation sweep B
  03ecbe73-877a-4354-abe8-4b151465a265   continuable  1     25      low      200.173 200s hit=true      Fast mutation sweep A
  5b0e2f09-973e-4343-b8ad-a393f3fb9bda   continuable  3     34      low      198.598 -                  Fast mutation sweep B
  f85ebc8f-0083-4114-9191-3caa1eb57cec   continuable  0     19      high     3.167   -                  Post-settlement retry of 031
  efca72b4-0f14-4d63-941d-2320c9c68fc7   continuable  9     49      high     67.631  -                  Adversarial code review
  582b3c1a-ea2d-4609-82ed-145f615dbc39   continuable  1     25      low      170.169 170s hit=true      Fresh-tree survivor re-verify
  beb55c94-ed4f-419b-a7fe-bf34d3205d5a   continuable  24    125     low      240.213 240s hit=true      Measurement lane
  66fb5c09-6e8b-467c-a6c4-29372ca9acab   continuable  18    83      low      200.381 200s hit=true      Regression evidence sweep
  c7896e7b-56ab-46d4-8deb-0eaa26668bcd   continuable  1     25      low      160.403 160s hit=true      Second row-targeted sweep
```

The reader decompressed **113 frames** / 265 records (the v27 lane's partial
parse counted 226 — the multi-frame truncation the reader exists to close).

### Which numbers match the drill's own figures

- **Parent prefix, exact**: the first 15 `assistant/message` usages sum to
  `inputTokens 134464 / cacheReadTokens 1286656 / outputTokens 76753` — the
  exact `parent` block of `quality/measure.json` (snapshotted after 15 lead
  calls). The full run's 20 calls add `29737 / 736512 / 27493`.
- **Per-child, exact for every settled lane**: 21 of the 23 referenced
  children reproduce their `inputTokens`/`cacheReadTokens`/`outputTokens`
  **byte for byte** (e.g. `19b4b78b… 42254/345344/11872`,
  `efca72b4… 42971/143157/6982`, `5b0e2f09… 28829/162560/28465`). The two
  lanes still live when `measure.json` was written grew afterwards — the
  reader reports the full run: `beb55c94` (measurement)
  `41629/659072/18075 → 51284/873984/25479`, `66fb5c09` (regression)
  `6694/284864/2994 → 15806/319872/4615`.
- **Box table, exact**: `be6ad92c` 45 s hit (the report's "box-probe 45 YES"),
  `582b3c1a` 170 s hit, `c7896e7b` 160 s hit, `66fb5c09` 200 s hit,
  `beb55c94` 240 s hit — the six box hits the report lists; `7d420665`,
  `19b4b78b`, `3996dbe9`, `ee6bb693`, `8144e117`, `a91bc87a`, `d051f736`,
  `b3fbde10` all show `-` (no hit), matching the report's `no` rows.
- **Efforts, recovered**: every child row carries its
  `request/header.config.reasoningEffort` (`7d420665 low`, `19b4b78b high`,
  `ee6bb693 medium`, `148ae65d max`, `b3b6ee49 default`, `5c451f19` no
  header) — the v27 §5 035 row that was "NOT EXERCISED (no transcript)".
- **Workflow run-record fields, recovered**: `tool-workflow/agent-start`
  seq 102/105/108 carry `requestedEffort`/`resolvedEffort`/`effortSource`
  (`max/pinned`, `default/inherited`-shaped `default/default`,
  `medium/pinned`), and the failed stage's `agent-end` carries
  `errorCode: UNSUPPORTED_REASONING_EFFORT` with the ladder — the v27 §5 037
  row that was "NOT EXERCISED".

## Acceptance 2 — box and steer rows verbatim

```
$ node dsh-records.mjs --session 10f5becd-… --agent be6ad92c-… --records subagent/box --json
[{"boxSeconds":45,"elapsedSeconds":45,"hit":true}]

$ node dsh-records.mjs --session 10f5becd-… --agent bb142d0e-… --records subagent/steer,subagent/steer-boundary --json
[{"messageId":"a26ae3bc-9a42-4278-adde-f82e549f23bc","target":"bb142d0e-66a8-4fd1-9b3e-1843d9137b93","senderSessionId":"session-10f5becd-c2cf-40a9-bc4c-b1888acff7df","deliveredAt":"2026-09-27T22:16:55.673Z"},{"messageId":"a26ae3bc-9a42-4278-adde-f82e549f23bc","deliveredAt":"2026-09-27T22:16:55.673Z","boundaryAt":"2026-09-27T22:16:55.783Z","boundarySeq":29}]
```

The box row is the v27 report's "box-probe (mech) 45 **YES**" notice turned
into a durable record; the steer pair is the v27 §5 034 `deliveredAt`
(22:16:55.673Z) plus the `boundaryAt` (22:16:55.783Z, seq 29) that the drill
could not read.

## Acceptance 3 — negative case

```
$ node dsh-records.mjs --session does-not-exist
error: session "does-not-exist" not found; tried /home/john/.dsh/sessions/*/does-not-exist/session.v3.jsonl.zstd and /home/john/.dsh/sessions/*/session-does-not-exist/session.v3.jsonl.zstd
NEG_EXIT=1
```

## Acceptance 4 — scratch-home copy

One session directory copied under a fresh `sessions/--scratch-copy--/` bucket:

```
$ node dsh-records.mjs --session 10f5becd-… --home /tmp/dsh-scratch-home.8Sdjjk
session session-10f5becd-c2cf-40a9-bc4c-b1888acff7df
path /tmp/dsh-scratch-home.8Sdjjk/sessions/--scratch-copy--/session-10f5becd-c2cf-40a9-bc4c-b1888acff7df/session.v3.jsonl.zstd
records 265 (multi-frame: 113 frame(s) via zstd -dc)
cwd /home/john/Documents/Projects/DSH
request headers 1: toolCount=178 provider=opencode-go model=deepseek-v4.1-flash reasoningEffort=max
... (record counts and default rows follow; exit 0)
```

## Acceptance 5 — self-test (two-frame fixture, forced fallback, negatives)

```
$ bash bugs/039-session-record-reader/scripts/records-selftest.sh
ok: multi-frame transcript read
ok: usage single-count rule
ok: subagent/box row verbatim (boxSeconds/elapsedSeconds/hit)
ok: session id accepted with and without the session- prefix
ok: node frame-loop fallback reads both frames
ok: --agent reads the child transcript
ok: --children table and drill-wide usage
ok: missing session exits non-zero naming the paths tried
ok: requested absent record type exits non-zero naming the type
ok: missing store exits non-zero naming the store
RECORDS-SELFTEST PASS
```

The fixture's first frame holds the session/header records and the second
holds the `assistant/message` (with a duplicated `data.stream[].chunk.usage`)
and the `subagent/box` record; the test proves frame 2 is read (multi-frame),
the stream duplicate is counted once (11/7/5, 1 call) and the node frame-loop
fallback reads both frames.

## Fix markers (checked by `scripts/check.sh`)

- the executable `scripts/dsh-records.mjs` parsing under `node --check`;
- `README.md` documenting `session.v3.jsonl.zstd`, `zstd -dc` and
  `subagent/steer-boundary`;
- `scripts/records-selftest.sh` exiting 0.
