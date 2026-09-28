# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: **all forty-two local fixes applied** to `dsh` 0.1.5-rc.2 (batch 5 —
  016, 020, 026-030 — landed from drill v12's findings plus the orchestrator
  efficiency pass; **batch 6 — 031-036 — landed 2026-09-27** from the
  v16/v17/v19/v21-v26 findings; **batch 7 — 037-038 — landed 2026-09-27**,
  the two remaining drill-opened items; **batch 8 — 039-041 — landed
  2026-09-28**, closing v27 F1/F2/F3). Drill v13 then closed fix 011: **ten
  clean `standard → orchestrator` switch samples**, no 176-tool mount in any.

## Batch 8 (2026-09-28, fixes 039-041) — the closing batch

What changed this turn, in order:

1. **040 — bundle patch first** (it is the only bundle change in this batch).
   Copied the installed `dsh-subagent/lib/index.js` to
   `/tmp/opencode/b40/{pristine,edited}.js`, added the reader-side cue regex +
   `declaredReadScopePaths`/`declaredPromptScope`, wired
   `assertInspectionOrdering` to them, added the `droppedIncidental` record
   field and the named refusal note; stored
   `patches/dsh-subagent-reader-declared-scope.patch` (160 lines) **before**
   touching the installed bundle, verified `patch --dry-run`, forward
   (`pristine+patch == edited`, `cmp` clean) and reverse
   (`installed-patch == pristine`) round trips plus `node --check`, then
   applied it to the installed bundle. `reapply.sh` chains 031/032 and is
   idempotent; a fake-base run (`DSH_AGENT_BASE=/tmp/opencode/b40/fakebase`)
   produced the byte-identical edited file.
2. **039 — repo-side reader.** `bugs/039-session-record-reader/scripts/dsh-records.mjs`
   (~630 lines): glob resolution (`sessions/*/<id>/…`, `session-` prefix
   accepted), `zstd -dc` decompression with a by-hand frame-header walker as
   fallback (both read every frame; the frame count is printed), deterministic
   seq/time ordering, header summary, per-type counts, default interesting
   rows + `--records all|<list>` (absent explicit type = exit 1 naming types
   present), `--usage` (each `assistant/message`'s `data.usage` counted once —
   `data.stream[].chunk.usage` deliberately ignored), `--children` (child ids
   from catalog/workflow/conflict references, read beside the parent),
   `--agent`, honest non-zero failures with paths tried. Also
   `scripts/records-selftest.sh`, which builds a two-frame fixture (session +
   header in frame 1, the usage record with a duplicated stream usage + a
   `subagent/box` in frame 2) and asserts the multi-frame read, the
   single-count rule, the node fallback and the negatives. `check.sh` asserts
   the executable/syntax/README markers/self-test.
3. **041 — repo tooling.** `scripts/check-all.sh` now tallies
   `present`/`missing` per bug folder and ends with
   `TOTAL: <present> fixes present, <missing> missing`, exit non-zero on any
   missing. `bugs/041-check-all-total/scripts/check.sh` greps the line's
   markers and runs a temp copy (real `check-all.sh` + `cp -R` of `bugs/`,
   every copied `check.sh` stubbed, one forced to `exit 1`) asserting
   `TOTAL: 41 fixes present, 1 missing` + exit 1, and the all-stub control
   `TOTAL: 42 fixes present, 0 missing` + exit 0. No recursion: the check
   never runs the real suite.
4. **Ancillary repo edits**: bug 031's `check.sh` maximal-refusal marker and
   both guard probes (031/032) were updated minimally for the new source
   shape (`${droppedNote}` in the refusal template; the new reader helper in
   the probe source-block lists). Assertions unchanged; both probes still
   PASS.

Exact commands and observed results (all run from the repo root):

```
./scripts/verify.sh                                  -> verify: OK (exit 0)
./scripts/check-all.sh                               -> exit 0,
   "TOTAL: 42 fixes present, 0 missing" (82 `fix PRESENT`/`deliverable PRESENT` lines)
./scripts/audit-secrets.sh                           -> audit-secrets: OK (exit 0)
shfmt -l $(git ls-files '*.sh')                      -> no output
shellcheck $(git ls-files '*.sh')                    -> no output
typos                                                -> no findings
dsh --profile headless "Reply with exactly the single word: pong"
                                                     -> pong (exit 0)

node bugs/040-…/scripts/guard-reader-scope-check.mjs            -> PASS (9 pre-fix failures)
node bugs/031-…/scripts/guard-scope-check.mjs                   -> GUARD-SCOPE-CHECK PASS
node bugs/032-…/scripts/guard-pair-check.mjs                    -> GUARD-PAIR-CHECK PASS
bash bugs/037-…/scripts/effort-option-probe.sh                  -> bug-037 live probe: PASS
bash bugs/039-…/scripts/records-selftest.sh                     -> RECORDS-SELFTEST PASS
bash bugs/040-…/scripts/reader-scope-probe.sh                   -> READER-SCOPE-PROBE PASS
```

