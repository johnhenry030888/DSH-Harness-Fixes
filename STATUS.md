# Status

All twenty-three local fixes are applied to the `dsh` 0.1.5-rc.2 bundle (bugs
001-004 re-applied 2026-09-20; bug 005 added 2026-09-25; bugs 006-010 added
2026-09-25 from the orchestrator drill v3/v4 findings; bugs 011-014, 018, 019
added 2026-09-26 from drill v6/v7/v8 findings; bugs 014b, 017, 021, 022 added
2026-09-26 from drill v9/v10 findings; bugs 023-025 added 2026-09-26 from
drill v11 findings), with patches generated against pristine published sources
and verified by pristine->reapply round-trips.

Deployment note (2026-09-26): `~/.dsh/settings.yaml` now **deliberately**
re-pins the eight `opencode-go.models` entries, so `llm.listModels()` serves the
pinned 8. Bug 005's check no longer fails on a pin (it prints a NOTE); bug 012
makes route rejection honest under a pin. Bug 009's check was updated to assert
its class (wording superseded by 012's three-source classifier); bug 024
centralized the served-but-unconfigured/unknown-id wording in a shared
`dsh-llm` formatter, so bugs 009's and 012's checks now assert their classes
there (no fix patch of 009/012 changed).

Stretch items: 015 (worker descriptor `toolFilter` — the descriptor half is
covered by bug 018), 016 (catalog introspection — NOT implemented this batch;
no seam-clean callable exists in the current composition), 020 (scriptable
session creation — documented as NOT-FILED; the web process token remains the
only local auth path).

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

## Legend

- Local fix: NONE / APPLIED / LOST-AFTER-UPDATE / UPSTREAMED (no longer needed)
- Upstream: NOT-FILED / FILED (#link) / ACCEPTED / CLOSED-WONTFIX
