# Upstream draft — bug 012

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** route rejection diagnostics collapse "unknown model id" and "not
configured for this deployment" under a pinned catalog

**Body:**

With `llm-pi-ai.providers.opencode-go.models` pinned to a curated list,
`llm.listModels(provider)` returns exactly the configured ids. A delegation
route rejection that classifies `served` with `listModels` therefore reports a
real, gateway-served id as

```
LLM provider "opencode-go" does not serve a model with id "glm-5.3-flash"
(child LLM route "opencode-go/glm-5.3-flash" is not allowed for this Session)
```

byte-identical to the message for a truly invented id. `gpt-5.6-luna` is even in
the shipped pi-ai catalog and still gets "does not serve".

Suggestion: distinguish the three sources of truth — the configured/pinned list,
the provider's own catalog (adapter descriptors ∪ the live-catalog cache), and
the Session's allowlist — and emit three messages. We ship a local patch adding
an optional adapter method `listCatalogModels(provider)` (default: the
configured list) exposed as `llm.listCatalogModels`, with the classifier
returning:

- configured but outside the allowlist → `the model is configured for this
  deployment but it is outside the Session's allowed routes`
- served but not configured → `LLM provider "P" serves model "M", but that
  model is not configured for this deployment`
- not served → the existing message

The optional default keeps every adapter working; the pi-ai adapter returns the
union of bundled, live-cache, and configured ids. Happy to open a PR.
