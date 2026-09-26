# Evidence — bug 024

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v11.md` §8.2: `agent-end` for the
  rejected pin carried `error`/`requestedProvider`/`requestedModel`, but
  `run-end` held only `{"runId":…,"stopReason":"completed"}`; the script still
  received a bare `null` (014b residual).
- Same section / §10 friction #2: the identical not-configured-model
  condition produced
  `pi-ai provider "opencode-go" has no configured model "glm-5.3-flash" (UNKNOWN_MODEL)`
  through `workflow` and
  `… serves model "glm-5.3-flash", but that model is not configured for this deployment …`
  through the direct `subagent` tool.
- `~/Documents/Projects/DSH/ORCHESTRATOR-OPTIMIZATION-PLAN.md` §22.3 residual
  1 and §22.4 (`024`).

## Fix markers (checked by `scripts/check.sh`)

- `dsh-llm`: `function modelResolutionDiagnostic(provider, model, served)`,
  `const MODEL_NOT_CONFIGURED_CODE = "MODEL_NOT_CONFIGURED"`,
  `const UNKNOWN_MODEL_CODE = "UNKNOWN_MODEL"`, the export list entry.
- `dsh-llm-pi-ai`:
  `modelResolutionDiagnostic(provider, model, catalogModels(provider).has(model))`.
- `dsh-tool-subagent`:
  `const diagnostic = modelResolutionDiagnostic(provider, model, catalog);`,
  both `throw await modelRouteRejection(llm,` call sites, `"ROUTE_NOT_ALLOWED"`.
- `dsh-tool-workflow`: `const failures = /* @__PURE__ */ new Map();`,
  `failedAgents: failure.count`, `failures.delete(runId);`;
  `readonly failedAgents?: number;` in `types.d.ts`.

## Live verification (2026-09-26, installed bundle, headless profile)

Temporary `--patch` overlay adding two fixed-pin one-shot rows
(`scripts/fixture/pin-rows.patch.yml`, live copy in
`/tmp/opencode/batch4/p24-live/`); the user's presets untouched. Lead session
`session-4b3f46c9-4186-4241-b630-198cfbdc9f01`
(`~/.dsh/sessions/--tmp-opencode-batch4-p24-live--/`).

Workflow probe (`agent()` × 2 with rejected pins) — parent transcript events,
verbatim:

```
tool-workflow/agent-start {"runId":"fb61c378-…","seq":1,"label":"Reply READY","childId":"d961d930-…","requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
tool-workflow/agent-end   {"runId":"fb61c378-…","seq":1,"outcome":"failed","error":"LLM provider \"opencode-go\" serves model \"glm-5.3-flash\", but that model is not configured for this deployment (MODEL_NOT_CONFIGURED)","requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
tool-workflow/agent-start {"runId":"fb61c378-…","seq":2,"label":"Reply READY","childId":"9fe1d6bb-…","requestedProvider":"opencode-go","requestedModel":"totally-invented-model-xyz"}
tool-workflow/agent-end   {"runId":"fb61c378-…","seq":2,"outcome":"failed","error":"LLM provider \"opencode-go\" does not serve a model with id \"totally-invented-model-xyz\" (UNKNOWN_MODEL)","requestedProvider":"opencode-go","requestedModel":"totally-invented-model-xyz"}
tool-workflow/run-end     {"runId":"fb61c378-…","stopReason":"completed","failedAgents":2,"error":"LLM provider \"opencode-go\" serves model \"glm-5.3-flash\", but that model is not configured for this deployment (MODEL_NOT_CONFIGURED)","requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
```

Direct-subagent probe (same conditions; lead tool results, verbatim):

```
Error: LLM provider "opencode-go" serves model "glm-5.3-flash", but that model is not configured for this deployment
  → error payload: {"name": "LlmError", "code": "MODEL_NOT_CONFIGURED"}

Error: LLM provider "opencode-go" does not serve a model with id "totally-invented-model-xyz"
  → error payload: {"name": "LlmError", "code": "UNKNOWN_MODEL"}
```

The workflow record's diagnostics are the identical canonical sentence plus
`(CODE)` (the in-process driver's `turnDiagnostic` renders the code); the
direct path's message is the same sentence with the code on the error object.

**Verification limit (disclosed):** this headless probe drives the direct
path through the pi-ai preflight of a fixed-pin row, so the shared-formatter
half of `modelRouteRejection` is not exercised live here (the headless
profile mounts no preset, and `modelSelectionSettings: true` rows require a
scoped preset Context). Its call-site change is covered by `check.sh` markers
and will be exercised by the v12 drill's Orchestrator `subagent` row.

## Commands

```bash
bash bugs/024-workflow-diagnostics/scripts/check.sh

# live (temp overlay only; presets untouched)
cd /tmp/opencode/batch4/p24-live
dsh --profile headless --patch ./pin-rows.patch.yml "<workflow with two rejected pins; two direct pins>"

# transcript events (read-only)
zstd -dc ~/.dsh/sessions/--tmp-opencode-batch4-p24-live--/session-4b3f46c9-4186-4241-b630-198cfbdc9f01/session.v3.jsonl.zstd \
  | grep -o '"type":"tool-workflow/[a-z-]*","seq":[0-9]*[^}]*}'
```

## Pre-fix behavior (module-level, no live re-run)

`scripts/check.sh` exits 1 against the pre-fix stack (bug 024's shadow-bundle
round trip), and the pre-fix wordings are quoted above from the drill report.
