# Evidence — bug 005 (`opencode-go` live catalog)

All observations 2026-09-25 on this machine.

## Environment

- `@deepseek-ai/dsh` 0.1.5-rc.2 at
  `/home/john/.local/lib/node_modules/@deepseek-ai/dsh`
- `@earendil-works/pi-ai` 0.85.1 (nested in the same tree)
- `opencode` CLI at `/home/john/.local/bin/opencode` (build
  `3e60524f9b-local`)
- Live metadata cache on this machine: `~/.cache/opencode/models.json`
  (4,926,057 bytes, the models.dev `api.json` document opencode caches)

## Stale-list measurement (pre-fix)

```console
$ node -e 'const v=require(".../pi-ai/dist/providers/data/opencode-go.json");
  console.log(Object.values(v).flatMap(g=>Object.keys(g)).length)'
27
$ node -e 'require(".../js-yaml").load(fs.readFileSync("~/.dsh/settings.yaml"))
  ["llm-pi-ai"].providers["opencode-go"].models.length'
5
$ curl -s https://opencode.ai/zen/go/v1/models | node -e '...ids.length'
42
$ node -e 'const d=require("/tmp/models-dev-api.json")["opencode-go"].models;
  active = !deprecated && status!=="deprecated"; ...'
41 total / 32 active / 9 deprecated
$ opencode models | sed -n 's|^opencode-go/||p' | wc -l
32
```

Gateway-only ids missing from the bundled 27 (15): `deepseek-flash`,
`deepseek-v4.1-flash`, `glm-5`, `gpt-6-luna`, `grok-4.5`, `grok-4.7`,
`hy3-preview`, `kimi-k2.5`, `mimo-v2-omni`, `mimo-v2-pro`,
`mimo-v2.6-flash`, `mimo-v2.6-pro`, `minimax-m2.5`, `qwen3.5-plus`,
`space-bunny-free`. No bundled id is absent from the gateway.

Latest pi-ai is no fix: `npm view @earendil-works/pi-ai version` → `0.86.0`;
its `opencode-go.json` has 27 entries too (adds `deepseek-v4.1-flash`, drops
`omen-alpha`), still missing `grok-4.7`, `gpt-6-luna`, `mimo-v2.6-flash`,
`mimo-v2.6-pro`, `space-bunny-free`.

The user's `settings.yaml` pin (5 models) was the served list because
`resolveRouteModels()` replaces the catalog when `models` is configured
(`dsh-llm-pi-ai/lib/index.js`, `entries = configured.length > 0 ? configured :
defaults`). Its original content is preserved at
`~/.dsh/settings.yaml.bak-bug005-20260925`.

## Patch verification

```console
$ patch --dry-run -p0 index.js < .../dsh-llm-pi-ai-live-opencode-go-catalog.patch
checking file index.js
$ # installed file (bug 003 already applied), dry-run then apply:
Hunk #3 succeeded at 2094 (offset 11 lines).
Hunk #4 succeeded at 2997 (offset 11 lines).
Hunk #5 succeeded at 3027 (offset 11 lines).
$ node --check .../dsh-llm-pi-ai/lib/index.js && echo APPLIED-OK
APPLIED-OK
```

Fix markers (grepped by `scripts/check.sh`): `function
startLiveCatalogRefresh(`, `function previewLiveCatalog(`, `zen/go/v1/models`.

## Conversion unit test (stubbed sources, deterministic)

`buildLiveCatalog("opencode-go", ["seed-flash","new-family","new-anthropic",
"gone","unknown"], metadata, bundled)` returns `seed-flash, new-family,
new-anthropic`:

- `seed-flash` keeps the bundled `api`/`compat`/`thinkingLevelMap`, refreshes
  name/context/maxTokens/cost, and drops `video` from models.dev input.
- `new-family` inherits the same-family sibling's `openai-completions`,
  `compat.thinkingFormat: "deepseek"`, and `/v1` base URL, with its own
  `thinkingLevelMap` (`off:null, minimal:null, low:"low", medium:null,
  high:"high", xhigh:null, max:null`).