Live evidence highlights (full raw output in each bug's `EVIDENCE.md`):

- **039** on `session-10f5becd-c2cf-40a9-bc4c-b1888acff7df`: `records 265
  (multi-frame: 113 frame(s) via zstd -dc)`; header `toolCount=178
  provider=opencode-go model=deepseek-v4.1-flash reasoningEffort=max`;
  “parent 164201 / 2023168 / 104246 / 20 calls”; 23-child table with per-child
  efforts and box hits; 21 of 23 children reproduce `quality/measure.json`
  byte-for-byte (the other two were live at its snapshot: `beb55c94`
  `41629/659072/18075 → 51284/873984/25479`, `66fb5c09`
  `6694/284864/2994 → 15806/319872/4615`); the first 15 parent usages are the
  exact `parent` block of `measure.json`. Negative: `--session
  does-not-exist` → exit 1 + both glob patterns tried. Scratch home copy →
  exit 0. Selftest → `RECORDS-SELFTEST PASS`.
- **040** live: `READ-ADMITTED-DISJOINT`, the overlap refusal
  (`…/tmp/dsh040-live/writer.txt` pair, `scopeBasis: declared`),
  `READ-ADMITTED-AFTER`; the durable records
  `{admitted, readTrees:["/tmp/dsh040-live/readers"]}` /
  `{refused, readTrees:["/tmp/dsh040-live/writer.txt"], conflicts:[{writerTree:"/tmp/dsh040-live/writer.txt"}]}` /
  `{admitted, readTrees:["/tmp/dsh040-live/writer.txt"]}`.
- **041**: real last line `TOTAL: 42 fixes present, 0 missing` (exit 0);
  one-broken temp copy `TOTAL: 41 fixes present, 1 missing` (exit 1).
- **037 re-run** (regression check): all 10 assertions PASS — pinned
  `low/pinned`, inherited `max`, `extreme` →
  `UNSUPPORTED_REASONING_EFFORT` with the ladder, `effort: 5` →
  `INVALID_ARGUMENT`, headers `low` and `max`.

**Restart reminder:** the user must restart `dsh web` to load the 040 bundle
patch. 039 (repo-side reader) and 041 (repo tooling) need no restart;
`dsh --profile headless "…pong"` already prints `pong` on the patched bundle.

**Nothing BLOCKED this batch** — all three fixes landed with green checks,
probes, and pasted evidence.
- Batch-6 fixes prompt written (2026-09-27): `~/Desktop/opencode-harness-fixes-prompt-6.md` — a
  **mandatory, completion-gated** opencode prompt for the six harness fixes the v16–v26 drills
  justified, each with its drill citation, the exact seam (verified line numbers), the required
  behaviour, the acceptance probe and the anti-pitfalls:
  **031** guard fail-closed on an undeclared read scope; **032** guard overlap on declared paths with
  the real pair in the message (kills the common-ancestor collapse and the `/​tmp` false refusal);
  **033** a runtime-enforced delegation deadline (`boxSeconds`) that interrupts and returns a partial
  result; **034** steer telemetry (`deliveredAt` + boundary stamp); **035** workflow resolved effort +
  its provenance on the run records, and an explicit effort-or-default marker from every adapter; **036**
  `list_agents` rendering the delegation's declared tree. The prompt fixes the batch gate at
  **37 fixes present**, requires per-fix patch round-trips, behavioural or live proofs, `verify.sh`/`audit-secrets.sh`/
  hooks/headless-`pong` green, STATUS+STATE updates, commit+push, and a BLOCKED entry with the exact error for
  anything not landed (silent skipping is defined as a failed batch).
- What changed this turn (2026-09-28, drill v29 — slim measured, cost still short):
  - **Job A passed again** (031–041 all with pasted records; 032c NOT EXERCISED-clean; 040 a/b/c PASS) and
    quality stayed green (29/29 type-strict rows; sweeps 20/18 and 16/12; a cross-oracle stage 6/6 plus
    12/12 recorded kills reproduced under the other oracle; 0 falsifiable survivors; review concrete).
  - **The slim bought 9 points and the bar still failed**: cache-inclusive share **62.1 % → 53.08 %**,
    uncached **34.45 %** (worse than v28's 27.61 %) because the run used **41 tool calls / 18 model
    requests**, 755 s of pre-dispatch authoring (nine drivers), and six separate read-only probe
    delegations in Phase 4. Wall **1 931 s**; fan-out **0 disagreements** (wording ambiguity, not policy).
  - **Persona core gained five rules** (5064 chars injected, from 3788): reuse v29's frozen fixture instead of
    authoring drivers; the guard obligations are one lane's fixed sequence, not six delegations; give
    measurement lanes the lead session id (a v29 lane read a *foreign* session and published 78.58 %);
    derivation items need policy-level ambiguity and merged resolutions must be fed back or marked advisory;
    never mention a hypothetical scratch path (the guard harvests it), set PYTHONDONTWRITEBYTECODE=1, have
    drivers print their own evidence, and wait for `stopped: complete` rather than a file.
  - **Drill v30 written** (`~/Desktop/orchestrator-drill-prompt-v30.md`): the fixture-based run — adapt
    v29's spec/rows/gate/drivers, fold every guard obligation into one probe lane, name the lead session for
    measurement, and design policy-level derivation items, with the share bar (both bases ≤17 %) as job A.
- Earlier this turn (2026-09-28, drill v28 — quality closed, cost bar failed, doctrine slimmed):
  - **drill v28: Job A passed completely** (all eleven acceptance rows 031–041 with pasted records; two box
    hits; both guard directions; the workflow effort records; 038's empty-home negative) and the quality half
    closed: suite `10 passed` + rows `16/16`, two sweeps executing (13/2/1, 3/0/0), fresh-tree re-verify
    `13/13` and `3/3`, **0 falsifiable survivors** (both classifications independently confirmed), 100 %
    type-strict across seven executions, wall ≈1 210 s, 15 non-dispatch/non-wait lead calls.
  - **Job B failed only on the cost bar: lead share 62.1 % cache-inclusive / 27.61 % uncached** (bar ≤17 %),
    and the cause is structural, not disciplinary — the lead's fixed per-call context (178 tools + the
    preset's doctrine) is re-sent on every call (`cacheRead` 3.78 M on the lead vs 1.87 M across all
    children).
  - **Fixed that immediately by moving the doctrine out of the always-on prompt** (backup
    `/tmp/pre-slim.yml`, and the previous revision is also in the archive): the persona `suffix` went from
    **40 125 → 3 788 chars** (rules only) and the full playbook now lives in the on-demand skill
    **`orchestrator-playbook`** under the project skill root
    (`~/Documents/Projects/DSH/.dsh/skills/orchestrator-playbook/SKILL.md`), which the catalog lists. Preset
    file 66 615 → 29 772 chars; injected doctrine −90.6 % per request. The skill's frontmatter must avoid a
    bare `: ` inside an unquoted description (it silently dropped the skill from the catalog until fixed).
  - **v28 frictions recorded for a proposed batch 9:** F1 the declared-tree echo at dispatch
    (`Tree: <root>` blocks every probe beneath it; v27 F5 recurred), F3 the bash default timeout killing a
    lane before its box fires (and the child misreporting a box hit), F4 `dsh-records.mjs --records a,b,c`
    short-circuiting when any type is absent.
  - **Drill v29 written** (`~/Desktop/orchestrator-drill-prompt-v29.md`): the slimmed-doctrine run — same
    shape and bars, aimed squarely at the share number the slim should move, with F1/F3/F4 workarounds as
    explicit instructions.
- Earlier this turn (2026-09-28, batch-8 independent verification):
  - **Batch 8 landed (039–041) and is verified — and my verification caught a real gate failure the batch
    missed.** `check-all.sh` came back `TOTAL: 41 fixes present, 1 missing`, exit 1: the failure was **bug
    005**, whose cached live catalog still advertised 4 models upstream had removed (`glm-5.1, kimi-k2.6,
    qwen3.6-plus, qwen3.7-max`) and whose CLI-parity arm treated a served-superset as failure. Fixed by
    refreshing the cache with 005's own script (**29 models**, `fetchedAt` 2026-09-28T06:34Z, matching the live
    source and the CLI) and by making that arm fail only on **CLI-only** ids (served-only ⇒ NOTE), leaving the
    live-parity arm as the authority. Now `TOTAL: 42 fixes present, 0 missing`, exit 0.
  - **039 verified**: selftest PASS; the real v27 store read (4 784 records / 2 710 frames) with per-header
    `toolCount`/route/`reasoningEffort`; `--children` produced the **23-child table**; `--usage` produced the
    per-agent totals and the lead share v27 could not measure (**35.67 % cache-inclusive / 25.28 % uncached**).
  - **040 verified**: module probe PASS; live probe PASS (declared `/tmp` scratch admitted while a writer was
    live, overlapping declaration refused naming the declared pair with `scopeBasis: declared`, admitted after
    settlement, durable records read back via 039); 031/032 probes still PASS (no regression).
  - **041 verified**: the `TOTAL:` line is now the authoritative count (it is what exposed the 005 drift).
  - **Doctrine updated (backup `agent.cordis.yml.pre-v31-20260928`):** read records with the supported
    `dsh-records.mjs` (one bash call, `--children --usage`, no hand-rolled parsing — wrong twice in v20/v26)
    and a declared **scratch** scope now counts as a real declaration (fix 040).
  - **Drill v28 brief updated**: the record/usage evidence now comes from `dsh-records.mjs`, and the expected
    gate line is `TOTAL: 42 fixes present, 0 missing`.
- Earlier this turn (2026-09-28, batch-8 fixes prompt written): `~/Desktop/opencode-harness-fixes-prompt-8.md` — the last three
  items, each with drill citations and verified seams, gate raised to **42 fixes**:
  **039 — a supported offline records reader** (`bugs/039-…/scripts/dsh-records.mjs`, repo-side like bug 020,
  no bundle patch, **no new model-facing tool**): locates a session by globbing
  `$DSH_HOME/sessions/*/<sid>/session.v3.jsonl.zstd` (slug rule documented), decompresses multi-frame with
  `zstd -dc`, and prints the `request/header` summary (toolCount, route, `reasoningEffort`), per-type record
  counts, the `subagent/box` / `subagent/steer` / `subagent/steer-boundary` / `tool-workflow/agent-start` rows,
  and `--usage` totals (counting each `assistant/message` usage once — the `data.stream[].chunk.usage`
  duplicate is a known trap), with `--children` for the per-child table and an honest non-zero failure — the
  fix for v27 F3, which cost three acceptance rows and the share bar.
  **040 — a reader's declared scope survives the incidental filter**: `DECLARED_PATH_INCIDENTAL`
  (`dsh-subagent/lib/index.js:1884`) is applied to both sides, so a reader declaring `/tmp/x` as its read
  scope is harvested as empty, and fail-closed 031 then refuses it (v27 F2, verbatim). The reader side
  (`declaredPromptTrees()`, ~1963) gets explicit-cue precedence while the writer side
  (`declaredWorkOfSession()`, ~1924) keeps the v26 A3 behaviour, scratch roots become declarable, and the
  refusal + `subagent/inspection-scope` record name any dropped incidental paths.
  **041 — one authoritative total from `check-all.sh`**: a final `TOTAL: N fixes present, M missing` line, so
  drills stop reconciling "39 fixes" against "37 ids / 77 assertion lines" (v27 F1).
- What changed this turn (2026-09-28, drill v27 — first run on the 39-fix bundle):
  - **The wall bar passed for the first time: 1 324 s** (bar 1 500; pre-dispatch 156 s vs v26's 340 s) with
    lead calls **16** (at budget). Fixes accepted with pasted records: **031** (`scopeBasis: maximal`
    refusal then admission after settlement), **032** (disjoint admitted / overlap refused with the real pair
    / incidental `/tmp` mention harmless), **036** (declared tree + `checkedAt` in the row), **038** (8
    offline routes + `basis`, empty home → exit 1); **033** on the box-hit notice, **034** on
    `deliveredAt → reply`, **037** on live pinned/unpinned/negative behaviour. Gate: both axes, 27/27
    type-strict rows, and the gate caught a self-authored false-positive rule before dispatch. Two
    independent sweeps executed (11 + 19 units), D2 conflict exercised, accounting recounted `5/4/1`
    `MISMATCH: NO`.
  - **Open:** 1 falsifiable survivor (D13, colon-less numeric string — B12's container-leaf hole was found
    and repaired mid-run), the share bar **unmeasured**, 9 of 20 lanes produced no artifact.
  - **Two failures were the drill brief's, and are now fixed in the doctrine (backup
    `agent.cordis.yml.pre-v30-20260928`, five sentences):** the brief never named the transcript path
    (`~/.dsh/sessions/--<cwd-slug>--/<child-id>/session.v3.jsonl.zstd`, `zstd -dc`, carrying
    `request/header`/`subagent/box`/`subagent/steer`/`subagent/steer-boundary`/`tool-workflow/agent-start`)
    — that cost three record-level acceptance rows and the share measurement; **the lead authors the driver
    and the lane runs it** (lanes that had to invent one inside a 160–200 s box stalled; 9 of 20 lanes
    produced nothing); a container needs **leaf-type** assertions (`3.0 == 3` hid a real mutation); a row
    must make the **branch** fail, not merely reach the clause (D13); and a delegation prompt must name
    **concrete file paths**, never the root alone (v27 F5: a root-only declaration collapsed the writer's
    tree and blocked every read-only delegation under it).
  - **Two residual harness items recorded for a possible batch 8:** a declared `/tmp` read scope is
    classified as "no read scope" (F2), and drills have no supported record-read surface beyond the
    transcript path (F3).
  - **Drill v28 written** (`~/Desktop/orchestrator-drill-prompt-v28.md`): the closure run with the
    transcript path in the brief, lead-authored drivers, leaf-type rows, branch-discriminating inputs,
    concrete write scopes, and the same bars.
- Earlier this turn (2026-09-27, batch-7 independent verification):
  - **Re-verified batch 7 from the outside**: `check-all.sh` exit 0 with **77 `PRESENT` lines = 39 fixes**;
    `verify.sh` OK; `audit-secrets.sh` OK; headless `pong` OK; both new `check.sh` green and both
    `reapply.sh` idempotent ("already present"). **037** live probe re-run: a pinned `effort: "low"` stage
    records `requestedEffort`/`resolvedEffort`/`effortSource: "pinned"`, an omitting stage records the
    lead's `max` as `inherited`, an unadvertised `"extreme"` fails with `UNSUPPORTED_REASONING_EFFORT` and
    the ladder in the message, and `effort: 5` is `INVALID_ARGUMENT`; `DEFERRED_AGENT_OPTIONS` is now
    `{isolation, agentType}` and the `agent()` description documents `effort`. **038** verified offline:
    `--routes --json` returns the **8** pinned routes with a `basis` block (policy 8 ∩ catalogue 33), and an
    empty `DSH_HOME` gives `routes: null` + the named sources + exit 1; the auth fence is unchanged
    (`/api/routes` 401, `/api/providers` 401, `/v1/models` 404).
  - **Doctrine updated (backup `agent.cordis.yml.pre-v29-20260927`, two sentences):** effort-sensitive
    fan-out now works in **both** places (`agent(prompt, {provider, model, effort})` pins a stage and the
    record carries `requestedEffort`/`resolvedEffort`/`effortSource`, so a cheap merge can stay inside the
    workflow instead of paying a handoff; read `effortSource` — `inherited` on a stage you meant to pin is a
    defect); and the route list is obtained **offline** with the 020 helper's `--routes --json` (one bash
    call, no session, honest `UNKNOWN`), while the in-session authority stays `list_subagent_models()`.
  - **All eight drill-opened harness items (031–038) are closed.** The read-only lane's wiped `/tmp` is
    documented as sandbox design rather than patched.
  - **Drill v27 updated** (`~/Desktop/orchestrator-drill-prompt-v27.md`): its acceptance table now covers
    **031–038**, its preflight uses `--routes` instead of probing endpoints, and its fan-out phase requires
    the pinned `effort` option to be exercised inside the workflow.
