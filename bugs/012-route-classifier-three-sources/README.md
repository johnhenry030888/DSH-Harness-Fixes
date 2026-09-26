# Bug 012 — fix 009's classifier reports real models as nonexistent under a pinned catalog

Severity: **high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

With `~/.dsh/settings.yaml` pinning the eight `llm-pi-ai.providers.opencode-go.models`
entries, drill v6/v7/v8 got byte-identical rejections for three different
conditions:

| # | request | observed (verbatim) | expected class |
| --- | --- | --- | --- |
| N1 | `glm-5.3-flash` @ high | `Error: LLM provider "opencode-go" does not serve a model with id "glm-5.3-flash" (child LLM route "opencode-go/glm-5.3-flash" is not allowed for this Session)` | real id, not configured |
| N3 | `gpt-5.6-luna` @ high | same template | real id, not configured |
| N5 | `totally-invented-model-xyz` | same template | no such id |

Both real ids are served by the live gateway, and `gpt-5.6-luna` is even in the
shipped pi-ai catalog. The operator was told a real model does not exist.

## Root cause

Fix 009's classifier asked `llm.listModels(provider)`, which resolves through the
adapter's **configured** model set. With a pin present that set is exactly the
eight allowlisted routes, so `served` was `false` for every off-allowlist id and
the "served but not allowlisted" branch was unreachable dead code.

## Fix design

Classify against three independent sources and name the actual reason:

1. **configured/pinned ids** — `llm.listModels(provider)` (the route config);
2. **the provider catalog** — the adapter's bundled descriptors ∪ the live
   catalog cache (`~/.dsh/storages/llm-pi-ai/catalog/<provider>.json`) ∪ the
   configured ids, exposed as a new `llm.listCatalogModels(provider)` service
   method backed by an adapter method of the same name (default: the configured
   list, so adapters without a separate catalog keep working);
3. **the Session's allowlist** — the existing `policy.routes` check.

Distinct messages (the parenthetical route text is kept on all three):

- *configured but outside the Session's allowed routes*:
  `child LLM route "P/M" is not allowed for this Session: the model is configured for this deployment but it is outside the Session's allowed routes`
- *served by the provider but not configured for this deployment*:
  `LLM provider "P" serves model "M", but that model is not configured for this deployment (child LLM route "P/M" is not allowed for this Session)`
- *not served by the provider at all* (unchanged):
  `LLM provider "P" does not serve a model with id "M" (child LLM route "P/M" is not allowed for this Session)`

Both rejection sites — the delegation preflight (`assertAllowedModelSelection`)
and `list_subagent_models`'s exact-model branch — share one
`modelRouteRejection(llm, provider, model)` helper. The effort branch is
untouched (N2 was already exact).

## Rejected alternatives

- **Drop the `models:` pin and serve the live catalog again.** That changes the
  operator's curated deployment instead of making the diagnostic honest; the pin
  is a deliberate choice (see bug 005's note and the plan §15.1).
- **Read the catalog cache file directly from `dsh-tool-subagent`.** It would
  duplicate the cache-path knowledge and still miss the bundled adapter
  descriptors; the adapter is the component that owns the catalog.
- **Add only the live cache (not the bundled catalog).** The task asks for
  "adapter catalog ∪ the live catalog cache"; a live cache that drops a
  still-shipped id must not turn it into "not served".
- **Expose the union through `listModels()` itself.** `listModels` is the
  configured-model contract several consumers rely on; changing its meaning
  would make `list_subagent_models` advertise routes the deployment cannot run.

## Files patched

- `@deepseek-ai/dsh-llm/lib/index.js`
  (`patches/dsh-llm-catalog-classification.patch`, stacks on 009)
- `@deepseek-ai/dsh-llm-pi-ai/lib/index.js`
  (`patches/dsh-llm-pi-ai-catalog-classification.patch`, stacks on 003/005)
- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-route-classification.patch`, stacks on 007–009/011)

## Acceptance evidence

See `EVIDENCE.md`. With the pin present: `glm-5.3-flash` and `gpt-5.6-luna`
report *served-but-not-configured*, `totally-invented-model-xyz` reports *not
served*, and an allowlisted route (`mimo-v2.5` @ medium) spawned and completed —
all four recorded verbatim from the session transcript.
