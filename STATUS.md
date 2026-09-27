# Status

All forty-two local fixes are applied to the `dsh` 0.1.5-rc.2 bundle (bugs
001-004 re-applied 2026-09-20; bug 005 added 2026-09-25; bugs 006-010 added
2026-09-25 from the orchestrator drill v3/v4 findings; bugs 011-014, 018, 019
added 2026-09-26 from drill v6/v7/v8 findings; bugs 014b, 017, 021, 022 added
2026-09-26 from drill v9/v10 findings; bugs 023-025 added 2026-09-26 from
drill v11 findings; bugs 016, 020, 026-030 added 2026-09-26 from drill v12
findings and the orchestrator efficiency pass; bug 016b added 2026-09-26 from
drill v14's single FAIL; **bugs 031-036 added 2026-09-27 from drill
v16/v17/v19/v21-v26 findings** — the ordering guard's undeclared-scope bypass
and declared-path collapse, the runtime `boxSeconds` deadline, steer
`deliveredAt`/boundary telemetry, workflow resolved-effort records + adapter
header honesty, and the `list_agents` declared tree; **bugs 037-038 added
2026-09-27 — the two remaining drill-opened items** (the workflow
`agent(prompt, {effort})` pin, and the documented offline route list), with
patches generated against pristine published sources and verified by
pristine->reapply round-trips; **bugs 039-041 added 2026-09-28 — the last two
drill-opened items plus the repo tooling that misled two drills**: the
supported offline record reader (v27 §6 F3), the reader-side declared-scope
precedence (v27 §6 F2), and `check-all.sh`'s one authoritative total
(v27 §0/§6 F1). `check-all.sh` now exits 0 with **42 fixes present, 0
missing** on its own TOTAL line.

Batch note (2026-09-28, fixes 039-041): all three landed with green `check.sh`
and idempotent `reapply.sh`; 039 and 041 are repo-side deliverables (documented
empty `patches/`), 040 is one `dsh-subagent` patch with a byte-exact
forward/reverse round trip against the 39-fix baseline. **039**: the reader
resolved the real v27 drill session (113 zstd frames / 265 records), printed
the header summary `toolCount=178 provider=opencode-go model=deepseek-v4.1-flash
reasoningEffort=max`, the 23-child table (efforts `low/high/medium/max/default`,
box hits `45/170/240/160/200 s`), and usage totals that reproduce
`quality/measure.json` exactly for 21 of 23 children (the other two were still
live at its snapshot and grew), with the negative case (`--session
does-not-exist`, exit 1 + paths tried) and a scratch-home copy pasted in
`EVIDENCE.md`; the two-frame self-test proves the multi-frame read, the
single-count usage rule and the node frame-loop fallback. **040**: module probe
9 failures pre-fix → all green post-fix (v27 F2 prompt admitted, `/tmp` pair
refused naming the pair, v26 A3 writer still cwd-fallback, filtered declaration
named via `droppedIncidental`), plus a live scratch-home run where a disjoint
`/tmp` declaration was admitted while a writer was live, the overlapping
declaration was refused naming the pair (`scopeBasis: declared`), and the same
call was admitted after settlement — the durable `subagent/inspection-scope`
records read back through the 039 reader; 031/032/037 probes re-run green.
**041**: the real suite ends `TOTAL: 42 fixes present, 0 missing` (exit 0) and
a temp copy with one `check.sh` forced to `exit 1` reads `TOTAL: 41 fixes
present, 1 missing` (exit 1). `verify.sh` prints `verify: OK`,
`audit-secrets.sh` exits 0, `shfmt -l`/`shellcheck`/`typos` are clean, and
`dsh --profile headless "…pong"` prints `pong`. **The user must restart
`dsh web` to load the patched bundle** (039/041 need no restart; 040 does).

Batch note (2026-09-27, fixes 037-038): both landed with green `check.sh`,
idempotent `reapply.sh`, a byte-exact six-file patch round trip for 037
(forward == installed, reverse == pre-037 baseline; 038 has no bundle patch by
design), and live evidence pasted in each `EVIDENCE.md` — **037**: a
four-stage workflow recording `requestedEffort low`/`resolvedEffort low`/
`effortSource pinned` (stage 1), inherited `max` (stage 2), the platform's
`UNSUPPORTED_REASONING_EFFORT` for the unadvertised `extreme` (stage 3, 22 ms
after its start record) and `INVALID_ARGUMENT` naming `effort` for a non-string
(stage 4), with child headers `low` and `max`; **038**: `--routes --json`
printing **8** routes (policy ∩ catalogue) and `routes: UNKNOWN (…)` + exit 1
on an empty home, the in-session `list_subagent_models` cross-check matching,
and unauthenticated `/api/routes` still **401** / `/v1/models` **404** on both
a scratch boot and the running server. `check-all.sh` exits 0 with **39 fixes**
(**77 `fix PRESENT` lines**; 78 lines containing `PRESENT` counting bug 020's
legacy `deliverable PRESENT`), `verify.sh` prints `verify: OK`, and
`audit-secrets.sh` exits 0. Two unrelated repo probe files (bugs 031/032
`scripts/*.mjs`) were reformatted minimally for the current biome 2.5.6 rule
set so the shared gate stays red-free — their probes still PASS. **The user
must restart `dsh web` to load the patched bundle**; `dsh --profile headless
"…pong"` already prints `pong`.

Batch note (2026-09-27, fixes 031-036): all six landed with green `check.sh`,
idempotent `reapply.sh`, a byte-exact six-fix patch round trip (forward ==
installed, reverse == pre-batch baseline), module-level probes (031/032/034)
and live probes (033/034/035/036) pasted in each `EVIDENCE.md`;
`check-all.sh` reports **37 fixes PRESENT** and `verify.sh` prints
`verify: OK`. **The user must restart `dsh web` to load the patched bundle**;
`dsh --profile headless "…pong"` already prints `pong` on the patched
bundle.

Independent re-verification (assistant, 2026-09-27, same session as the reports): the batch was
re-checked from the outside rather than from its own report — `check-all.sh` exit 0 with **73 `PRESENT`
lines (37 fixes)**, `verify.sh` OK, `audit-secrets.sh` OK, `dsh --profile headless "…pong"` → `pong` on the
patched bundle, the three module probes re-run green (031 `GUARD-SCOPE-CHECK PASS`, 032
`GUARD-PAIR-CHECK PASS` — including the v26 A3 case "writer that only touched `/tmp/v26_tstart` is
admitted" — and 034 `STEER-CHECK PASS`), and all four live probes re-run green:
**033** box hit at 15 s in both the per-call and row-config variants with partial output and the durable
`subagent/box {boxSeconds: 15, elapsedSeconds: 15, hit: true}` record;
**034** ordered triple `deliveredAt 21:11:43.518Z → boundaryAt .620Z → reply`, with `subagent/steer` and
`subagent/steer-boundary`;
**035** every child request header carries `reasoningEffort` (longcat-2.0 = `"default"`, deepseek = `max`)
and every `agent-start` carries `resolvedEffort` + `effortSource`;
**036** the row renders `[writes in /tmp/orch-drill-036/declared/sub/file.txt (declared)]` with `checkedAt`
and `filePolicy`. No BLOCKED entries and no unreported gaps were found; the orchestrator preset's doctrine
was then updated to the new semantics (guard fail-closed/declared paths, `boxSeconds` as a harness
guarantee, steer stamps, `resolvedEffort`/`effortSource`, declared-tree rows).

Batch-7 note (2026-09-27, fixes 037-038): both landed and were independently re-verified from the outside
too — `check-all.sh` exit 0 with **77 `PRESENT` lines = 39 fixes**, `verify.sh` OK, `audit-secrets.sh` OK,
`dsh --profile headless "…pong"` → `pong`. **037**: `DEFERRED_AGENT_OPTIONS` is now `{isolation, agentType}`
and the `agent()` description documents `effort`; the live probe (run again here) shows stage 1 pinned
`effort: "low"` recorded as `requestedEffort='low' resolvedEffort='low' effortSource='pinned'`, stage 2
omitting it as `resolvedEffort='max' effortSource='inherited'`, an unadvertised `"extreme"` failing with the
platform code **`UNSUPPORTED_REASONING_EFFORT`** naming the ladder `off, minimal, low, medium, high` (no
silent fallback), and a non-string effort rejected as `INVALID_ARGUMENT`; the child headers carry
`reasoningEffort='low'` and `'max'` respectively. **038**: `--routes --json` prints exactly the **8** pinned
routes with `basis {policy: settings.yaml#subagent-model-selection.allowedModels (8), catalog: storages/llm-pi-ai/catalog/*.json (33)}`,
and with an empty `DSH_HOME` it prints `routes: null` plus the two named missing sources and exits **1**;
the auth fence is unchanged (`/api/routes` 401, `/api/providers` 401, `/v1/models` 404).

Verification note (2026-09-28, drill v27, first run on the 39-fix bundle): **the wall bar
PASSED for the first time — 1 324 s** (pre-dispatch 156 s vs v26's 340 s), lead calls **16** (at budget).
Accepted with pasted records: **031** (refused "declared no read scope … `scopeBasis: maximal`", then admitted
after settlement), **032** (disjoint scope admitted / overlap refused naming the real pair / incidental `/tmp`
mention no longer refuses), **036** (row shows `[writes in <declared path> (declared)]` with `checkedAt`),
**038** (offline 8 routes with `basis`, empty home → exit 1), **033** on its notice, **034** on
`deliveredAt → reply`, **037** on live behaviour (pinned `PINNED-OK`, unpinned `INHERITED-OK`, unadvertised
effort rejected by name with the ladder). Also green: both gate axes (27/27 type-strict rows, and the gate
caught a self-authored false-positive rule before dispatch), suite 17 passed lead-run, two independent sweeps
executed (11 and 19 units), the conflict branch exercised (D2), and the accounting lane recounted `5/4/1`
with `MISMATCH: NO` — the v26 count-fabrication mode did not recur. Open: **1 falsifiable survivor** (D13, a
colon-less numeric string no row covers — one oracle hole, B12, was found and repaired mid-run), the share bar
**unmeasured**, and 9 of 20 lanes produced no artifact. Two causes are the **drill brief's**, not the
harness's, and are fixed in the doctrine: the brief never named the transcript path
(`~/.dsh/sessions/--<cwd-slug>--/<child-id>/session.v3.jsonl.zstd`), which cost three record-level acceptance
rows and the share measurement; and lanes asked to *author* a driver inside a 160–200 s box stalled, so the
lead now authors the driver and the lane runs it. Two residual harness-side items are recorded for a possible
batch 8: a declared `/tmp` read scope is classified as "no read scope" (v27 F2), and there is no supported
record-read surface for drills beyond the transcript path (v27 F3).

**All eight drill-opened harness items are now closed** (031–038). The only item from the v25/v26 lists that
is deliberately *not* a fix is the read-only lane's wiped `/tmp`: it is the sandbox design (a read-only
lane's scratch is per-invocation), now documented rather than patched.

Deployment note (2026-09-26): `~/.dsh/settings.yaml` now **deliberately**
re-pins the eight `opencode-go.models` entries, so `llm.listModels()` serves the
pinned 8. Bug 005's check no longer fails on a pin (it prints a NOTE); bug 012
makes route rejection honest under a pin. Bug 009's check was updated to assert
its class (wording superseded by 012's three-source classifier); bug 024
centralized the served-but-unconfigured/unknown-id wording in a shared
`dsh-llm` formatter, so bugs 009's and 012's checks now assert their classes
there (no fix patch of 009/012 changed).

Verification note (2026-09-26, drill v13): fix 011 is **CLOSED** — ten clean
`standard → orchestrator` switch samples on file
(`~/Documents/dsh-drill-archive/orchestrator-switch-path-log.md`), every one
corroborated at
transcript level, no 176-tool mount.

Verification note (2026-09-27, drill v26, closure attempt): **not closed — and the
blockers are now structural rather than doctrinal.** Green: the row gate's
parameter multi-value axis worked (7/7 parameters at ≥2 values, 30 rows, 22
mutants, 0 decorative / 0 inconsistent / 0 unguarded, plus a smoke run that proved
the gate can fail), sweep 2 executed **22/22 kills with 0 survivors** on a
fresh-tree-per-unit driver, the review reproduced **5/5** claimed failures and named
two further deviations, `app/` stayed clean, all four lead-owned frozen artifacts
verified at close, preflight **14 s**, and the guard's four sides were observed
(refused with a declared scope → admitted after settlement; undeclared → admitted;
and a **new false refusal on genuinely disjoint scopes**). Missed: wall **1 775 s**
(pre-dispatch 340 s of which 326 s is frozen-artifact authoring, post-dispatch
1 435 s), lead calls **32**, share **not measured**, merge **385 s**, barrier
**410 s**, lane returns **10/12**, sweep 1 executed **nothing** (662 s, no artifact
at all), the accounting lane returned `UNCOMPARABLE`, and **5 of 30 rows failed a
type-strict replay** — the rows pinned the mean's *value* four ways but never its
*type*, so `Decimal` shipped where `float` was pinned (R18/R19 fail even loosely).
The merge's own `counts` block also contradicted two independent recounts (3/8 vs
7/0) while its per-item quotes were faithful. Two guard defects now have verbatim
evidence in both directions: an **undeclared read scope is admitted** while writers
are live, and a **disjoint scope is refused** with the writer's declared work
reported as a path it merely touched.

Verification note (2026-09-27, drill v25, in-driver run): **the in-driver recipe
reproduced and the disagreement branch was exercised on real data; a real
correctness gap appeared in the lead's own frozen rows.** Green: three lanes ran
in-driver loops and every per-unit job finished under the driver's deadline check
(**21 mutants in 1.3 s**, **28 in 1.6 s** — v24's recipe twice), two independent
sweeps executed **49 mutants**, the disagreement engineering produced **3 conflicts
/ 2 consensus** (D1, D2, D4 exercised for real, D2 quoted and adjudicated),
candidate barrier **71 s**, banner quoted with a content check, guard refuse→admit,
review reproduced every claimed survivor, `app/` byte-clean, no lead-owned file
touched. Missed: wall **1 976 s** (bar 1 500 — a multi-loop forensic lane overran
by 664 s repairing its own parsing, a sweep lane sat 8 silent minutes after its
driver had already written the artifact, and preflight+spec+gate ate 298 s), lead
calls **20**, share **0.31/0.34** (bar 0.17), merge 130 s, lane returns 7/8, and
**4 falsifiable survivors** — every one a hole in the lead-authored frozen rows
(tuple-vs-list pinned only as `str`; a missing-key branch never exercised; `AVG 1.5`
identical at 1 dp and 2 dp; no row formatting an empty report), all four reproduced
by the review. Two new findings: the lead's mutation driver restored only the
current unit's target file, so its recorded 26 kills fell to **24 kills / 4
survivors** on a fresh-tree re-verify; and the ordering guard **admits a read-only
delegation that declares no scope** while writers are live.

Verification note (2026-09-27, drill v24, box-discipline run): **the correctness
spine is solid; the wall bar missed for the same disease — lanes that overrun.**
Green: the AST gate with a discriminating-ness matrix caught **4 decorative + 5
inconsistent rows before the freeze** (and a re-run proved the gate can fail), two
independent mutation sweeps **executed 38 mutants** (19 + 19, not 0 like v23), the
read-only review adjudicated both survivors with proofs (one defective application,
one equivalent), the engineered disagreement produced a genuine conflict (D8,
quoted and adjudicated), barrier **158.9 s**, merge **118 s**, guard refuse→admit
with `scope_granularity=root` observed verbatim, preflight **10 s**, no ordering
violation, `app/` byte-clean. Missed: wall **1 984 s** (bar 1 500), lead calls
**~20** (bar 16), share **not measured** (the measurement lane overran and was
interrupted before it emitted the counters), lane returns **8/11**, the accounting
lane **not run**, and the banner quote (the sweep quoted the delegation prompt —
same record type and seq slot as the banner). Root cause, in the drill's own words:
three lanes overran their boxes (2x, 1.6x, 1.8x) and returned nothing, while the one
lane given an in-driver deadline loop did **19 mutants in 13 s**.

Verification note (2026-09-27, drill v23, wall-clock run): **the v22 coupling defect
is CLOSED; the wall bar is still missed, now for lane-box discipline.** Closed and
green: the measurement lane finished at **177 s of its 180 s box** and marked the
unmeasurable row unmeasurable instead of waiting on the verify lane's sentinel
(`consumer_gated_on_producer: false`); the AST row gate with its discriminating-ness
matrix ran before freezing and **caught two dead rows** (27 rows, 17/17 mutants
killed, 0 decorative); the disagreement-engineering worked exactly as designed
(4 underdetermined items → **1 genuine conflict**, quoted verbatim and adjudicated);
barrier **120 s**, merge **18 s / 3 271 output tokens**, both candidates row-pinned
(mimo `low`, longcat `medium` against the lead's `max`), preflight **9 s** (bash
basis), no ordering violation, no lead-owned file touched, clean artifact dir.
Missed: total wall **1 622 s** (bar 1 500), lead calls **18** (bar 16) and lead
input share **34.46 % uncached / 32.58 % cache-inclusive** (bar 17 %) — the share is
a **lead-context** failure this time: one un-capped `grep -rl` over the session
store returned **52,869 B** of transcripts that re-entered every later request; and
two lanes failed their boxes (verify ran ~2x its 300 s box and executed **0 of 19
mutants**; the sweep lane wrote nothing for 235 s and produced no artifact), which
cost ~380 s and made the regression sweep PARTIAL/FAIL. The guard's root-scoped
overlap was observed live again: a read-only lane was refused while any writer in
the drill was live.

Verification note (2026-09-27, drill v22, lead-call budget): **the headline
objective is MET — 16 lead model calls (v21: 38) and a lead input share of 11.98 %
(v21: 33.12 %) — with every correctness/evidence bar green**: 25/25 suite run by
the lead, 18/18 mutants RED with 0 falsifiable survivors (the review lane
independently reproduced 6/6 sampled mutations), clause+row-aware spec gate before
freezing (18 rows, 9 boundary rows, 7/7 clause probes), no ordering violation, no
hash moved, clean artifact dir, and **all 10 lane returns within their caps**
(≈147 lines ≈2.3 k tokens total; the only consensus cost left in the lead's
context is its own 15.6 k-token spec-design turn). Cost bars: barrier 189.8 s and
merge 95.2 s / 8,012 tokens both MET. Missed: total wall ≈1,880 s (bar 1,500) —
one lane overran its 240 s box to ~656 s and the measurement lane was gated on
that lane's sentinel; the candidate-disagreement bar (0 disagreements: two
families still agreed 18/18 on a row-precise spec); and the guard/steer probes
were NOT EXERCISED because the run spent its call budget on the budget bars
(disclosed, not hidden).

Verification note (2026-09-26, drill v21, closing run): **12 of 14 bars MET — and
the single miss is now unambiguous.** Met: 16/16 mutants killed with **0
falsifiable survivors** (the reviewer independently reproduced `killed=16
survived=0` and the claimed 8 weak tests), the clause-aware spec gate ran before
the builders (`clauses=7 rows=16 boundary_cases=29 inconsistent=0`), the bounded
returns worked (**≈4,306 tokens across nine lane returns**, largest ≈702 — v20's
270-line diff did not recur), the latency-matched pinned fan-out took the barrier
from 349.8 s to **44.5 s** and the merge to **50.7 s / 4 896 tokens**, preflight
**10.3 s**, total wall **1 483 s**, 0 duplicate measurement lanes, 0 false
failures, artifact dir clean. **MISSED: lead input share 33.12 %** (bar 17 %) —
with lane returns capped, the dominant term is the lead's own **38 model calls**
re-sending ~3.1 k tokens of context each (118,426 tokens on the lead alone). The
run's own arithmetic puts ~15-16 lead calls at ≈16 %. The 027 count observation is
**closed with its location**: 9/9 children carry "This layer advertises 161 tools"
in the injected `user/message` (seq 11), not in `subagent/descriptor`.

Verification note (2026-09-26, drill v20, closure run): **every correctness and
evidence bar MET; two cost bars missed, both self-inflicted by the lead's own
return schemas.** Met: spec gate ran before the builders saw it
(`rows=13 inconsistent=0`), 15/15 mutants killed with **0 falsifiable survivors**
(the single survivor was proven falsifiable with an exact input, closed by one
added test, and independently re-verified), review by a non-authoring family
reproduced **15/15** verdicts, the pinned fan-out worked exactly as predicted
(candidates at row-pinned `low` while the lead ran `max`, merge **71.2 s /
10 520 tokens**), preflight 60 s, 0 duplicate measurement lanes, 0 false failures,
artifact directory clean. `workflow` was **not used at all** — the pinned-rows rule
replaced it. Missed: lead input share **45.00 %** (bar 17 %) because the lead asked
for complete unified diffs of a 270-line suite and full tables from every lane, and
total wall 1 539 s (bar 1 500); the candidate barrier missed 300 s (349.8 s) on a
3.8x latency spread between two equally-pinned `low` lanes — pinning effort
equalises effort, not latency. The 027-banner observation from v19 is **closed**:
the count sentence is present and correct ("This layer advertises 161 tools").

Verification note (2026-09-26, drill v19, cost-discipline run): **the doctrine
paid.** Lead input share fell **26.7 % -> 15.32 %** (v16 15.6 %), the preflight
fell **145 s -> 25 s**, and the lead's own model calls fell **62 -> 27** (only 5
classified as measurement, 0 transcript-decompression calls): the telemetry table
was produced by a delegated lane, not inline. The pinned merge cleared both of its
bars — **37.0 s and 1 887 output tokens** (-90 % against the token bar; v17:
55 702) — and the checklist machine check ran before freezing (`rows=13
inconsistent=0`), eliminating v18's impossible-row class. Quality held: 16 of 18
mutations killed and the 2 survivors **proved equivalent** (exhaustive +
randomized proofs, independently reproduced), review by a non-authoring family,
0 ordering violations, no hash moved. Missed: total wall 1 592 s (bar 1 500) and
both workflow bars (barrier 577.7 s -> 644.4 s) because `agent()` still cannot
express effort and both stage-1 candidates ran at the lead's `max`; the literal
"0 survivors" bar by two equivalent mutants. New cost driver: the primary
measurement lane went silent for ~12 min with no progress artifact, and the
duplicate lane dispatched against it wasted 182.8 s / 62.9 k tokens.

Verification note (2026-09-26, drill v18, bounded efficiency run): **4 bars met,
5 missed — and the bar it existed to test is confirmed.** Doctrine 1 is proved:
running stage 1 in `pipeline()` and the merge as a directly-delegated,
row-pinned `subagent_fast` child (header `"reasoningEffort": "low"`) cut the merge
**395.3 s -> 105.2 s** and the workflow sub-task **848 s -> 490.7 s** (~42 %), at
the price of a 72.8 s inter-stage handoff that `agent()` cannot avoid because it
accepts no effort option. The e2e task held: **0/15 mutations survived**,
independently reproduced by a second family, 0 ordering violations, no artifact
hash moved. Misses: total wall 1 906 s (bar 1 500), lead input share **26.7 %**
(bar 17 % — the same inline-measurement behaviour as v17's 24.0 %), merge output
tokens 17 532 (bar 15 000, still 69 % below v17), sibling spread 2.54x (bar 2x,
with a route whose header carries no effort key at all) and a 145 s preflight
(bar 60 s). Its own true failure: the lead's frozen checklist row D10 was
arithmetically impossible (3 tokens in, 4 occurrences out) — caught by a builder's
refusal, repaired in 68 s.

Verification note (2026-09-26, drill v17, efficiency re-run): **PASS with one
negative result.** Doctrine fix 1 paid (the guard was dispatched through a
read-only row, refused naming the declared paths, then admitted — no un-fireable
probes, ~86 s and ~58 k tokens saved) and doctrine fix 3 paid fully (**11/11
mutations RED, 0 survivors**, both v16 survivors killed; the blind-authored suite
also caught a real contract defect on its first run). **Doctrine fix 2 did not
work as written:** the sibling spread worsened (2.11x -> 2.451x) and the workflow
sub-task ended 4.7 s cheaper out of 852 s, because halving the barrier (798.6 ->
451.9 s) was given back by a merge stage that inherited the lead's `max` effort
(395.3 s, 55 702 output tokens, 24% of the run). The cause is now recorded as the
top open item: resolved effort is absent from `tool-workflow/agent-start` and at
least one route emits **no** `reasoningEffort` key at all, so "effort-matched" is
unfalsifiable from the record. The doctrine now says to right-size the merge
deliberately, to verify effort per child afterwards, and to keep the lead's own
verification delegated (v17's lead input share rose 15.6% -> 24.0%).

Verification note (2026-09-26, drill v16): the **end-to-end closure run** PASSED —
partition → two different-family builders in parallel → verify with a genuine RED
falsification in a private copy (reproduced independently by a second lane) →
non-authoring review → lead re-hash + lead-run suite (47/47) → merge, with the
whole 178/161 mount arithmetic and the owner-settled guard holding (the refusal
named the **declared target path**). Six frictions were logged, **no new harness
bug**, and the run's honest caveat is a doctrine lesson rather than a defect: the
suite was green with **two single-line mutations surviving it**. Two costs came
from missing legibility, not from broken behaviour — the ledger now carries three
open items: (a) `list_agents` renders a row's tree from the child's session cwd,
not its declared target; (b) no steer delivery/boundary timestamp is surfaced;
(c) the workflow run record does not show the resolved stage effort, so
`agent()`'s inherited effort is invisible (v16 measured a stage child silently at
the lead's `max` beside a `null` sibling, 798 s vs 378 s).

Verification note (2026-09-26, drill v15): **31 of 31 fixes PASS live, 0 FAIL,
0 NOT RUN** — every local fix in this project has now been observed in a real
session (16 during v15 itself: 001, 002, 004, 010, 016, 016b, 018, 019, 020,
021, 022, 023, 025, 026, 027, 029; the rest carried from v13/v14 and not
re-litigated). v15 also closed v14's single FAIL (016b) and its seven NOT RUN
targets. Two harness-side frictions remain **open** (documented, not fixed):
(a) `list_agents` renders a row's tree as the child's **session cwd**, not the
target its prompt declared — the ordering guard itself uses declared paths, only
the display is coarse, and the clean fix is to reuse the guard's
`declaredTreesOf` through the listing projection; (b) a steer's delivery and
boundary timestamps are not surfaced (`send_message` result or settlement
notice), so drill authors still measure the steer band with a stopwatch and a
cooperative child.

Verification note (2026-09-26, drill v14): **21 PASS / 1 FAIL / 7 NOT RUN**. The
FAIL is fixed as **016b** above (and re-verified live). Drill v14 also closed
**007** live, confirmed **020, 027, 028, 029, 030** (030 measured 4.1 s from
steer to reply behind a 90 s sleep), and reported two harness-side frictions
that are now fixed in the helper: the 020 helper could not corroborate its own
session (`session/prompt` queues, and the store is multi-frame zstd) — it now
waits for the first `turn/end` and reports `headerToolCount`/`assistantText`
(verified live: 178 in one call, `waitedMs` 16 958). Drill v15 covers the
remaining never-observed fixes: 001, 002, 004, 010a/b/c, 019, 021, 025.

Verification note (2026-09-26, bug 007): the fix now has a **re-runnable live
probe** — `bugs/007-toolfilter-unknown-name-outage/scripts/drill-007-probe.sh`
runs both arms in a scratch harness home (real `~/.dsh` only read) and passes:
the tolerant arm spawns a child whose own header proves the filter applied
(`bash,edit,job_kill,job_list,job_output,read,write`), and the typo arm fails
loudly with the loader row and `"subagnt_fast"` named while creating no child
session. The second known-but-non-restrictable name, `list_subagent_models`,
stays unit-verified (`tolerance-check.mjs`) because a standing row cannot enable
`modelSelectionSettings`. Drill v14 takes this script as a required phase and
carries the outstanding live probes for 016, 020, 027, 028, 029 and 030.

| Bug | Title | Local fix | Upstream |
|-----|-------|-----------|----------|
| [001](bugs/001-ask-during-goal-rounds/README.md) | ask_user_question during goal rounds | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6074 — TS port delivered; maintainer plugin v0.1.1 adopted all review points, independently verified 13/13; PR blocked: token lacks CreatePullRequest) |
| [002](bugs/002-mcp-env-no-expansion/README.md) | MCP env `${VAR}` never expanded | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6075) |
| [003](bugs/003-opencode-go-missing-session-header/README.md) | opencode-go 400 MissingSessionID (no `x-opencode-session`) | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6076) |
| [004](bugs/004-codex-oauth-missing-composition/README.md) | GPT Codex subscription OAuth surface missing | APPLIED to bundle 0.1.5-rc.2 (composition + Typert Remote `authorization` namespace + Models panel) | NOT-FILED |
| [005](bugs/005-opencode-go-live-catalog/README.md) | opencode-go model list stale (release-locked catalog, no live refresh) | APPLIED to bundle 0.1.5-rc.2 (live catalog overlay + startup refresh; `settings.yaml` `models:` pin removed) | NOT-FILED |
| [006](bugs/006-workflow-worker-tool-filter/README.md) | workflow workers bypass the delegation leaf policy | APPLIED to bundle 0.1.5-rc.2 (engine-owned `toolFilter` on the worker-thread row, passed to every `agent()` child) | NOT-FILED |
| [007](bugs/007-toolfilter-unknown-name-outage/README.md) | one unknown `toolFilter` name kills every spawn | APPLIED to bundle 0.1.5-rc.2 (tolerant child composition + row-identified pre-spawn/boot validation) | NOT-FILED |
| [008](bugs/008-fork-empty-seed-diagnostic/README.md) | `subagent_fork` silently starts cold inside the parent's turn | APPLIED to bundle 0.1.5-rc.2 (empty-seed host warning + completed-turn contract in the tool description) | NOT-FILED |
| [009](bugs/009-route-effort-diagnostics/README.md) | route/effort rejection diagnostics are ambiguous | APPLIED to bundle 0.1.5-rc.2 (served-vs-unserved classification; effort ladder in the rejection) | NOT-FILED |
| [010](bugs/010-control-surface-ergonomics/README.md) | control-surface ergonomics (job hint, list_agents status, own route) | APPLIED to bundle 0.1.5-rc.2 (agent-id hint; `checkedAt` status sampling; `agent:route` runtime context) | NOT-FILED |
| [011](bugs/011-boot-arm-non-destructive/README.md) | REGRESSION: fix 007's boot arm removes the lead's `subagent`/`list_subagent_models` (mount race) | APPLIED to bundle 0.1.5-rc.2 (non-destructive boot arm: named deferral log; pre-spawn arm stays the hard failure) | NOT-FILED |
| [012](bugs/012-route-classifier-three-sources/README.md) | fix 009's classifier reports real models as nonexistent under a pinned catalog | APPLIED to bundle 0.1.5-rc.2 (three-source classification: configured / catalog / allowlist, via `llm.listCatalogModels`) | NOT-FILED |
| [013](bugs/013-fork-seed-announcement/README.md) | fix 008's cold-fork announcement is not observable (no count, no notice) | APPLIED to bundle 0.1.5-rc.2 (numeric `inheritedEventCount` on the descriptor + both-direction host log + child runtime-context line) | NOT-FILED |
| [014](bugs/014-workflow-run-record-error/README.md) | workflow run records drop the child's spawn error and requested route | APPLIED to bundle 0.1.5-rc.2 (seam `diagnostic` + `error`/`requestedProvider`/`requestedModel` on `tool-workflow/agent-start`/`agent-end`) | NOT-FILED |
| [014b](bugs/014b-workflow-agent-null-provenance/README.md) | `workflow` `agent()` still returns a bare `null` on failure | APPLIED to bundle 0.1.5-rc.2 (run-record lookup documented in the `agent()` bullet of the workflow tool description) | NOT-FILED |
| [017](bugs/017-stop-time-in-termination-notice/README.md) | termination notices carry no `stopTime` | APPLIED to bundle 0.1.5-rc.2 (`stopTime` + `lastActivityTime` on the notice source, notice text, `subagent/end`, and types; live: stop 23 ms after last activity, envelope 22.7 s later) | NOT-FILED |
| [018](bugs/018-child-layer-identity/README.md) | a child layer keeps the lead's system prompt while its tools are filtered | APPLIED to bundle 0.1.5-rc.2 (leading `subagent:layer` banner naming parent + removed tools; one-shot descriptors declare `toolFilter` — also covers 015's descriptor half) | NOT-FILED |
| [019](bugs/019-child-write-scope/README.md) | no per-child write scope: workers can modify files they do not own | APPLIED to bundle 0.1.5-rc.2 (per-row `readOnly: true`: path-aware guard on `edit`/`write`/`present` + read-only sandbox for shell mutations, descriptor-durable) | NOT-FILED |
| [021](bugs/021-read-only-no-temp-dir/README.md) | read-only lanes have no writable temporary directory (pytest dies before collecting) | APPLIED to bundle 0.1.5-rc.2 (`tempWriteRoots()` seam + bwrap private `--tmpfs /tmp` in every confined mode + Landlock/Seatbelt temp grants; live: bare pinned pytest `3 passed` on a `readOnly: true` lane, workspace still refused) | NOT-FILED |
| [022](bugs/022-agent-preset-mount-path/README.md) | `agent-preset/selected` cannot say how the preset was mounted (direct vs picker switch) | APPLIED to bundle 0.1.5-rc.2 (one event writer records `mountPath: direct|switch` + `rowMount: mounted`; live on both paths via a headless overlay) | NOT-FILED |
| [023](bugs/023-inspection-ordering-guard/README.md) | verify→review ordering has no mechanical guard: a live write-capable child can corrupt a concurrent read-only review | APPLIED to bundle 0.1.5-rc.2 (`INSPECTION_CONFLICT` refusal in `dsh-subagent` on both creation paths, keyed on live status + the resolved `sandbox/mode` policy + cwd-prefix overlap; `list_agents` rows expose `filePolicy` + `tree`; live: refused while the writer ran, same call returned `READY` after settlement) | NOT-FILED |
| [024](bugs/024-workflow-diagnostics/README.md) | workflow `run-end` hides contained failures; one condition has two wordings by call path | APPLIED to bundle 0.1.5-rc.2 (`failedAgents`+`error`+requested route on `run-end`; shared `dsh-llm` `modelResolutionDiagnostic` with `MODEL_NOT_CONFIGURED`/`UNKNOWN_MODEL` codes used by pi-ai and the delegation classifier; live: identical sentence both paths, run-end carries `failedAgents: 2`) | NOT-FILED |
| [025](bugs/025-read-only-pytest-cache/README.md) | read-only lanes emit a `PytestCacheWarning` and drift back to a workaround command | APPLIED to bundle 0.1.5-rc.2 (`PYTEST_ADDOPTS=-p no:cacheprovider` exported by read-only bash calls only, appended to any inherited value; live: read-only lane `3 passed` with no warning, write lane unchanged) | NOT-FILED |
| [026](bugs/026-target-path-ordering-guard/README.md) | the 023 guard keys on the session cwd, so a review of an unrelated tree is refused for the wrong reason | APPLIED to bundle 0.1.5-rc.2 (guard keys on the delegation's declared target paths via `declaredTreePaths`, and the message names the tested tree; live in drill v13: refusal named `<…>/project` and the writer's `stats.py`, same call allowed after settlement) | NOT-FILED |
| [027](bugs/027-child-tool-count-banner/README.md) | children report a wrong own catalog size (137/157 claimed vs 161 actual) | APPLIED to bundle 0.1.5-rc.2 (the `subagent:layer` banner states the authoritative advertised count, computed from the same registry view the filter uses) | NOT-FILED |
| [028](bugs/028-workflow-agent-failure-code/README.md) | a rejected pin reaches a workflow script as a bare `null`; the same condition has two wordings by call path | APPLIED to bundle 0.1.5-rc.2 (terminal turn failure code preserved as `SubagentResult.errorCode` through both in-process and out-of-process paths, one stable code) | NOT-FILED |
| [029](bugs/029-compact-worker-persona/README.md) | every child inherits the lead's full ~20.4 k-char persona (per-child token cost + the seeded-fork impersonation hazard) | APPLIED to bundle 0.1.5-rc.2 (child composition installs a compact ~520-char worker persona naming role, parent, filter and return contract; a row's own `persona` is honoured when set) | NOT-FILED |
| [030](bugs/030-steer-cancels-in-flight-tool-call/README.md) | a steer cannot interrupt an in-flight tool call (62 s worst case; a long call is un-steerable) | APPLIED to bundle 0.1.5-rc.2 (cancel-then-replan: `AgentLoop` tracks `inFlightToolCalls` around `executeToolCalls()` and a steer cancels them, delivering the message at the resulting boundary) | NOT-FILED |
| [016](bugs/016-catalog-self-query/README.md) | no way to query one's own catalog (the lead hand-counts 177 vs 178; children report 161 or 137) | APPLIED to bundle 0.1.5-rc.2 (`list_subagent_models({catalog:true})` — a third, mutually exclusive mode returning the authoritative `{count,names}`) | NOT-FILED |
| [016b](bugs/016b-catalog-mode-exclusivity/README.md) | `catalog: true` was silently accepted together with `provider`/`model`, so a mixed call answered the catalog question and dropped the route arguments (drill v14 §1 — the run's only FAIL) | APPLIED to bundle 0.1.5-rc.2 (the catalog branch refuses route arguments by name; the tool description states the rule; live on a freshly booted process: both mixed calls rejected with the named message while `{catalog:true}` alone still returned 178/178 and `{provider}` alone still listed 8 routes) | NOT-FILED |
| [020](bugs/020-scriptable-session-creation/README.md) | no scriptable local session creation: every switch-path/preset probe costs the operator manual GUI work | APPLIED (helper + documented path; no harness code change — auth untouched) | NOT-FILED |
| [031](bugs/031-fail-closed-undeclared-read-scope/README.md) | the 023/026 ordering guard is fail-open on an undeclared read scope (v25 §5 probe 1; v26 §5 item 3 + Appendix A admitted G1 with four writers live) | APPLIED to bundle 0.1.5-rc.2 (undeclared read scope is maximal: refuse while any write-capable child is live, with the required message and a durable `subagent/inspection-scope {scopeBasis, outcome}` record; declared scopes unchanged) | NOT-FILED |
| [032](bugs/032-declared-path-overlap-pairs/README.md) | the guard harvests every absolute path and reports collapsed ancestors, refusing genuinely disjoint reviews (v21 §4.2, v23 §4.2, v26 §5 + Appendix A2/A3) | APPLIED to bundle 0.1.5-rc.2 (incidental/sentinel mentions filtered, most-specific path kept, declared reader × declared writer overlap only, refusal names the actual pair + `scopeBasis`/`writerBasis`; module probe: pre-fix FAIL 5 cases, post-fix PASS) | NOT-FILED |
| [033](bugs/033-runtime-box-deadline/README.md) | no runtime-enforced delegation deadline: overrunning lanes returned nothing (v23 §3 0/19 mutants; v24 §3 2 lanes overran and returned nothing; v26 §3/F1/F2 662 s and 323 s with no artifact) | APPLIED to bundle 0.1.5-rc.2 (`boxSeconds` row + `box_seconds` per call, runtime interrupt on expiry, `agent "<id>" hit its <n> s box …` with partial output, durable `subagent/box` + box-hit settlement notice; live probe: 15 s box both variants, ~31 s wall, record `{15,15,hit:true}`) | NOT-FILED |
| [034](bugs/034-steer-telemetry/README.md) | steer delivery has no timestamps: the deliveredAt → boundary → reply split is unmeasurable (v21 §4.3; v23 §5 item 5; v25 §5 item 8 measured −0.306 s; v26 §5 item 5 only the 14 s total) | APPLIED to bundle 0.1.5-rc.2 (`deliveredAt` in the `send_message` result, durable `subagent/steer` on the child, `subagent/steer-boundary` at the inbox claim; fake-clock probe + live probe: 20:53:43.297Z → 20:53:43.435Z → 20:53:49.370) | NOT-FILED |
| [035](bugs/035-workflow-resolved-effort/README.md) | workflow run records omit the resolved effort and an adapter header can lack the key entirely (v16 F5/v17 §2 silent lead-max; v19 §5 item 2/v25 §5 item 2 longcat header had no `reasoningEffort`) | APPLIED to bundle 0.1.5-rc.2 (`resolvedEffort` + `effortSource` on `tool-workflow/agent-start`/`agent-end`, creation-time resolution in the worker host, and the explicit `"default"` sentinel in `dsh-llm` handled by both adapters; live probe: 3 records incl. `max`/`inherited`, every header carries the key, longcat `"default"`) | NOT-FILED |
| [036](bugs/036-list-agents-declared-tree/README.md) | `list_agents` renders the session cwd instead of the delegation's declared tree; settled rows carry no tree/policy (v16 F2, v17 §5, v20 F2, v21 §5 item 4, v22 §5 item 4, v26 §5 item 4) | APPLIED to bundle 0.1.5-rc.2 (service exposes the guard's `declaredWorkOf`; rows render `[writes in <declared path> (declared)]` + `trees`/`treeBasis`, settled-row policy absence documented; live probe shows the declared drill subpath with `checkedAt`/`filePolicy`) | NOT-FILED |
| [037](bugs/037-workflow-agent-effort-option/README.md) | `agent()` accepts no `effort`, so a workflow stage cannot be pinned and silently inherits the lead's effort (v16 F5, v17 §2; v19 §5 item 2/v25 §5 item 2 unmatched pair; v21 §7 R1 pinned merge leaves the workflow) | APPLIED to bundle 0.1.5-rc.2 (`effort` accepted as a non-empty string and forwarded as the child's pinned `agentOptions.reasoningEffort`; `requestedEffort` recorded beside 035's `resolvedEffort`/`effortSource: "pinned"`; unadvertised effort fails loudly with the platform's `UNSUPPORTED_REASONING_EFFORT`; `isolation`/`agentType` stay deferred; live probe: `low`/pinned, inherited `max`, `extreme` rejected in 22 ms with the ladder, `effort: 5` → `INVALID_ARGUMENT`) | NOT-FILED |
| [038](bugs/038-offline-route-enumeration/README.md) | no documented, offline way to enumerate the served (policy-filtered) routes — `/v1/models` 404, `/api/routes` 401 (v25 §0, v26 §0/§7 F-route: header/effort table NOT MEASURED) | APPLIED (helper + documented path; no harness code change — auth untouched). `dsh-local-session.mjs --routes` prints policy ∩ catalogue (`allowedModels` ∩ `storages/llm-pi-ai/catalog/*.json`) with a `basis:` line, `--json`, and honest `UNKNOWN` + non-zero when a source is missing; README states the in-session `list_subagent_models()` authority and the `/api` cookie / unmounted `/v1/models` facts | NOT-FILED |
| [039](bugs/039-session-record-reader/README.md) | no supported offline reader for session records/token usage: every record-level acceptance is unreadable and the hand-rolled `zstd -dc \| python3` workaround produced wrong parses twice (v23 §5 steer split lost; v26 §3/§6 header/effort table + share lost; v27 §3/§4/§6 F3 three acceptance rows + the share bar lost) | APPLIED (repo-side `scripts/dsh-records.mjs`, no bundle patch and no new tool). Globs `$DSH_HOME/sessions/*/<sid>/session.v3.jsonl.zstd`, decompresses every frame (`zstd -dc` + node frame-loop fallback), prints header summary/counts/raw rows (`subagent/box` `{boxSeconds,elapsedSeconds,hit}`, steer `deliveredAt`→`boundaryAt`, workflow `requestedEffort`/`resolvedEffort`/`effortSource`), `--usage` per-agent + drill-wide totals counting each `assistant/message` once (the `data.stream[].chunk.usage` duplicate trap closed), `--children` per-child table, `--agent`, honest non-zero absences; verified on the real v27 session (113 frames/265 records; 21/23 children match `measure.json` byte-for-byte) and the two-frame self-test | NOT-FILED |
| [040](bugs/040-reader-declared-scope/README.md) | a reader that declares `/tmp/` as its read scope is harvested as `declared no read scope` (scopeBasis maximal) because 032's incidental filter runs on both sides, so fail-closed 031 refuses the delegation (v27 §6 F2) | APPLIED to bundle 0.1.5-rc.2 (reader-side `READ_SCOPE_CUE` precedence in `declaredReadScopePaths`/`declaredPromptScope`; scratch roots declarable; dropped mentions named in the maximal refusal + `droppedIncidental` on the record; writer side and 031/032 semantics unchanged). Module probe 9 failures pre-fix → PASS; live: disjoint `/tmp` declaration admitted while a writer was live, overlap refused naming the pair with `scopeBasis: declared`, same call admitted after settlement; 031/032 probes still green | NOT-FILED |
| [041](bugs/041-check-all-total/README.md) | `check-all.sh` prints no count, so drills reconcile "N fixes" against heterogeneous id/assertion lines by hand (v27 §0/§6 F1: 39 predicted vs 37 ids vs 77 assertion lines) | APPLIED (repo tooling). Every bug folder tallies `present`/`missing` once and the tool ends with `TOTAL: <present> fixes present, <missing> missing`, exiting non-zero when anything is missing; the temp-copy probe forces one check to exit 1 and asserts `TOTAL: 41 fixes present, 1 missing` + exit 1 without touching the real suite | NOT-FILED |

## Legend

- Local fix: NONE / APPLIED / LOST-AFTER-UPDATE / UPSTREAMED (no longer needed)
- Upstream: NOT-FILED / FILED (#link) / ACCEPTED / CLOSED-WONTFIX
