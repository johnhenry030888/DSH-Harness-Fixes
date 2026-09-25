# Bug 005: `opencode-go` model list goes stale in dsh (bundled catalog + settings pin, no live refresh)

## Symptoms

The models dsh offers for `provider: "opencode-go"` are a snapshot, not the
gateway's live list:

- With the pre-fix `~/.dsh/settings.yaml`, the dsh models panel served **5**
  models (`deepseek-v4-flash`, `longcat-2.0`, `mimo-v2.5`,
  `muse-spark-1.2-contributor`, `muse-spark-1.3-contributor`). Without the pin,
  it served pi-ai's bundled catalog of **27**.
- `opencode models` on the same machine lists **32** opencode-go models, and
  the gateway advertises **42** ids (9 deprecated, plus two aliases models.dev
  does not list).
- Model ids that exist live but not in dsh include `deepseek-v4.1-flash`,
  `grok-4.7`, `gpt-6-luna`, `mimo-v2.6-flash`, `mimo-v2.6-pro`,
  `space-bunny-free`, and more. `deepseek-v4.1-flash` (the model opencode
  itself runs on this machine) was not selectable in dsh at all.
- The Models settings page's "fetch models" action could not help: for a
  catalog-backed provider it returns the installed catalog, not the endpoint.

## Root cause

Three layers, all release-locked or manual:

1. **pi-ai's bundled catalog is fixed at release time.**
   `@earendil-works/pi-ai` resolves `opencode-go` models from
   `dist/providers/data/opencode-go.json` (27 entries in 0.85.1; `0.86.0`, the
   current latest, still ships only 27 — it adds `deepseek-v4.1-flash` and
   drops `omen-alpha`, but is missing five models that are already live).
   `dsh-llm-pi-ai`'s `catalogModels()` (`lib/index.js`) is the only source for
   `resolveRouteModels()` and `listModels()`, so dsh cannot see a model until
   a pi-ai release ships it.
2. **A configured `models` list replaces the catalog.**
   `resolveRouteModels()` uses `entries = configured.length > 0 ? configured :
   defaults`, so the old `settings.yaml` pin defined the entire served list.
   It had to be maintained by hand and could never gain a new model on its own.
3. **No live path exists.**
   - `discoverModels()` short-circuits any provider pi-ai ships a catalog for:
     `if (request.provider !== void 0) { const installed = catalogModels(...);
     if (installed.size > 0) return [...installed.values()] }` — it never
     probes `https://opencode.ai/zen/go/v1/models`.
   - `reuseCatalogProvider()` deliberately drops pi-ai's `refreshModels`
     (its comment says the settings document *is* the catalog), and dsh never
     calls `Models.refresh()` anywhere.
   - Config model entries cannot carry a per-model `api` (`modelFields` has
     only `name`, `contextWindow`, `maxTokens`, `input`, `reasoningEfforts`,
     `compat`), while opencode-go mixes `anthropic-messages`
     (`minimax-m3`, `qwen3.8-flash`), `openai-responses`
     (`gpt-5.6-luna`, `grok-4.6`, `muse-spark-*`), and
     `openai-completions`. A hand-generated settings list therefore cannot
     represent the live catalog without misrouting whole families.

## Fix design

Give `dsh-llm-pi-ai` a **live catalog overlay** for `opencode-go`, refreshed
at every host start, with the bundled catalog as the only fallback:

- **Synchronous cache read at resolution time.** `catalogModels(provider)`
  now returns the live cache when one exists (the cache is a complete active
  set, so removed/deprecated ids disappear), else pi-ai's bundled catalog
  exactly as before. The cache lives at
  `${DSH_HOME:-~/.dsh}/storages/llm-pi-ai/catalog/opencode-go.json`; a missing,
  empty, or unreadable document changes nothing.
