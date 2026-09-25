# Bug 009 — route/effort rejection diagnostics are ambiguous

Severity: **medium**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

Two distinct failure classes return indistinguishable text:

1. A **dead/unserved route** (an invented model id) and a **served model that
   is not allowed for this Session** both returned the byte-identical
   `child LLM route "…" is not allowed for this Session`
   (`@deepseek-ai/dsh-tool-subagent/lib/index.js:97`, `:162`). Drill v4 §6
   N1 (`glm-5.3-flash`) and N3 (`gpt-5.6-luna`) were identical, so the lead
   could not tell "wrong id" from "policy limit".
2. The unsupported-effort error omitted the ladder:
   `provider "opencode-go" model "deepseek-v4.1-flash" does not support
   reasoning effort "medium"` (`@deepseek-ai/dsh-llm/lib/index.js:2120`,
   `:2124`) — no supported ids and no default, so the caller had to guess or
   re-discover them via `list_subagent_models`.

Evidence: drill v1 §4, v2 §5, v4 §6 (N1/N3 identical; N2 has no ladder).

## Root cause

- `assertAllowedModelSelection` and `listSubagentModels` checked only
  `policy.routes` (the Session's allowed list) and threw the same message for
  every miss. The provider's live catalog (`llm.listModels`) was available but
  never consulted on the failure path.
- `resolveCallWithInfo` threw before rendering `info.reasoning.efforts` /
  `info.reasoning.defaultEffort`, which it already had in hand.

## Fix design

1. `assertAllowedModelSelection` becomes async and takes the live `llm`
   runtime. On a policy miss it asks `llm.listModels(provider)`:
   - served → `child LLM route "…" is not allowed for this Session: the
     provider serves this model id, but it is outside the Session's allowed
     routes`;
   - not served (or `listModels` rejects) → `LLM provider "…" does not serve a
     model with id "…" (child LLM route "…" is not allowed for this Session)`.
   The call site now resolves `llm` once and runs the allowlist check inside
   the existing `requiresRoutePreflight` block (behavior-preserving: the check
   already returned early unless a model request existed, which implies
   preflight).
2. `listSubagentModels` gets the same classification on its exact-model
   branch (the `list_subagent_models` discovery tool).
3. `@deepseek-ai/dsh-llm` renders the ladder on both effort-rejection sites via
   `describeReasoningEfforts(reasoning)`:
   `— supported: low, high, max (default: high)`, or `— supported: none
   advertised` when the model advertises no reasoning metadata.

## Rejected alternatives

- **Make both cases the same class again and document it.** Rejected: the
  distinction is exactly what lets a lead fix an invented id without changing
  policy, and vice versa.
- **Consult `llm.listModels` inside `restrict()`/`resolveCallWithInfo` and
  throw there.** Rejected: the LLM layer owns model metadata but not the
  Session's allowlist; the policy check must stay in the delegation tool that
  owns the policy. `dsh-llm` only gains the ladder, which it owns.
- **Add a distinct error code instead of text.** Rejected as insufficient: the
  drill (and the model) sees text, not codes; the message itself must classify.
- **Call `listModels` unconditionally before every delegation.** Rejected:
  it is a catalog read; only the failure path needs it, so the fix adds it
  only after a policy miss.

## Files patched

- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-route-diagnostics.patch`, stacks on bugs 007/008)
- `@deepseek-ai/dsh-llm/lib/index.js`
  (`patches/dsh-llm-effort-ladder.patch`)

## Acceptance evidence

- `scripts/check.sh` exit 1 before, 0 after; `reapply.sh` idempotent
  (re-applies bugs 007/008 first when needed); stacked dry-run clean.
- Live (headless with a temporary orchestrator-copy preset; no user file
  edited):
  - invented id: `LLM provider "opencode-go" does not serve a model with id
    "totally-invented-model-xyz" (child LLM route
    "opencode-go/totally-invented-model-xyz" is not allowed for this Session)`;
  - served but not allowed: `child LLM route "opencode-go/glm-5.3-flash" is not
    allowed for this Session: the provider serves this model id, but it is
    outside the Session's allowed routes` (same text for `mimo-v2.6-pro`);
  - unsupported effort: `provider "opencode-go" model "deepseek-v4.1-flash"
    does not support reasoning effort "medium" — supported: low, high, max`.
