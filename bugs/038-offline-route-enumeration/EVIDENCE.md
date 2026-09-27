# Evidence — bug 038

## Primary evidence (pre-fix)

- Drill **v25 §0**: "the pins were taken from the preset map and verified
  afterwards from each child's own `request/header`" because the preflight
  could not obtain a route list — `/v1/models` → **404**, `/api/routes` →
  **401**, `/api/providers` → **401**.
- Drill **v26 §0 + §7 F-route**: the same three codes, and the run's whole
  header/effort table went **NOT MEASURED**.
- Drill **v22/v23**: the in-session `list_subagent_models(provider)` returned
  the 8 routes — the answer exists, only the script-side/offline path was
  missing.

## Fix markers (checked by `scripts/check.sh`)

- `dsh-local-session.mjs`: `args.routes = true;`,
  `function readPolicyRoutes(settingsPath)`,
  `function readCatalogRoutes(catalogDir)`,
  `#subagent-model-selection.allowedModels`, `routes: UNKNOWN (`.
- `README.md`: `## How to enumerate routes`,
  `The authority is the **in-session \`list_subagent_models\` tool**`.
- The check also chains the bug-020 `check.sh` (whose three host-contract
  markers must still pass); its output is surfaced only when it fails, so the
  suite keeps one PRESENT line per fix.

## Before/after check output

```
$ (pre-038: helper + README at HEAD)
missing: args.routes = true; (in dsh-local-session.mjs)
missing: function readPolicyRoutes(settingsPath) (in dsh-local-session.mjs)
missing: function readCatalogRoutes(catalogDir) (in dsh-local-session.mjs)
missing: #subagent-model-selection.allowedModels (in dsh-local-session.mjs)
missing: routes: UNKNOWN ( (in dsh-local-session.mjs)
missing: ## How to enumerate routes (in README.md)
missing: The authority is the **in-session `list_subagent_models` tool** (in README.md)
bug-038 fix MISSING
exit=1

$ (post-038)
bug-038 fix PRESENT
exit=0

$ scripts/reapply.sh (twice) -> "already present -- nothing to do" (exit 0, idempotent)
```

## Live evidence — offline `--routes` (real `~/.dsh`, no server, no prompt)

```
$ node bugs/020-scriptable-session-creation/scripts/dsh-local-session.mjs --routes
opencode-go/deepseek-v4-flash
opencode-go/deepseek-v4.1-flash
opencode-go/longcat-2.0
opencode-go/mimo-v2.5
opencode-go/mimo-v2.6-flash
opencode-go/muse-spark-1.2-contributor
opencode-go/muse-spark-1.3-contributor
opencode-go/space-bunny-free
routes: 8
basis: policy=/home/john/.dsh/settings.yaml#subagent-model-selection.allowedModels (8 entries) ∩ catalog=/home/john/.dsh/storages/llm-pi-ai/catalog/*.json (33 models across 1 document(s))
exit=0

$ node bugs/020-scriptable-session-creation/scripts/dsh-local-session.mjs --routes --json
{"routes":["opencode-go/deepseek-v4-flash","opencode-go/deepseek-v4.1-flash","opencode-go/longcat-2.0","opencode-go/mimo-v2.5","opencode-go/mimo-v2.6-flash","opencode-go/muse-spark-1.2-contributor","opencode-go/muse-spark-1.3-contributor","opencode-go/space-bunny-free"],"count":8,"basis":{"policy":"/home/john/.dsh/settings.yaml#subagent-model-selection.allowedModels","catalog":"/home/john/.dsh/storages/llm-pi-ai/catalog/*.json","policyRoutes":8,"catalogModels":33}}
exit=0
```

## Live evidence — the honest UNKNOWN failure mode