- Earlier this turn (2026-09-27, batch-7 fixes prompt written): `~/Desktop/opencode-harness-fixes-prompt-7.md` — a
  mandatory, completion-gated opencode prompt for the **two remaining drill-opened items**, with every
  seam verified against the installed bundle before writing:
  **037 — `agent(prompt, {effort})`**: accept a pinned per-stage effort (the plumbing already exists from
  035: the worker host's `resolveChildEffort()` returns `effortSource: "pinned"` as soon as
  `agentOptions.reasoningEffort` is present, so the option only has to be let through
  `DEFERRED_AGENT_OPTIONS`/`readAgentOptions` in `worker.cjs` and forwarded in the host's `startAgent`
  `agentOptions`), record `resolvedEffort`/`effortSource` (plus the requested value), keep
  `isolation`/`agentType` deferred, and fail loudly on an unadvertised effort; acceptance is a live
  two-stage workflow with a pinned stage and a negative case.
  **038 — one documented offline route list**: `dsh-local-session.mjs --routes` prints policy ∩ served
  catalogue (`subagent-model-selection.allowedModels` = 8 ∩ `storages/llm-pi-ai/catalog/*.json` = 33 → 8)
  with a `basis:` line, `--json`, and an honest `UNKNOWN` + non-zero exit when a source is missing, plus a
  README section stating that the in-session `list_subagent_models()` is the authority, `/api/*` needs the
  process-token cookie and `/v1/models` is not mounted (verified now: `/v1/models` → **404**,
  `/api/routes` → **401**, `/api/providers` → **401**). No new RPC method, no auth change. Gate raised to
  **39 fixes / 77 `PRESENT` lines**.
