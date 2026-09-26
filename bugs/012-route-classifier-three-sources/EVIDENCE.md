# Evidence — bug 012

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v6.md` §6 ("The N1/N3/N5 collapse") and
  `~/Desktop/orchestrator-drill-report-v7.md` §6, `v8` §6: all three requests
  return the same template, differing only in the interpolated id.
- `~/Desktop/orchestrator-drill-evidence-v6.json` → `negative_tests` (verbatim
  strings, N1/N3 "MISCLASSIFIED", N5 "EXACT MATCH").
- Root-cause proof: `gpt-5.6-luna` is in the shipped adapter catalog
  (`@earendil-works/pi-ai/dist/providers/data/opencode-go.json`) yet was reported
  as unserved; the live cache
  `~/.dsh/storages/llm-pi-ai/catalog/opencode-go.json` lists 32 ids including
  `glm-5.3-flash` and `gpt-5.6-luna`.
- Source: `dsh-tool-subagent` `assertAllowedModelSelection` +
  `listSubagentModels` both branched on `llm.listModels(provider)`;
  `dsh-llm-pi-ai`'s `listModels` returns `snapshot.models.getModels(provider)`
  (configured only).

## Fix markers (checked by `scripts/check.sh`)

- `async function modelRouteRejection(llm, provider, model)` and
  `is not configured for this deployment` in `dsh-tool-subagent`;
- `async listCatalogModels(provider) {` + `detachCatalog(provider, models) {` in
  `dsh-llm`;
- `listCatalogModels(provider) {` + `catalogModels(provider).values()` in
  `dsh-llm-pi-ai`.

## Live re-verification (2026-09-26, installed bundle, orchestrator session)

Session `session-bddb308e-68e1-4ef3-ad74-4aeb3fd14d75` (created on `standard`,
switched to `orchestrator`; pin present: 8 configured ids). The lead called
`subagent` once per request; every string below is the tool result text from the
session transcript (`tool/result` events seq 27, 32, 37, 43), not the model's
summary:

**A — `glm-5.3-flash` @ high (seq 27), class 2:**

```
Error: LLM provider "opencode-go" serves model "glm-5.3-flash", but that model is not configured for this deployment (child LLM route "opencode-go/glm-5.3-flash" is not allowed for this Session)
```

**B — `gpt-5.6-luna` @ high (seq 32), class 2:**

```
Error: LLM provider "opencode-go" serves model "gpt-5.6-luna", but that model is not configured for this deployment (child LLM route "opencode-go/gpt-5.6-luna" is not allowed for this Session)
```

**C — `totally-invented-model-xyz` @ high (seq 37), class 3:**

```
Error: LLM provider "opencode-go" does not serve a model with id "totally-invented-model-xyz" (child LLM route "opencode-go/totally-invented-model-xyz" is not allowed for this Session)
```

**D — `mimo-v2.5` @ medium (seq 43), allowlisted → spawned:**

```
started subagent 787c447a-aa17-4718-ab27-483c4e33a862
```

The child settled with `READY` (parent observed the settlement notice). Class 1
(configured but outside the allowlist) is not constructible in this deployment
because configured == allowlisted (8 routes); the branch is exercised by
construction and shares the same helper as classes 2/3.

Class-2 classification was additionally confirmed for the `list_subagent_models`
path by the same helper (both rejection sites call `modelRouteRejection`; the
check script asserts both call sites).

## Commands

```bash
# the four tool results, verbatim
zstd -dc ~/.dsh/sessions/--home-john-Documents-Projects-DSH--/session-bddb308e-68e1-4ef3-ad74-4aeb3fd14d75/session.v3.jsonl.zstd \
  | python3 -c "import sys,json
for l in sys.stdin:
    d=json.loads(l)
    if d.get('type')=='tool/result':
        print(json.dumps(d['data']['message']['content'][0]['content'][0]['text']))"
```
