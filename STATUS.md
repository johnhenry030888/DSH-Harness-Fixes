# Status

All thirty-one local fixes are applied to the `dsh` 0.1.5-rc.2 bundle (bugs
001-004 re-applied 2026-09-20; bug 005 added 2026-09-25; bugs 006-010 added
2026-09-25 from the orchestrator drill v3/v4 findings; bugs 011-014, 018, 019
added 2026-09-26 from drill v6/v7/v8 findings; bugs 014b, 017, 021, 022 added
2026-09-26 from drill v9/v10 findings; bugs 023-025 added 2026-09-26 from
drill v11 findings; bugs 016, 020, 026-030 added 2026-09-26 from drill v12
findings and the orchestrator efficiency pass; bug 016b added 2026-09-26 from
drill v14's single FAIL), with patches generated against pristine published
sources and verified by pristine->reapply round-trips.

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

## Legend

- Local fix: NONE / APPLIED / LOST-AFTER-UPDATE / UPSTREAMED (no longer needed)
- Upstream: NOT-FILED / FILED (#link) / ACCEPTED / CLOSED-WONTFIX