- What changed this turn (2026-09-27, batch 7 — harness fixes 037-038, the two
  remaining drill-opened items):
  - **037 landed** as `bugs/037-workflow-agent-effort-option/` (README,
    EVIDENCE, VERSIONS, UPSTREAM-DRAFT, six patches, check/reapply,
    `scripts/effort-option-probe.sh`): `agent(prompt, {effort})` is accepted
    (non-empty string; anything else `INVALID_ARGUMENT` naming `effort`),
    forwarded as the child's pinned `agentOptions.reasoningEffort` so the host's
    035-era `resolveChildEffort()` reports `effortSource: "pinned"`, and
    recorded as `requestedEffort` beside `resolvedEffort`/`effortSource` on
    `tool-workflow/agent-start`/`agent-end`. `isolation`/`agentType` stay
    deferred. Route taken for requirement 4 (documented in the README): the
    unadvertised effort fails the child's first request with the platform's own
    `UNSUPPORTED_REASONING_EFFORT` (22 ms after its start record in the stored
    run), carried as the `WorkflowError.code` the script can catch — no new
    typed error channel and no silent fallback. Live probe (scratch
    `DSH_HOME=/tmp/orch-drill-037`, real `~/.dsh` read-only):
    `requestedEffort low / resolvedEffort low / effortSource pinned`
    (stage-one), no requested + `max`/`inherited` (stage-two),
    `extreme`/pinned + failed `UNSUPPORTED_REASONING_EFFORT` with the ladder
    (stage-three), `effort: 5` → `INVALID_ARGUMENT` (stage-four), child headers
    `low` and `max`. Six-file round trip byte-exact (forward == installed,
    reverse == pre-037 baseline); reapply chains 006 → 028 → 035 and is
    idempotent.
  - **038 landed** as `bugs/038-offline-route-enumeration/` (README, EVIDENCE,
    VERSIONS, UPSTREAM-DRAFT, empty patch by design, check/reapply):
    `bugs/020-…/scripts/dsh-local-session.mjs` gains `--routes` / `--routes
    --json`, printing the intersection of
    `settings.yaml#subagent-model-selection.allowedModels` (8 entries) and
    `storages/llm-pi-ai/catalog/*.json` (33 models) with a two-source `basis:`
    line, and `routes: UNKNOWN (<reason>)` + exit 1 when either source is
    missing. `bugs/020-…/README.md` gains "How to enumerate routes" (the
    in-session `list_subagent_models()` is the authority; `/api/*` needs the
    process-token cookie; `/v1/models` is not mounted). No new RPC, no auth
    change. Live: 8 routes via `--routes --json`; empty scratch home →
    UNKNOWN + exit 1; a scratch orchestrator session's
    `list_subagent_models({provider:"opencode-go"})` returned the same 8 routes
    (`headerToolCount: 178`); unauthenticated `/api/routes` → 401,
    `/api/providers` → 401, `/v1/models` → 404 on both a fresh scratch boot and
    the running server; token exchange → 303.
  - **Gates (exact commands and observed results):**
    `./scripts/check-all.sh` → exit 0, **39 fixes**, `grep -c 'fix PRESENT'` =
    **77** (78 lines contain `PRESENT`, counting bug 020's legacy
    `deliverable PRESENT` — the natural output under the repo's one-PRESENT-line
    -per-fix convention; the prompt's parenthetical 77 is met under the
    `fix PRESENT` counting that produced its 73 baseline); `./scripts/verify.sh`
    → `verify: OK`; `./scripts/audit-secrets.sh` → `audit-secrets: OK`;
    `shfmt -l $(git ls-files '*.sh')` + shellcheck + `typos` → clean;
    `dsh --profile headless "Reply with exactly the single word: pong"` →
    `pong` (exit 0).
  - **Unrelated gate maintenance:** `verify.sh` was red on the current biome
    2.5.6 rule set in `bugs/031-…/scripts/guard-scope-check.mjs` and
    `bugs/032-…/scripts/guard-pair-check.mjs` (pre-existing
    `lint/complexity/useOptionalChain` warnings). Applied biome's own unsafe
    fix to those two probe files only (semantics preserved; both probes still
    print `GUARD-SCOPE-CHECK PASS` / `GUARD-PAIR-CHECK PASS`).
  - **Doctrine note:** the orchestrator preset's doctrine sentence about the
    route list is out of scope for this repository — the assistant maintains
    it (the 037 addition also makes the preset's "`agent()` cannot express
    effort" sentences stale).
  - **Deployment reminder:** the user must restart `dsh web` to load the
    patched bundle; the headless `pong` run already proves the patched bundle
    parses and answers.
  - **Commit/push:** `c045992` (27 files, +1586/-19; pre-commit
    shfmt/shellcheck/typos green, pre-push pytest `7 passed`, cargo/go/node
    skips, secrets OK) pushed `a81f163..c045992` to `origin/main`
    (`https://github.com/johnhenry030888/DSH-Harness-Fixes`).
- What changed this turn (2026-09-27, batch-6 independent verification):
  - **Re-verified batch 6 from the outside** (not from its own report): `check-all.sh` exit 0 with **73
    `PRESENT` lines = 37 fixes**; `verify.sh` OK; `audit-secrets.sh` OK; headless `pong` OK on the patched
    bundle; the three module probes re-run green — **031** `GUARD-SCOPE-CHECK PASS` (including "the A3 shape
    (writer that only touched `/tmp/v26_tstart`) is admitted"), **032** `GUARD-PAIR-CHECK PASS`, **034**
    `STEER-CHECK PASS`; and all four live probes re-run green: **033** box hit at 15 s in both the per-call
    and row variants with partial output and `subagent/box {boxSeconds: 15, elapsedSeconds: 15, hit: true}`;
    **034** ordered triple `deliveredAt 21:11:43.518Z → boundaryAt .620Z → reply` with `subagent/steer` +
    `subagent/steer-boundary`; **035** every child header carries `reasoningEffort` (longcat `"default"`,
    deepseek `max`) and every `agent-start` carries `resolvedEffort` + `effortSource`; **036** the row renders
    `[writes in /tmp/orch-drill-036/declared/sub/file.txt (declared)]` with `checkedAt` and `filePolicy`. No
    BLOCKED entries and no unreported gaps.
  - **Doctrine updated to the new semantics** (backup `agent.cordis.yml.pre-v28-20260927`, five sentences):
    the guard is fail-closed and declared-path based (an undeclared read scope is `maximal`; incidental
    mentions no longer refuse; a refusal now means real overlap); **set `boxSeconds` on every delegation** and
    treat the runtime box as the guarantee, keeping the in-driver loop for partial output; steer timing is
    read from `subagent/steer` / `subagent/steer-boundary`; `resolvedEffort`/`effortSource` is read from the
    workflow run record (and `inherited` on a stage you meant to pin is a defect); and a `list_agents` row's
    `[writes in <path> (declared)]` carries its `treeBasis`.
  - **Drill v27 rewritten as the post-batch acceptance run** (`~/Desktop/orchestrator-drill-prompt-v27.md`):
    job A accepts 031–036 live with a pasted record per fix; job B re-attempts v26's quality and cost bars now
    that the crutches are structural.
- Earlier this turn (2026-09-27, batch 6 — harness fixes 031-036):
  - **All six landed**, each as `bugs/031-…` … `bugs/036-…` with README,
    EVIDENCE, VERSIONS, UPSTREAM-DRAFT, `patches/`, `scripts/{check.sh,reapply.sh}`,
    a module-level probe (031/032/034) or a live probe (033/034/035/036), and
    drill citations:
    - **031** `dsh-subagent` + `dsh-session`: an undeclared read scope is
      maximal — refuse while any write-capable child is live, with the required
      message and a durable `subagent/inspection-scope {scopeBasis, outcome}`
      record (v25 §5 item 7; v26 §5 item 3 / Appendix A). Four new known session
      event types provisioned (`subagent/inspection-scope|box|steer|steer-boundary`).
    - **032** `dsh-subagent`: incidental/sentinel mentions are not declared work,
      the most-specific declared path survives, overlap is declared-reader ×
      declared-writer only, and the refusal names the actual pair with
      `scopeBasis`/`writerBasis` (v21 §4.2, v23 §4.2, v26 §5 + Appendix A2/A3).
    - **033** `dsh-subagent` + `dsh-tool-subagent` + types: `boxSeconds` row /
      `box_seconds` per call (≥5, unset = today), runtime interrupt on expiry,
      `agent "<id>" hit its <n> s box and was interrupted after <m> s; partial
      output follows: …`, durable `subagent/box` + box-hit settlement notice
      (v23 §3, v24 §3, v26 §3/F1/F2).
    - **034** `dsh-tool-subagent-control` + `dsh-subagent` + `dsh-agent-loop` +
      types: `deliveredAt` in the tool result, durable `subagent/steer` on the
      child, `subagent/steer-boundary` at the inbox claim; monotone
      deliveredAt ≤ boundaryAt ≤ reply (v21 §4.3, v23 §5 item 5, v25 §5 item 8
      −0.306 s, v26 §5 item 5).
    - **035** `dsh-tool-workflow` + `dsh-workflow-worker-thread` + `dsh-llm` +
      both adapters + `dsh-workflow` types: `resolvedEffort`/`effortSource`
      (`pinned|inherited|default|unknown`, never omitted) on `agent-start` and
      `agent-end`, and the explicit `"default"` sentinel so a reasoning-capable
      model's header always carries the key (v16 F5, v17 §2, v19 §5 item 2,
      v25 §5 item 2).
    - **036** `dsh-subagent` (service + types) + `dsh-tool-subagent-control`:
      `list_agents` renders `[writes in <declared path> (declared)]` from the
      guard's own `declaredWorkOf`, with `trees`/`treeBasis`; settled-row policy
      absence documented (v16 F2, v17 §5, v20 F2, v21 §5 item 4, v22 §5 item 4,
      v26 §5 item 4).
  - **Verification:** `check-all.sh` → **37 fixes PRESENT**, exit 0; the six
    `check.sh` scripts fail on the pre-fix shadow bundle and pass on the
    installed one; `/tmp/opencode/roundtrip.sh` proves forward apply ==
    installed and reverse apply == pre-batch baseline for all 15 touched files;
    module probes: 031 PASS (pre-fix 6 failures), 032 PASS (pre-fix 5
    failures), 034 PASS (pre-fix builders absent); live probes: **033 PASS**
    (per-call 15 s over a 30 s row, row 15 s, ~31 s wall, `subagent/box
    {15,15,hit:true}`), **034 PASS** (deliveredAt 20:53:43.297Z → boundaryAt
    20:53:43.435Z → reply 20:53:49.370), **035 PASS** (three `agent-start`
    records incl. `max`/`inherited`; every header carries `reasoningEffort`;
    longcat-2.0 = `"default"`), **036 PASS** (`[writes in
    /tmp/orch-drill-036/declared/sub/file.txt (declared)]`).
  - **Deployment note:** the user must restart `dsh web` to load the patched
    bundle; `dsh --profile headless "…pong"` already prints `pong` (exit 0).
    A scratch-home `dsh web` boot on the patched bundle composes the
    orchestrator preset with **178 tools** (`turnCompleted: true`,
    `headerToolCount: 178`, assistantText `ok`) and the header carries
    `subagent`, `list_subagent_models`, `list_agents`, and `send_message` —
    the mount is clean on the 17-name filter and the 178/161 arithmetic is
    untouched.
  - Scratch homes used by the probes live under `/tmp/orch-drill-033/034/035/036`;
    `~/.dsh` was read-only throughout (credentials symlinked, sessions own).
  - **Commit/push:** `a7caefc` (65 files, +4591/-5; pre-commit
    shfmt/shellcheck/typos green, pre-push pytest `7 passed`, cargo/go/node
    skips, secrets OK) pushed `4b0f5d9..a7caefc` to `origin/main`
    (`https://github.com/johnhenry030888/DSH-Harness-Fixes`).
- What changed this turn (2026-09-27, drill v26 follow-up):
  - **drill v26: not closed; the blockers are structural.** Green: parameter
    multi-value coverage (7/7 params at ≥2 values) with 0 decorative/inconsistent
    rows and a gate smoke test; sweep 2 did **22/22 kills, 0 survivors** on a
    fresh-tree driver; the review reproduced **5/5** failures plus two extra
    deviations; `app/` clean; all frozen artifacts verified; preflight 14 s; the
    guard's four sides observed. Missed: wall **1 775 s** (326 s of the 340 s
    pre-dispatch is frozen-artifact authoring), calls **32**, share **not measured**,
    barrier **410 s** (slowest sibling 410 s vs 75 s), merge **385 s**, returns
    **10/12**, sweep 1 executed **nothing** (662 s, zero bytes), the accountant
    returned `UNCOMPARABLE`, and **5/30 rows failed a type-strict replay** — the
    rows pinned the mean's value four ways but never its type (`Decimal` shipped
    where `float` was pinned; R18/R19 fail even loosely). The merge's `counts`
    block contradicted two independent recounts (3/8 vs 7/0) while its quotes were
    faithful.
  - **Persona corrected (backup `agent.cordis.yml.pre-v27-20260927`, five
    sentences):** run every in-driver lane under an **external `timeout <box>`** and
    treat **no artifact after ~60 s as a hang** (two v26 lanes produced nothing at
    all and cost a sweep plus the whole measurement bundle); a measurement lane
    emits its **first counter before parsing anything**; the row gate must **pin the
    returned type** as well as multiple values; a consumer's poll window must be
    **≥ the producer's box** with a producer start sentinel, and a lane publishing
    counts must **recount its own items and fail loudly on mismatch**; and guard
    probes must **always declare a read scope** and expect a **false refusal on
    disjoint scopes** (restate narrower and retry once).
  - **Harness batch now clearly justified (not yet implemented):** the ordering
    guard's two defects — undeclared scope admitted, disjoint scope refused — have
    verbatim evidence from v25/v26 in both directions, and the box/discipline rules
    that keep failing are the ones a harness could enforce rather than a prompt.
  - **Drill v27 written** (`~/Desktop/orchestrator-drill-prompt-v27.md`): the
    closure attempt with external timeouts, the type axis, producer/consumer
    windows, merge self-recount, declared scopes, and a cheaper frozen-artefact
    path (freeze rows first, let the gate grow).
