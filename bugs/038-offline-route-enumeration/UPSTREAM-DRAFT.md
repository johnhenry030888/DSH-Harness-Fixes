# Upstream draft — bug 038

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** Document how to enumerate the served (policy-filtered) subagent
routes from a script — the in-session tool exists, the offline path does not

**Body:**

Drill v25 §0 and v26 §0/§7 F-route both hit the same preflight wall: the run
could not obtain the list of served routes. `/v1/models` answers **404** (not
mounted), and `/api/routes` / `/api/providers` answer **401** (the `/api`
channel requires the per-process token → cookie exchange). The run therefore
took its pins from the preset map and verified them afterwards from each
child's own `request/header`; v26's header/effort table went **NOT MEASURED**.

The information already exists in-session — `list_subagent_models()` /
`({provider})` / `({provider, model})` returns the policy-filtered providers,
models and effort ladders (8 routes in v22/v23 and again in this fix's
cross-check, on a clean 178-tool orchestrator session). What is missing is a
documented, script-side/offline path for a preflight that has no LLM session
yet.

Request:

1. Document the authority and the fences in one place: the in-session
   `list_subagent_models` tool is the authority; `/api/*` needs the
   process-token cookie; `/v1/models` is not mounted.
2. Consider a supported offline enumeration over the same two local sources
   the host composes from (`settings.yaml`'s
   `subagent-model-selection.allowedModels` ∩
   `storages/llm-pi-ai/catalog/*.json`), stating its basis and failing loudly
   (never guessing) when a source is missing. A helper exists in the
   DSH-Harness-Fixes repository (`bugs/020-.../scripts/dsh-local-session.mjs
   --routes`), so the ask is for the documented contract, not a new service.

No new RPC method is needed and the auth fence must stay untouched.
