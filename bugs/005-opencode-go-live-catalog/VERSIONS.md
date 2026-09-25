# Versions — bug 005

- First analyzed broken: `@deepseek-ai/dsh` 0.1.5-rc.2 (installed bundle,
2026-09-25) with `@earendil-works/pi-ai` 0.85.1 and an `opencode-go`
`models:` pin in `~/.dsh/settings.yaml`. The mechanism (release-locked pi-ai
catalog + no live path) predates this version; `deepseek-v4.1-flash` is absent
from 0.85.x and 0.86.0 alike, and even up-to-date pi-ai misses five models
that are already live on the gateway.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-25): patch applied on top of
bug 003's patch with no fuzz, `node --check` clean, `scripts/check.sh` exit 0,
`scripts/reapply.sh` idempotent, `scripts/check-all.sh` exit 0. Live parity:
the served set equals `opencode models`' opencode-go list (32/32), and
`opencode-go/deepseek-v4.1-flash` completed a headless turn end-to-end.
- Settings change required with the fix: remove
  `llm-pi-ai.providers.opencode-go.models` from `~/.dsh/settings.yaml` (a
  non-empty list replaces the live catalog at resolution time). Original
  preserved at `~/.dsh/settings.yaml.bak-bug005-20260925`.
- Runtime cache: `${DSH_HOME:-~/.dsh}/storages/llm-pi-ai/catalog/opencode-go.json`,
  rewritten at every host start from the gateway listing intersected with
  models.dev's non-deprecated set.
- Fix markers checked by `scripts/check.sh`:
  - `function startLiveCatalogRefresh(` in `dsh-llm-pi-ai/lib/index.js`
  - `function previewLiveCatalog(` in `dsh-llm-pi-ai/lib/index.js`
  - `zen/go/v1/models` in `dsh-llm-pi-ai/lib/index.js`
  - plus the live catalog cache exists and (when online) matches the live
    sources and the `opencode` CLI list.
- Pristine sources for diffing: `npm pack
  @deepseek-ai/dsh-llm-pi-ai@<version>` from the registry.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 005 is MISSING, run
  `scripts/reapply.sh`; if the patch no longer applies, re-investigate (code
  moved?) or check whether upstream shipped a live/dynamic opencode-go
  catalog (then mark UPSTREAMED in root `STATUS.md`).