- **Background refresh at host start.** `apply()` kicks
  `startLiveCatalogRefresh()` for every configured route in the `LIVE_CATALOG`
  table (only `opencode-go` today). It:
  - fetches the gateway listing `https://opencode.ai/zen/go/v1/models`
    (unauthenticated) and `https://models.dev/api.json` (opencode's own
    metadata source), falling back to `~/.cache/opencode/models.json`, and
    failing safe (warn, keep the previous cache) when neither answers;
  - keeps the ids that are both advertised and not deprecated — the exact
    definition of `opencode models`' own list;
  - writes the cache atomically (pid-suffixed temp file + `rename`), with
    single-flight per provider so repeated settings changes do not refetch;
  - on a changed set, calls `PiAiAdapter.invalidate()` and
    `registration.replace(routes)`, the same `llm/adapters-updated` publish
    path settings edits already use, so an open model picker reloads without a
    host restart.
  - skips a route whose profile pins `models` (the pin would win anyway).
- **Descriptor conversion.** pi-ai's tested entry wins for an id it ships
  (protocol, `compat`, `thinkingLevelMap`, `baseUrl`), with name, capacity,
  price, and modalities refreshed from metadata. A new id inherits its
  closest same-`family` sibling's protocol/compat, or the models.dev `npm`
  mapping (`@ai-sdk/anthropic` → `anthropic-messages`,
  `@ai-sdk/openai` → `openai-responses`, else `openai-completions`), falling
  back to a provider default. Effort values become a total
  `thinkingLevelMap` (`none` stays unsupported; every other base level is
  pinned explicitly). pi-ai modalities are text/image only, so audio/video/pdf
  from models.dev are dropped.
- **Settings pin removed.** `llm-pi-ai.providers.opencode-go.models` is gone
  from `~/.dsh/settings.yaml` (backup:
  `~/.dsh/settings.yaml.bak-bug005-20260925`), so the live catalog is what
  gets served. Keeping a pin is still valid user configuration; it will
  simply replace the live list again, and `check.sh` calls that out.
- **Scripts reuse the host's own converter.** The patch exports
  `buildLiveCatalog`, `previewLiveCatalog`, `refreshLiveCatalog`,
  `liveCatalogPath`, and `catalogModels` so
  `scripts/refresh-opencode-go-catalog.mjs` (refresh / `--check`) can never
  drift from what the host serves.

Evidence that the contract now holds: dsh serves 32 models whose ids are
byte-for-byte the `opencode models` opencode-go list, `deepseek-v4.1-flash`
was callable end-to-end through the host, and a deliberately truncated cache
was healed back to 32 during a single headless boot.

## Deployed here

- Patch: `patches/dsh-llm-pi-ai-live-opencode-go-catalog.patch` (pristine
  `@deepseek-ai/dsh-llm-pi-ai@0.1.5-rc.2` → installed; applies no-fuzz on top
  of bug 003's patch; `node --check` clean).
- Cache: `~/.dsh/storages/llm-pi-ai/catalog/opencode-go.json` (32 models,
  refreshed 2026-09-25).
- `scripts/check.sh` (exit 0 = fix present and live-parity holds),
  `scripts/reapply.sh` (idempotent), `scripts/refresh-opencode-go-catalog.mjs`
  (manual refresh / `--check`).

## Rejected alternatives

- **Regenerate the `models:` pin by hand.** Cannot express mixed protocols
  (no per-model `api` in the schema) and recurs with every model release.
- **Bump pi-ai to 0.86.0.** `^0.85.1` permits only 0.85.x today, and 0.86.0
  still ships 27 models — one model gained, five live ones missing. Not a
  mechanism.
- **Patch pi-ai's `dist/providers/data/opencode-go.json` directly.** Edits a
  generated third-party artifact that every pi-ai release replaces, and is
  wiped by the next `dsh` update.
- **Second hand-declared route (`opencode-go-live`).** Changes provider ids,
  so every `opencode-go/<model>` reference (sessions, defaults, subagent
  allow-lists) breaks, and the picker shows a duplicate provider.
- **Use pi-ai's `Models.refresh()` machinery (as `radius` does).** dsh never
  calls it, `reuseCatalogProvider` drops `refreshModels`, pi-ai ships only an
  in-memory `ModelsStore`, and each config change rebuilds the `Models`
  instance — the overlay merge point is smaller and survives all three.
- **A wrapper script that refreshes before `exec dsh`.** Only covers launch
  paths that go through the wrapper; the host-side refresh covers every entry
  point (web, headless, desktop).