- What changed this turn (2026-09-27, drill v25 follow-up):
  - **drill v25: the in-driver recipe held; the correctness gap moved back to the
    lead's own rows.** In-driver loops did 21 mutants in 1.3 s and 28 in 1.6 s;
    two sweeps executed 49 mutants; the engineered disagreement produced **3
    conflicts / 2 consensus** (exercised on real data); barrier 71 s; banner quoted
    with a content check; guard refuse→admit; review reproduced every survivor;
    `app/` clean. Missed: wall **1 976 s**, calls **20**, share **0.31/0.34**, merge
    130 s, returns 7/8, and **4 falsifiable survivors** — all four traced to frozen
    row blind spots (tuple-vs-list pinned only as `str`, an unexercised
    missing-key branch, a rounding rule indistinguishable at 1 dp vs 2 dp, an
    unformatted empty report). Two new defects: the mutation driver restored only
    the current unit's target (26 recorded kills → **24 kills / 4 survivors** on a
    fresh-tree re-verify), and the guard **admits an undeclared read scope**.
  - **Persona corrected (backup `agent.cordis.yml.pre-v26-20260927`, five
    sentences):** a mutation driver must restore the **whole tree** (or a fresh tree
    per unit) before every unit, not just the current target, and self-verify the
    mutation applied; the lane's single bash call is its **first and last** action
    (no follow-up analysis turns) with **one script per loop and no repair passes**;
    the row gate must require **each clause parameter at more than one value** (it
    would have caught all four survivors); **never assert an effort in a delegation
    prompt** — the row pin and the child's header are authoritative; and a
    read-only delegation must **declare its read scope**, because one that declares
    none is admitted while writers are live.
  - **Open harness items stay six**, now with two extra live findings folded in:
    the guard both collapses to a common ancestor *and* admits an undeclared scope,
    and the gateway route list is not reachable for a preflight route count.
  - **Drill v26 written** (`~/Desktop/orchestrator-drill-prompt-v26.md`): the
    closure run — whole-tree mutation drivers, first-and-last bash calls,
    parameter-discriminating rows, declared read scopes, and a wall target that
    separates dispatch latency from lane overruns.
- What changed this turn (2026-09-27, drill v24 follow-up):
  - **drill v24: correctness spine solid, wall bar missed by ~484 s for the v23
    disease.** Green: the AST gate caught 4 decorative + 5 inconsistent rows before
    the freeze; two independent sweeps executed **38 mutants**; the review
    adjudicated both survivors with proofs; 1 genuine conflict quoted; barrier
    158.9 s; merge 118 s; guard refuse→admit with `scope_granularity=root`;
    preflight 10 s; `app/` byte-clean. Missed: wall **1 984 s**, lead calls ~20,
    share **not measured** (the measurement lane overran and was interrupted before
    emitting counters), lane returns 8/11, accounting lane not run, banner quote
    missed (the sweep quoted the delegation prompt — same record type *and* seq
    slot). The one lane with an in-driver deadline loop did **19 mutants in 13 s**
    against the verify lane's **400 s for the same 19**.
  - **Persona corrected (backup `agent.cordis.yml.pre-v25-20260927`, six
    sentences):** **put the box in the driver, not the prompt** (one bash call whose
    loop re-checks the deadline before every unit and appends partial output);
    **stall = no advancement** (bytes/rows over ~30 s), not merely a missing file;
    mutation drivers must **self-verify** that the mutation changed the file before
    recording a survivor; start per-unit work on the **cheap** lane and keep the
    strong lane for the fix round; dispatch the **accounting lane in the producer's
    wave** and carry a lane-id map for steers; require a **content check** when
    quoting the 027 banner; audit degenerate inputs **at authoring time**; and note
    that `/tmp` is wiped for read-only lanes but **persists for write-capable**
    ones.
  - **Open harness items stay six**; the guard's declared-scope collapse
    (`scope_granularity=root`) now has verbatim live evidence in two drills.
  - **Drill v25 written** (`~/Desktop/orchestrator-drill-prompt-v25.md`): the
    wall-clock closure with in-driver boxes, advancement-based stall detection,
    cheap-lane gating, same-wave accounting, and the banner content check.
- What changed this turn (2026-09-27, drill v23 follow-up):
  - **drill v23: the v22 coupling defect is closed; the wall bar moved to lane-box
    discipline.** Green: measurement finished 177/180 s and marked the unmeasurable
    row unmeasurable; the AST row gate with a discriminating-ness matrix caught two
    dead rows before freeze (27 rows, 17/17 mutants killed, 0 decorative); the
    engineered disagreement produced **1 genuine conflict** quoted and adjudicated;
    barrier 120 s; merge 18 s / 3 271 tokens; both candidates row-pinned; preflight
    9 s; no ordering violation; clean dir. Missed: wall **1 622 s** (bar 1 500),
    lead calls **18** (bar 16), share **34.46 % uncached / 32.58 % cache-inclusive**
    (bar 17 %), lane returns 8/10, regression sweep PARTIAL — causes: one un-capped
    session-store `grep` put **52,869 B** into the lead's context and re-sent it
    every call; verify ran ~2x its box and executed 0 of 19 mutants; the sweep lane
    wrote nothing in 235 s (and blocked the review through the guard's root scope).
  - **Persona corrected (backup `agent.cordis.yml.pre-v24-20260927`, four
    sentences):** **the expensive work goes first** in a boxed lane and the box is
    re-read before every unit (v23's verify spent 430 s of a 300 s box on
    bookkeeping and executed nothing); a lane with **no progress artifact after
    ~90 s is stalled** — interrupt and re-scope instead of waiting; **never let
    discovery output into the lead's context** (cap every discovery command, never
    grep `~/.dsh` as discovery); take an author's family from its own
    `request/header`, never from code style; and a lane self-checking a sentinel
    must use `max(mtime)` over every owner in scope.
  - **Open harness items stay six**, with the guard's declared-scope collapse now
    carrying live evidence (v23 observed the refusal naming the drill root, which
    serializes a read-only lane behind every writer in the drill).
  - **Drill v24 written** (`~/Desktop/orchestrator-drill-prompt-v24.md`): the
    wall-clock closure run — v23's shape with box-first discipline, the stall rule,
    capped discovery, and a regression sweep lane that must return artifacts.
