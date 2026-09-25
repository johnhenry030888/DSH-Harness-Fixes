# Decisions

Append-only log for choices that future turns (human or agent) need to understand.

| Date | Decision | Why |
| --- | --- | --- |
| | initial scaffold | see STATE.md |
| 2026-09-25 | Bug 005: host-side live catalog overlay + startup refresh, and remove the `opencode-go` `models:` pin from `~/.dsh/settings.yaml` | A pin replaces the catalog and cannot express mixed wire protocols; bumping pi-ai (0.86.0 still ships 27) or editing its generated data is release-locked; pi-ai's `Models.refresh()` is unused by dsh and its snapshot lifecycle is rebuilt per config change. The overlay reuses pi-ai's tested descriptors and fails safe to the bundled catalog. |
