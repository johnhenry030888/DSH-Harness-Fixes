# Status

All ten local fixes are applied to the `dsh` 0.1.5-rc.2 bundle (bugs 001-004
re-applied 2026-09-20; bug 005 added 2026-09-25; bugs 006-010 added
2026-09-25 from the orchestrator drill v3/v4 findings), with patches generated
against pristine published sources and verified by pristine->reapply
round-trips. Bug 005 additionally removed the `opencode-go` `models:` pin from
`~/.dsh/settings.yaml` (backup kept) so the live catalog is served; the pin was
re-added before drill v3 and removed again for bugs 006-010
(`settings.yaml.bak-pre-bug010-20260925` preserves that state).

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

## Legend

- Local fix: NONE / APPLIED / LOST-AFTER-UPDATE / UPSTREAMED (no longer needed)
- Upstream: NOT-FILED / FILED (#link) / ACCEPTED / CLOSED-WONTFIX