- What changed this turn (2026-09-27, drill v22 follow-up):
  - **drill v22: the lead-call budget works.** 16 lead model calls (v21: 38) and a
    lead input share of **11.98 %** (v21: 33.12 %), with every correctness and
    evidence bar green: 25/25 suite, 18/18 mutants RED, 0 falsifiable survivors
    (review reproduced 6/6), clause+row-aware gate (18 rows / 9 boundary / 7/7
    clause probes), no ordering violation, no hash moved, clean dir, and all 10
    lane returns inside their caps (≈2.3 k tokens total). Barrier 189.8 s, merge
    95.2 s / 8,012 tokens. Missed: total wall ≈1,880 s (bar 1,500) because one lane
    overran its 240 s box to ~656 s and the measurement lane was **gated on that
    lane's sentinel**; the disagreement bar (0 — families agreed 18/18 on a
    row-precise spec); and the guard/steer probes were not exercised (the call
    budget went to the budget bars, disclosed).
  - **Persona corrected (backup `agent.cordis.yml.pre-v23-20260927`, four
    sentences):** a lane box is a **hard self-abort** that returns partial results,
    and a consumer must never be gated on a producer's sentinel (snapshot, mark the
    rest un-comparable) — that coupling alone cost v22 its wall-clock bar; a gate
    that parses code must parse it **structurally** (`ast.parse`+`literal_eval`,
    never comma-splitting — v22's checker bug cost 2 of its ~16 calls); row oracles
    must **discriminate the defect class they pin** (a tie-break test whose input is
    already tie-ascending is decorative; 6 tests passed against an all-empty
    implementation); family spread is **necessary, not sufficient** for
    disagreement, so underdetermined items must be engineered into the derivation
    set with `disagreements_expected` recorded; and every metric is reported **with
    its basis** (cache-inclusive vs uncached share; bash-observed vs transcript
    preflight seconds).
  - **Open harness items stay six**; all are non-blocking (no workflow path is used
    any more) and the guard's declared-scope collapse remains the most
    user-visible.
  - **Drill v23 written** (`~/Desktop/orchestrator-drill-prompt-v23.md`): the
    wall-clock drill — hard self-abort boxes, no consumer gated on a producer, the
    AST-parsing gate, engineered disagreement, both measurement bases, and the
    guard/steer probes folded into the delegated sweep.
- What changed this turn (2026-09-26, drill v21 follow-up):
  - **drill v21: 12 of 14 bars met; the last miss is the lead's turn count.**
    Correctness/evidence all green (16/16 mutants killed, 0 falsifiable survivors
    reproduced independently by the review lane, clause-aware gate before the
    builders, no ordering violation, no hash moved, clean artifact dir). Cost
    bars that v20 missed are now green: returns **≈4,306 tokens across nine
    lanes**, barrier **44.5 s** (v20 349.8), merge **50.7 s / 4 896 tokens**,
    preflight **10.3 s**, total wall **1 483 s**. The one miss: lead input share
    **33.12 %** (bar 17 %) — with returns capped, the driver is the lead's own
    **38 model calls** at ~3.1 k tokens of re-sent context each; ~15-16 calls
    would land ≈16 %.
  - **Persona corrected (backup `agent.cordis.yml.pre-v22-20260926`, five
    sentences):** your own **turn count is the budget** (one long wait with an
    explicit `timeout_ms` per wave, at most one status call per wave, never poll a
    lane that owns a progress artifact — read it); the return cap is a **hard line
    budget** with overflow pushed into the artifact file, and a long lane's first
    action is a progress write **inside** its loop (read-only lanes are exempt and
    return a partial table from one invocation); a **candidate pair must span
    families** (v21 merged two deepseek lanes that agreed on all 14 items, so the
    conflict branch was never exercised); the only legal cwd for a lane's pytest is
    its **private copy**; pass `timeout_ms` on long waits; hash/line-count an
    artifact and read its head before calling it rewritten or a lane defective; and
    the 027 count lives in the child's injected `user/message`, not the descriptor.
  - **Open harness items stay six and are all non-blocking** — the pinned-rows rule
    replaced the workflow path, so `agent()`'s missing `effort` option costs
    nothing today; the guard's declared-scope harvest (v21 reproduced the
    common-ancestor collapse to the drill root) is the most user-visible of them.
  - **Drill v22 written** (`~/Desktop/orchestrator-drill-prompt-v22.md`): the
    closure run with a **lead-call budget** (≤ ~16 lead calls / ≤ 17 % share) as
    the primary bar, plus the progress-artifact, family-spread, private-copy and
    timeout rules.
