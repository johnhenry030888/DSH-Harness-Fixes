# Upstream draft — bug 024

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** Workflow `run-end` hides contained failures, and the
not-configured-model diagnostic has two wordings per call path

**Body:**

Two residuals of the workflow run-record changes, both reported by drill v11:

**1. `run-end` hides failure.** A workflow run whose `agent()` pins were
rejected still reports

```json
{"runId":"…","stopReason":"completed"}
```

The rejection text appears only on the per-member `agent-end`; the script
itself receives `null` by contract. A caller scanning the run record for
"what happened" therefore sees a clean completed run.

Proposal: the model-facing `workflow` tool already mirrors every
`workflow/agent-end` into the parent session, so its recorder can keep a
first-failure summary per run and append it on `run-end`:

```json
{"runId":"…","stopReason":"completed","failedAgents":2,
 "error":"LLM provider \"opencode-go\" serves model \"glm-5.3-flash\", but that model is not configured for this deployment (MODEL_NOT_CONFIGURED)",
 "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
```

(`failedAgents` always present when any member failed; `error`/route from the
first failure; per-member detail stays on each `agent-end`.)

**2. One condition, two wordings.** The same rejected pin produces
`pi-ai provider "opencode-go" has no configured model "glm-5.3-flash" (UNKNOWN_MODEL)`
via `workflow` and `LLM provider "opencode-go" serves model "glm-5.3-flash",
but that model is not configured for this deployment …` via the direct
subagent tool — so error-matching automation cannot key on either string.

Proposal: one exported formatter in `@deepseek-ai/dsh-llm`,
`modelResolutionDiagnostic(provider, model, served)`, returning a message and
a stable code:

- `MODEL_NOT_CONFIGURED` — "serves model …, but that model is not configured
  for this deployment" (the provider catalog knows the id; the deployment
  does not configure it);
- `UNKNOWN_MODEL` — "does not serve a model with id …".

`dsh-llm-pi-ai`'s `modelOf` classifies an unresolvable id against its catalog
and throws the shared diagnostic; the direct tool's route guard renders the
same two classes through the same formatter (its
configured-but-outside-allowlist class keeps Session-specific wording and a
new `ROUTE_NOT_ALLOWED` code). The codes are machine-readable.
