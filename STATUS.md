# Status

All four local fixes were re-applied after the `dsh` 0.1.5-rc.2 update on
2026-09-20; patches were regenerated against pristine 0.1.5-rc.2 sources and
verified by a pristine->reapply round-trip.

| Bug | Title | Local fix | Upstream |
|-----|-------|-----------|----------|
| [001](bugs/001-ask-during-goal-rounds/README.md) | ask_user_question during goal rounds | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6074 — TS port delivered; maintainer plugin v0.1.1 adopted all review points, independently verified 13/13; PR blocked: token lacks CreatePullRequest) |
| [002](bugs/002-mcp-env-no-expansion/README.md) | MCP env `${VAR}` never expanded | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6075) |
| [003](bugs/003-opencode-go-missing-session-header/README.md) | opencode-go 400 MissingSessionID (no `x-opencode-session`) | APPLIED to bundle 0.1.5-rc.2 | FILED (discussion #6076) |
| [004](bugs/004-codex-oauth-missing-composition/README.md) | GPT Codex subscription OAuth surface missing | APPLIED to bundle 0.1.5-rc.2 (composition + Typert Remote `authorization` namespace + Models panel) | NOT-FILED |

## Legend

- Local fix: NONE / APPLIED / LOST-AFTER-UPDATE / UPSTREAMED (no longer needed)
- Upstream: NOT-FILED / FILED (#link) / ACCEPTED / CLOSED-WONTFIX