- What changed this turn (2026-09-26, drill v20 follow-up):
  - **drill v20: all correctness/evidence bars met, two cost bars missed — and the
    misses are the lead's own doing.** Met: clause/row gate before the builders,
    15/15 mutants killed with **0 falsifiable survivors** (the one survivor was
    proven falsifiable with `tokenize(["ab"])`, closed by a single added test and
    independently re-verified), review reproduced 15/15, pinned fan-out at
    row-`low` while the lead ran `max` with a **71.2 s / 10 520-token** merge,
    60 s preflight, 0 duplicate measurement lanes, 0 false failures, clean
    artifact dir. `workflow` was **not used at all** — the pinned-rows rule
    replaced it. Missed: lead input share **45.00 %** (bar 17 %, because the lead
    asked for complete unified diffs of a 270-line file and full tables) and total
    wall 1 539 s (bar 1 500); candidate barrier 349.8 s (bar 300) from a 3.8x
    latency spread between two equally-pinned `low` lanes.
  - **Persona corrected (backup `agent.cordis.yml.pre-v21-20260926`, five
    sentences):** **cap every child's return** (write the diff/table to a file and
    return its sha256 plus ≤20 lines; a diff is a full-file dump once the file is
    large; the lead reads artifacts by hash, not into context); pinning effort
    equalises effort **not latency**, so match lanes by measured latency or compose
    so the slow item does not gate; the machine check must be **clause-aware**
    (v20's C5 prose contradicted itself and only a builder caught it); time-box
    lanes from their **measured** cost (a 15-mutant verify ≈ 300 s before the
    audit); and delegate the *independent accounting parse* too (v20's lead
    parsed its own merge ledger wrong and spent 89.8 s / 2 425 tokens redoing it).
  - **027 banner observation closed:** the numeric count sentence is present and
    correct (v20: "This layer advertises 161 tools" — matching the independently
    measured header count), so v19's sighting without a count was the anomaly.
  - **Open harness items stay at six**, unchanged in substance and now
    non-blocking (the pinned-rows rule means `agent()`'s missing `effort` option no
    longer costs anything): (1) `agent()` effort option; (2) workflow resolved
    effort + adapter effort-or-default marker; (3) the guard's declared-scope
    harvest (now measured: the harvested scope can be the **drill root**, the
    common ancestor of every referenced path, so any writer mentioning it blocks
    every read-only lane on the drill); (4) `list_agents` declared target; (5)
    steer delivery/boundary stamps; (6) read-only lane scratch.
  - **Drill v21 written** (`~/Desktop/orchestrator-drill-prompt-v21.md`): the
    closing run — the same bars with the return caps, lane-latency matching, a
    clause-aware checker and time-boxes from measured cost.
- What changed this turn (2026-09-26, drill v19 follow-up):
  - **drill v19: the cost-discipline fix worked.** Lead share 26.7 % -> **15.32 %**,
    preflight 145 -> **25 s**, lead calls 62 -> **27** with **zero**
    transcript-decompression calls, pinned merge **37.0 s / 1 887 tokens** (both of
    its bars met), checklist machine-checked before freezing (`rows=13
    inconsistent=0`), 16/18 mutations killed with the 2 survivors **proved
    equivalent**, 0 ordering violations, no hash moved. Missed: total wall 1 592 s
    (bar 1 500) and both workflow bars — stage 1 ran at the lead's inherited `max`
    (577.7 s barrier) because `agent()` cannot express effort; and the literal
    "0 survivors" bar.
  - **Persona corrected (backup `agent.cordis.yml.pre-v20-20260926`, six
    sentences):** time-box measurement lanes and demand a stat-able progress
    artifact (v19's silent lane cost a duplicate lane: 182.8 s / 62.9 k tokens) and
    name the lead explicitly with `delegationDepth: 0` + the 178-tool cross-check
    (a lane that guessed by event volume published 17.3 % for a true 15.32 %);
    budget a `parallel` barrier as the slowest sibling **at your own effort**;
    **effort-sensitive fan-out belongs in the pinned `subagent*` rows, not in
    `workflow`** (a stage cannot be pinned — that is exactly what cost v19 both
    workflow bars, while its pinned merge cleared both of its own); a schema-bearing
    workflow stage advertises 162 tools vs a direct child's 161 (per-child, never
    universal); the survivor bar is **zero falsifiable survivors** with equivalence
    proved; and run the closing suite with `-p no:cacheprovider` so the artifact
    directory matches its hashes.
  - **Open items unchanged in count (six), re-ranked:** (1) `agent()` has no
    `effort` option (v19 confirms `worker.cjs:224` `DEFERRED_AGENT_OPTIONS` and the
    `:521` `UNSUPPORTED_OPTION` rejection; drill-estimated payoff: workflow total
    ~410 s); (2) workflow resolved effort + an adapter effort-or-default marker (a
    longcat header carries no `reasoningEffort` key at all); (3) the ordering
    guard's declared-scope harvest takes *referenced* paths from prompt text and
    refused two legitimate probes, making a literal re-admission impossible;
    (4) `list_agents` declared target; (5) steer delivery/boundary stamps; (6)
    read-only lane scratch. New observation to re-check: v19 reports the 027
    banner carries the parent and the 17 removed tools **but no numeric count**
    (v14/v15 saw the count sentence) — needs a targeted look, not a code change.
  - **Drill v20 written** (`~/Desktop/orchestrator-drill-prompt-v20.md`): the
    closure run — same bars as v19 plus a time-boxed measurement lane, the pinned
    fan-out rule, and an explicit report on whether the workflow path was used at
    all.
- What changed this turn (2026-09-26, drill v18 follow-up):
  - **drill v18: 4 bars met / 5 missed; doctrine fix 1 confirmed.** Merge
    395.3 -> 105.2 s, workflow 848 -> 490.7 s, 0/15 mutations survived (second
    family reproduced them), 0 ordering violations, no hash moved. Misses: total
    1 906 s, lead input share 26.7 %, merge tokens 17 532, sibling spread 2.54x,
    preflight 145 s. True failure: the lead's own checklist row D10 was
    arithmetically impossible — a builder refused to bend its code and reported it
    (68 s repair round-trip).
  - **Persona corrected (backup `agent.cordis.yml.pre-v19-20260926`, four
    sentences):** delegate the **measurement** as well as the verification (one
    cheap lane per evidence bundle returning a compact table) and keep a preflight
    to one check-all + one route list + one refusal probe (~25 s), because 62 lead
    calls / 26.7 % input share / 145 s preflight are one behaviour; **machine-check
    a frozen checklist** (tokenize each row's input with the spec's own rules and
    assert its expected output is self-consistent) before freezing it; a pinned
    merge must currently leave `agent()` — prove the pin from the child's header
    and budget the ~73 s handoff, or use a diff-and-dedupe remit inside the
    workflow; and child tool counts are read per child (v18: 161 for both direct
    and workflow children; v17's 162 has not reproduced).
  - **Open items now six** (top first): (1) `agent()` accepts no `effort` option,
    so a right-sized merge cannot stay in the workflow (v18 measured the 72.8 s
    handoff cost); (2) resolved effort + provenance on the workflow agent records,
    and an explicit effort-or-default marker from every adapter (a mimo stage
    header carries no effort key at all); (3) `list_agents` should render the
    delegation's declared target, which the ordering guard already computes;
    (4) surface the steer delivery/boundary stamps (the transcript already carries
    them); (5) a persistent scratch dir for read-only lanes; (6) the guard's
    refusal wording quotes a **referenced** path as "the writer's declared work"
    (v18: `wf/WF-BRIEF.md`, a lead-owned file neither writer owned) — the
    extraction harvests every absolute path in the writer's prompt, which is safe
    but should not be described as ownership.
  - **Drill v19 written** (`~/Desktop/orchestrator-drill-prompt-v19.md`, the only file left on the Desktop; v18's prompt was archived):
    the cost-discipline run — same end-to-end shape with the measurement
    delegated, bars on lead input share (<= ~17 %), preflight (<= 60 s), total
    (<= ~1 500 s), workflow incl. handoff (<= ~600 s) and 0 surviving mutations.
- Desktop sweep (2026-09-26): every drill artifact except the active v18 prompt
  moved to `~/Documents/dsh-drill-archive/` — `prompts/` (18, plus `prompts/opencode/`
  with the 5 batch-fix prompts), `reports/` (16), `evidence/` (16), `roots/` (16
  drill working directories, 12 MB total) and `orchestrator-switch-path-log.md`.
  Nothing was deleted. Drill v18's setup/output paths now write into the archive
  (`roots/orchestrator-drill-v18-<STAMP>`, `reports/`, `evidence/`), so the Desktop
  stays clean between runs.
- What changed this turn (2026-09-26, drill v17 follow-up):
  - **drill v17 (efficiency re-run): PASS, with one honest negative result.**
    1 677 s / 853 109 tokens / 10 children / 171 calls; suite 47 passed with
    **11/11 mutations RED (0 survivors)** including both that v16's suite missed;
    the owner-settled guard was correctly dispatched through a read-only row and
    the steer cost 4.98 s (1.46 s to boundary, 3.52 s to reply) against a lane
    whose own steps cost 3.3-6.0 s. The negative: doctrine fix 2 (effort-match the
    workflow siblings) did not achieve its aim — the spread worsened to 2.451x and
    the workflow sub-task finished 4.7 s cheaper out of 852 s, because the barrier
    saving was exactly offset by a terminal merge that inherited the lead's `max`
    (395.3 s, 55 702 output tokens).
  - **Persona corrected for the negative result and the new frictions** (backup
    `agent.cordis.yml.pre-v18-20260926`, five sentences): right-size the terminal
    merge deliberately (v16's cheap 53.6 s merge was correct, v17's heavy 395 s
    merge was the error); every `agent()` stage inherits your effort and the
    record hides it, so verify effort per child afterwards and route
    effort-critical stages through the pinned `subagent*` rows; keep your own
    verification delegated (lead input share regression 15.6% -> 24.0%); a
    read-only lane's `/tmp` is wiped between calls, so a mutation reproduction
    must be one self-contained invocation; and `subagent/descriptor` — not a
    "quote your system prompt" probe — is the authoritative child identity (4/4
    children quoted its filter sentence correctly; 1 of 4 faked the prompt line).
    A workflow-spawned child advertises **162** tools vs a direct child's 161 —
    recorded so it is not misread as a lost filter.
  - **Open items now four** (top first): (1) resolved effort + provenance on the
    workflow agent events, and an explicit effort-or-default marker from every
    adapter (v17 friction #1, high); (2) `list_agents` should render the
    delegation's declared target, which the ordering guard already computes (v16
    F2 / v17 #2); (3) surface the steer delivery/boundary stamps — the transcript
    already carries `agent/inbox/spliced` with a timestamp (v17 #3); (4) one
    persistent scratch dir for read-only lanes (v17 #4, low).
  - **Drill v18 written** (`~/Desktop/orchestrator-drill-prompt-v18.md`): the
    bounded efficiency run — same end-to-end shape with a right-sized merge, and
    explicit bars (workflow sub-task ≤ ~500 s vs 852/848 s, lead input share
    ≤ ~17%, 0 surviving mutations, all regressions green).
- Earlier this turn (2026-09-26, drill v16 follow-up):
  - **drill v16: end-to-end PASS** (report + evidence on the Desktop; 37 min 15 s,
    942 467 tokens, 14 children, 141 model calls). The full lane set ran in the
    prescribed order with no rule violated; the deliverable is real
    (`wordstats.py` + `test_wordstats.py`, `47 passed` when the lead ran it) and a
    genuine RED falsification was captured twice by independent lanes. Its own
    honest caveat: the suite is green **and** two single-line mutations survive it
    (case-only tie ordering, the untested default `-n`).
  - **Persona corrected for the three legibility gaps it exposed** (backup
    `agent.cordis.yml.pre-v17-20260926`, four sentences): only `subagent_review`
    and `subagent_vision` are `readOnly: true` (so a write-capable lane's probe is
    admitted by design — reading that as a guard failure cost v16 ~28 s and ~58 k tokens);
    `agent()` **inherits the lead's effort** and the run record hides it (v16's
    stage-1 siblings ran at unmatched effort: 798 s vs 378 s, 36 % of the run);
    a build task now carries a **discrimination checklist** (one adversarial input
    per contract clause); and the review lane must **re-run** claimed mutations.
  - **Drill v17 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v17.md` (was on the Desktop)): the
    efficiency re-run — same end-to-end task, but with the three doctrine fixes
    exercised and the telemetry diffed against v16's baseline; its explicit bar is
    that v16's two surviving mutations go RED.
  - Three open items recorded in the ledger (see the STATUS verification note):
    the `list_agents` declared-tree render, the steer delivery/boundary stamp, and
    the resolved stage effort in the workflow run record.
- Earlier this turn (2026-09-26, drill v15 follow-up):
  - **drill v15: 31/31 PASS, 0 FAIL, 0 NOT RUN** (report + evidence on the
    Desktop, since archived under `~/Documents/dsh-drill-archive/reports/`; drill root `~/Documents/dsh-drill-archive/roots/orchestrator-drill-v15-20260926-1923`). Every
    local fix in the project is now observed live: v15 itself exercised 001
    (answer arrives as the `ask_user_question` tool result inside a goal round,
    `roundsStarted: 0`), 002 (GitHub `list_commits` + postgres `select 1` —
    `${VAR}` env expansion live), 004 (operator confirms the Codex sign-in entry),
    010a/b/c (job-tool teaching hint, `checkedAt` rows, own route line), 019
    (`write` refused **and** a shell mutation denied by the read-only sandbox,
    while the build lane still wrote), 021/025 (read-only pytest: no temp-dir
    error, no cache warning, and the suite falsified both ways), plus 016b/020b,
    018/020/022/023/026/027/029 and the three regressions.
  - **Two v15 frictions remain open** (recorded here rather than half-fixed):
    `list_agents` shows the child's session cwd, not its declared target tree
    (the guard's `declaredTreesOf` is the right source; it lives in
    `dsh-subagent` and the listing is projection-backed), and a steer's
    delivery/boundary timestamps are not surfaced for measurement.
  - **Cheap v15 follow-ups landed:** the 020 helper reports `webPid` (+ `kept`)
    so a "no stray server" assertion is baseline-relative, and the 025 README
    documents the self-invalidating assertion trap (`has_plugin("cacheprovider")
    is False`, never a `.pytest_cache` directory check).
  - **Persona corrected** (backup `agent.cordis.yml.pre-v16-20260926`): the job
    tools' teaching hint and `checkedAt` semantics, the `[writes in …]`
    tree caveat (never read it as the declared target), the second and third
    steering-band samples with the model-bound split, and the falsification
    pitfall.
  - **Drill v16 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v16.md` (was on the Desktop)): the
    closure run — one real end-to-end task through the whole lane set
    (partition → build → verify + falsification → review → lead merge), a
    two-stage `workflow` sub-task, an efficiency-telemetry table (wall clock per
    phase, prompt sizes, tokens, steers/retries), a short regression sweep, and
    the two open frictions re-checked as observations.
- Earlier this turn (2026-09-26, drill v14 follow-up):
  - **drill v14 results (report on the Desktop): 21 PASS / 1 FAIL / 7 NOT RUN.**
    Closed live: 007 (probe, both variants), 020, 027 (161 = header on direct /
    workflow / fork), 028 (`UNKNOWN_MODEL` on both paths), 029 (555-char worker
    persona, no lane map), 030 (steer → reply in 4.1 s behind a 90 s sleep,
    `AbortError`/`ABORTED`). Its single FAIL: 016's `catalog: true` was silently
    accepted with `provider`/`model`.
  - **016b** (new, 31st fix; `dsh-tool-subagent`): the catalog branch now refuses
    route arguments by name and the tool description states the rule. Verified
    **live** on a freshly booted process via a second `dsh web`: both mixed calls
    rejected with the named message, while `{catalog:true}` alone still returned
    `{count:178,names:178}` and `{provider}` alone still listed 8 routes.
  - **020b** (helper, `bugs/020…/scripts/dsh-local-session.mjs`): a prompted run
    now waits for the first `turn/end` and reports `turnCompleted`,
    `headerToolCount`, `assistantText`, `turnEndReason`, `waitedMs`. Two real
    defects were found and fixed while validating it: the store is **multi-frame**
    zstd (Node's single-shot `zstdDecompressSync` returned 198 B of a 47 KB
    transcript, so the wait never saw `turn/end`) and the wait must happen before
    the SIGTERM. Verified live: `headerToolCount: 178`, `waitedMs: 16958`.
  - **Persona corrected again** (backup `agent.cordis.yml.pre-v15-20260926`):
    the steering band is now stated as model-bound with v14's numbers, the mount
    tripwire names `list_subagent_models({catalog:true})` as the authoritative
    self-count (and as a standalone mode), and delegation-failure attribution
    points at `tool/result.error.code` / `workflow … errorCode`, never the
    descriptor.
  - **Drill v15 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v15.md` (was on the Desktop)):
    required phases for the never-observed fixes — 001 (goal-round ask), 002 (MCP
    `${VAR}` expansion via the github + postgres servers), 004 (Codex sign-in
    entry, operator-assisted), 010a/b/c (job-tool teaching hint, `checkedAt`,
    own route), 019/021/025 (one read-only-lane pytest phase), plus 016b and
    020b verification and three regressions.
  - Stray server from a `--keep` run reaped (drill v14 friction #5).
- Earlier this turn (2026-09-26, batch 5 + repo hygiene + 007 probe):
  - **026** (`dsh-subagent`): the 023 inspection guard now keys on the
    delegation's **declared target paths** (`declaredTreePaths` extracts
    absolute paths from the instruction text; URLs stripped, system roots
    dropped, normalized + deduped) instead of the session cwd, and the refusal
    names the tested tree. Live (drill v13): refusal named `<…>/project` as the
    target and `<…>/project/stats.py` as the writer's declared work; the same
    call succeeded after settlement. v12's false-refusal caveat is gone.
  - **027** (`dsh-subagent` banner): the `subagent:layer` banner now states the
    layer's **authoritative advertised tool count**, computed from the same
    registry view the filter uses — children no longer have to guess
    (children used to claim 137 or 157 against the real 161).
  - **028** (`dsh-subagent-in-process-driver` + `dsh-subagent`): a terminal
    turn failure now preserves its **code** as `SubagentResult.errorCode`
    (`turnFailureCode()` in-process; `settleRunResult()` out-of-process), so a
    workflow script can distinguish a rejected pin from an agent that returned
    nothing, with one stable code on both paths.
  - **029** (child composition): every child now gets a **compact worker
    persona** (~520 chars: role, parent, filter contract, return contract)
    instead of inheriting the lead's ~20.4 k-char persona; a row's own
    `persona` is honoured when set. Cuts per-child token cost and removes the
    seeded-fork impersonation surface.
  - **030** (`dsh-agent-loop`): **cancel-then-replan** — `AgentLoop` tracks
    `inFlightToolCalls` around `executeToolCalls()` and a steer cancels them so
    the message lands at the resulting boundary instead of waiting out a 60 s
    tool call.
  - **016** (`dsh-tool-subagent`): `list_subagent_models({catalog:true})` — a
    third, mutually exclusive mode returning the agent's authoritative
    `{count,names}`.
  - **020**: scriptable local session helper + documented path (no harness code
    change; authentication untouched).
  - **Repo hygiene finished by the assistant after the batch run stopped short
    of its completion gate:** biome-formatted the two new helper scripts
    (`bugs/020…/scripts/dsh-local-session.mjs`,
    `bugs/026…/scripts/target-path-check.mjs`) so `verify.sh` is green again;
    added `STATUS.md` rows and the header paragraph for all seven new bugs;
    updated this file; committed and pushed.
  - **007 gained a re-runnable live probe** (`bugs/007…/scripts/drill-007-probe.sh`):
    it boots the shipped headless profile twice against a targeted `toolFilter`
    overlay in a scratch harness home, so the last unexercised fix no longer
    needs a user-preset edit. Result: **PASS (both variants)** — the tolerant arm
    spawned a child whose own header proves the filter applied, and the typo arm
    failed loudly with the loader row and `"subagnt_fast"` named and created no
    child session. (Two probe-design traps were found and documented: the
    preset's 17 names are pins the headless host lacks, and a standing row cannot
    enable `modelSelectionSettings`.)
  - **Persona corrected for the batch-5 fixes** (preset backup
    `agent.cordis.yml.pre-v14-20260926`, three edited lines): a child's count is
    now read from the 027 banner instead of being distrusted as a hand count, and
    the steering guidance reflects fix 030 — a steer cancels the in-flight tool
    call, so the ~62 s long-call band is history and > ~20 s behind a long call is
    friction to report.
  - **Drill v14 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v14.md` (was on the Desktop)): required
    live probes for 016, 020, 027, 028, 029 and 030, the 007 probe script as a
    required phase, three regression checks, a completion gate and the exact
    report/evidence paths.
- Verification:
  - `bash scripts/check-all.sh` — exit 0, **all 30 checks PRESENT** (026-030
    included).
  - `./scripts/verify.sh` — exit **0** after the formatting fix (it was FAILED:
    biome reported 3 errors + 3 warnings in the two new scripts).
  - `sh scripts/audit-secrets.sh` — exit 0.
  - `dsh --profile headless "Reply with exactly the single word: pong"` →
    `pong`, exit 0, empty stderr (patched bundle boots).
  - Drill v13 (live, real Orchestrator session): **011 CLOSED** (10/10 clean
    switch samples, transcript-corroborated); 006, 008, 009, 010, 012, 013,
    014 (with the 014b residual), 017, 018, 019, 021, 023, 025, 026 all PASS;
    013's fork effort pin verified (`high`, not the lead's `max`).
- Deployment note: `~/.dsh/settings.yaml` deliberately pins the eight
  `opencode-go.models`; the Orchestrator preset now also bounds workflow
  fan-out (`maxConcurrentAgents: 6`, `maxTotalAgents: 64`) and pins the fork
  lane's effort.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` / biome) — clean after the two-script fix
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `5cce78c` (bug 016b + the turn-aware 020
    helper + STATUS/STATE docs; hooks green) after `baaf069` (bugs 016/020/026-030
    fixes +
    docs; pre-commit `shfmt`/`shellcheck`/`typos` cleared first: the two
    multiline `{ … }` blocks were expanded, the literal-`grep -F` marker
    scripts carry a file-level `# shellcheck disable=SC2016` with the reason,
    and the four wordings that `typos` flagged were rephrased), then `8c9d61e`
    (the bug-007 live probe, its README/EVIDENCE record, and the STATUS/STATE
    updates for it)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes`
    accepted `63ff83d..baaf069`, `baaf069..8c9d61e` and `edcc07c..5cce78c` on
    `main`; pre-push hooks passed on every push (pytest, node, cargo/go skips,
    secrets green)
  - [x] update this file (every turn ends by updating it)
- Autonomy loop — batch 6 (fixes 031-036):
  - [x] lint (`biome`/`shfmt`/`shellcheck`/`typos`) — clean (biome 0 errors;
    three optional-chain warnings left as-is, the pre-commit hook is
    warning-tolerant)
  - [x] `./scripts/check-all.sh` — exit 0, 37 fixes PRESENT (74 PRESENT lines)
  - [x] `./scripts/verify.sh` — `verify: OK`
  - [x] `sh scripts/audit-secrets.sh` — exit 0
  - [x] six `check.sh` pre-fix MISSING / post-fix PRESENT + idempotent
    `reapply.sh` (twice each on shadow bundles)
  - [x] six patch round-trips — forward == installed, reverse == baseline
  - [x] probes: module 031/032/034, live 033/034/035/036 (outputs pasted in
    each `EVIDENCE.md`)
  - [x] `dsh --profile headless "…pong"` → `pong`, exit 0
  - [x] commit `a7caefc`; push `4b0f5d9..a7caefc` to `origin/main` (hooks
    green)
  - [x] update this file (this edit; pushed as the docs follow-up commit)
- Open items:
  - **Live probes outstanding for 016 / 020 / 027 / 028 / 029 / 030** — applied
    and `check.sh`-green, but no drill has exercised them yet; drill v14 carries
    the probes (catalog self-query and mode exclusivity, scriptable session
    creation, banner count on three child kinds, in-script failure branch, child
    vs lead persona size, steer-cancels-in-flight latency).
  - **007 is no longer waiting on a drill-time preset edit**: the new probe
    script passes locally, but drill v14 still has to run it inside the real
    session and paste the output as its acceptance record.
  - 023/024 disclosed acceptance limits from an earlier turn still stand
    (headless overlays rather than the real preset; the direct-path classifier
    is covered by drills).
  - The human should restart their own `dsh web` so it loads the patched
    bundle.
- Decisions: see `docs/decisions.md`.