- `new-anthropic` maps `provider.npm: "@ai-sdk/anthropic"` →
  `anthropic-messages` and the non-`/v1` base URL; no sibling means no compat
  or map.
- `gone` (`deprecated: true`) is filtered; `unknown` (no metadata) is dropped
  — parity with what `opencode models` lists.

## Live source test (2026-09-25)

```console
$ node -e 'const m=await import(.../dsh-llm-pi-ai/lib/index.js);
  const p=await m.previewLiveCatalog("opencode-go"); ...'
preview count: 32
api distribution: {"anthropic-messages":2,"openai-completions":24,"openai-responses":6}
deepseek-v4.1-flash: {"api":"openai-completions","reasoning":true,
 "input":["text","image"],"contextWindow":1000000,"maxTokens":384000,
 "compat":{"thinkingFormat":"deepseek",...},"thinkingLevelMap":{...low,high,max}}
gpt-6-luna: openai-responses (family gpt-luna→gpt-5.6-luna sibling),
 tiers [{inputTokensAbove: 272000, ...}]
```

Cache write/serve/idempotence:

```console
$ node -e 'm.refreshLiveCatalog("opencode-go")'
cache path: /home/john/.dsh/storages/llm-pi-ai/catalog/opencode-go.json exists before: false
refresh 1 changed: true exists after: true
refresh 2 changed: false
served via catalogModels: 32 | has v4.1: true | has omen-alpha(deprecated): false
cache doc: opencode-go 2026-09-25T14:08:14.042Z 32
```

Exact parity: served ids vs `opencode models` opencode-go ids — 32 vs 32,
no id on either side alone.

## Fix check and its failure paths

```console
$ bugs/005.../scripts/check.sh
ok: 32 live opencode-go models match .../opencode-go.json
bug-005 fix PRESENT                                    # exit 0

$ DSH_HOME=/tmp/.../fakehome .../check.sh               # settings pin restored in fake home
settings pin present: llm-pi-ai.providers.opencode-go.models replaces the live catalog
bug-005 fix MISSING                                    # exit 1

$ # cache truncated to 31 (deepseek-v4.1-flash removed)
live catalog drift against .../opencode-go.json
  available but not served: deepseek-v4.1-flash
opencode CLI parity FAILED (32 CLI vs 31 served)
bug-005 fix MISSING                                    # exit 1
```

`scripts/reapply.sh` is idempotent (second run: `unchanged`, `check.sh` exit
0, `re-applied OK`).

## End-to-end host verification

1. Configured `agent-default-model` as `opencode-go/deepseek-v4.1-flash` — an
   id **absent from pi-ai 0.85.1's bundled catalog** — and booted the host:

   ```console
   $ dsh --profile headless "Reply with exactly the single word: pong"
   pong                                                  # exit 0, empty stderr
   ```

   This proves the host resolved a model only the live catalog carries, and
   bug 003's session header still carries the request. Settings were restored
   afterwards (default back to `deepseek-v4-flash`).

2. Startup self-heal: removed `deepseek-v4.1-flash` from the cache (31),
   booted again, then:

   ```console
   cache before boot: 31
   pong
   cache after boot: 32 has v4.1: true                  # exit 0, empty stderr
   ```

## Known limits

- The changed-set announcement (`PiAiAdapter.invalidate()` +
  `registration.replace(routes)` → `llm/adapters-updated`) is verified by code
  path and by the fact that settings edits use the same publish; the picker
  reload itself was not observed in a browser this run.
- The refresh is intentionally non-blocking: the first paint of a model picker
  in the ~1 s before the fetch lands uses the previous launch's cache.
- Metadata source (models.dev) may lag a brand-new gateway model by up to its
  own refresh interval; that is the same source `opencode models` reads, so
  dsh and opencode stay in lockstep by construction.
