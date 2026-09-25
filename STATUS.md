# Status

All five local fixes are applied to the `dsh` 0.1.5-rc.2 bundle (bugs 001-004
re-applied 2026-09-20; bug 005 added 2026-09-25), with patches generated
against pristine published sources and verified by pristine->reapply
round-trips. Bug 005 additionally removed the `opencode-go` `models:` pin from
`~/.dsh/settings.yaml` (backup kept) so the live catalog is served.

| Bug | Title | Local fix | Upstream |
|-----|-------|-----------|----------|
| [001](bugs/001-ask-during-goal-rounds/README.md) | ask_user_question during goal rounds | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6074 — TS port delivered; maintainer plugin v0.1.1 adopted all review points, independently verified 13/13; PR blocked: token lacks CreatePullRequest) |
| [002](bugs/002-mcp-env-no-expansion/README.md) | MCP env `${VAR}` never expanded | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6075) |
| [003](bugs/003-opencode-go-missing-session-header/README.md) | opencode-go 400 MissingSessionID (no `x-opencode-session`) | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6076) |
| [004](bugs/004-codex-oauth-missing-composition/README.md) | GPT Codex subscription OAuth surface missing | APPLIED to bundle 0.1.5-rc.2 (composition + Typert Remote `authorization` namespace + Models panel) | NOT-FILED |
| [005](bugs/005-opencode-go-live-catalog/README.md) | opencode-go model list stale (release-locked catalog, no live refresh) | APPLIED to bundle 0.1.5-rc.2 (live catalog overlay + startup refresh; `settings.yaml` `models:` pin removed) | NOT-FILED |

## Legend

- Local fix: NONE / APPLIED / LOST-AFTER-UPDATE / UPSTREAMED (no longer needed)
- Upstream: NOT-FILED / FILED (#link) / ACCEPTED / CLOSED-WONTFIX