```
$ DSH_HOME=/tmp/orch-drill-038-empty/home node …/dsh-local-session.mjs --routes
routes: UNKNOWN (cannot read /tmp/orch-drill-038-empty/home/settings.yaml: ENOENT; cannot read catalogue directory /tmp/orch-drill-038-empty/home/storages/llm-pi-ai/catalog: ENOENT)
basis: policy=/tmp/orch-drill-038-empty/home/settings.yaml#subagent-model-selection.allowedModels ∩ catalog=/tmp/orch-drill-038-empty/home/storages/llm-pi-ai/catalog/*.json
exit=1

$ DSH_HOME=/tmp/orch-drill-038-empty/home node …/dsh-local-session.mjs --routes --json
{"routes":null,"count":null,"unknown":"cannot read /tmp/orch-drill-038-empty/home/settings.yaml: ENOENT; cannot read catalogue directory /tmp/orch-drill-038-empty/home/storages/llm-pi-ai/catalog: ENOENT","basis":{"policy":"/tmp/orch-drill-038-empty/home/settings.yaml#subagent-model-selection.allowedModels","catalog":"/tmp/orch-drill-038-empty/home/storages/llm-pi-ai/catalog/*.json"}}
exit=1

$ (policy present, catalogue missing — a partial source is still UNKNOWN)
routes: UNKNOWN (cannot read catalogue directory /tmp/orch-drill-038-empty/home/storages/llm-pi-ai/catalog: ENOENT)
exit=1
```

## Live cross-check — in-session authority beside the offline set

The 020 helper created an **orchestrator** session on a scratch `DSH_HOME`
(real `~/.dsh` read via symlinks) and prompted the lead to call
`list_subagent_models({provider:"opencode-go"})`:

```
{"sessionId":"session-8d28a076-3301-40ff-b3ad-d05a7b3b237e","agentPreset":"orchestrator","cwd":"/tmp/orch-drill-038-session/work","webPid":183777,"baseUrl":"http://127.0.0.1:45765/?token=…","prompted":true,"turnCompleted":true,"headerToolCount":178,"assistantText":"opencode-go/longcat-2.0 — LongCat-2.0\nopencode-go/deepseek-v4-flash — DeepSeek V4 Flash\nopencode-go/deepseek-v4.1-flash — DeepSeek V4.1 Flash\nopencode-go/mimo-v2.6-flash — MiMo-V2.6-Flash\nopencode-go/space-bunny-free — Space Bunny Free\nopencode-go/mimo-v2.5 — MiMo V2.5\nopencode-go/muse-spark-1.3-contributor — Muse Spark 1.3 Contributor\nopencode-go/muse-spark-1.2-contributor — Muse Spark 1.2 Contributor","turnEndReason":{"kind":"completed"},"waitedMs":11840}
```

The two sets are the **same 8 routes** (`deepseek-v4-flash`,
`deepseek-v4.1-flash`, `longcat-2.0`, `mimo-v2.5`, `mimo-v2.6-flash`,
`muse-spark-1.2-contributor`, `muse-spark-1.3-contributor`,
`space-bunny-free`); only the ordering differs. The session composed cleanly
(`headerToolCount: 178`, `turnCompleted: true`) — the tool is present in the
preset that owns it.

## Live evidence — the auth fence is unchanged

Scratch boot (`dsh web --no-open --port 0` on the scratch home), unauthenticated
requests with no cookie:

```
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:35187/api/routes    -> 401
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:35187/api/providers -> 401
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:35187/v1/models     -> 404
GET token index (the helper's exchange)                                     -> 303
```

The already-running server (pid 161574, port 3080) answers identically:

```
existing dsh web :3080 /api/routes    -> 401
existing dsh web :3080 /api/providers -> 401
existing dsh web :3080 /v1/models     -> 404
```

No auth was weakened: `--routes` never contacts a server, and the `/api/*`
fence still requires the process-token cookie.

## Verification limits (disclosed)

- The intersection is between the **policy** file and the **shipped
  catalogue**; a route the gateway serves live but the catalogue document does
  not list is not printed (the catalogue is the same source the host's
  `llm.listModels` overlays; refresh it by running the host as usual).
- The settings parser deliberately supports only the documented
  `subagent-model-selection: {enabled, allowedModels: [{provider, model}]}`
  shape; any other shape is an UNKNOWN rather than a best-effort parse.
- The orchestrator preset's doctrine sentence about the route list is out of
  scope for this repository (the assistant maintains it; recorded in
  `STATE.md`).
