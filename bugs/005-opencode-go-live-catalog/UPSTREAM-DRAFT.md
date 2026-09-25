# UPSTREAM DRAFT — `:bug: Bug: opencode-go model list goes stale (bundled catalog is release-locked, no live refresh)`

Status: NOT-FILED.

---

dsh's `opencode-go` model list goes stale between pi-ai releases, and there is
no path that can refresh it:

Environment: dsh 0.1.5-rc.2 with `@earendil-works/pi-ai` 0.85.1.

- pi-ai 0.85.1 ships 27 opencode-go models; the gateway
  (`https://opencode.ai/zen/go/v1/models`, unauthenticated) advertises 42 ids;
  models.dev lists 41 (32 active, 9 deprecated); `opencode models` shows 32.
  Missing from the bundled catalog: `deepseek-v4.1-flash`, `grok-4.7`,
  `gpt-6-luna`, `mimo-v2.6-flash`, `mimo-v2.6-pro`, `space-bunny-free`, and
  more. Even the current latest pi-ai (`0.86.0`) still ships only 27 — it adds
  `deepseek-v4.1-flash` and drops `omen-alpha`, but five already-live models
  remain absent.
- `dsh-llm-pi-ai` exposes no live path: `catalogModels()` is the only source
  for `resolveRouteModels()`/`listModels()`, `discoverModels()` short-circuits
  on any provider pi-ai ships a catalog for (so the Models page "fetch" returns
  the bundled list), `reuseCatalogProvider()` drops pi-ai's `refreshModels`
  ("this route's catalog is the settings document"), and dsh never calls
  `Models.refresh()`.
- A configured `models` list replaces the catalog at resolution time
  (`resolveRouteModels`), so a user pin freezes the list; and entries cannot
  carry a per-model `api`, so a hand-generated list cannot even represent the
  mixed protocols opencode-go serves (`anthropic-messages` for `minimax-m3` /
  `qwen3.8-flash`, `openai-responses` for `gpt-5.6-luna` / `grok-4.6` /
  `muse-spark-*`, `openai-completions` for the rest).

Suggested fixes, in increasing generality:

1. Give pi-ai's `opencode-go` provider a `fetchModels`/`refreshModels`
   implementation like the `radius` provider: fetch the gateway listing and
   merge metadata from models.dev, with a persisted last-good set.
2. Have dsh preserve and trigger that refresh for catalog routes that do not
   pin a `models` list (e.g. at host start, and on demand from the Models
   page), instead of returning the bundled catalog from `discoverModels()`.
3. Allow a per-model `api` in `models`/`modelOverrides` entries, so generated
   catalogs can express mixed-protocol providers.

A tested local patch for (2)+(1) exists for 0.1.5-rc.2 (host-side live
catalog overlay: gateway ids ∩ models.dev non-deprecated, descriptor
conversion seeded by pi-ai's own entries, background refresh at host start,
atomic last-good cache, failure-safe). After it, dsh serves the same 32 models
as `opencode models`, `deepseek-v4.1-flash` is callable end-to-end, and a
truncated cache self-heals on the next boot. Happy to share the diff and
evidence here if useful.
