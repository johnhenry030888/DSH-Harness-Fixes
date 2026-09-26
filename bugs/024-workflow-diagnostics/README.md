# Bug 024 — workflow diagnostics: `run-end` hides failure, and one condition
has two wordings

Severity: **medium** (diagnostic). Local fix: **APPLIED** to the `dsh`
0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

Two residuals of bug 014, both from drill v11 §8.2 / §10 friction #2 / §11
recommendation 3:

1. **`run-end` hides failure.** A workflow run containing a **failed** agent
   still reports `tool-workflow/run-end` `{runId, stopReason: "completed"}` —
   the rejection text lives only on the per-member `agent-end`. A script that
   treats a stage's `null` as ordinary data (the documented `agent()`
   contract) produces a run record that never mentions the failure.
2. **One condition, two wordings.** The identical not-configured-model pin
   produced
   `pi-ai provider "opencode-go" has no configured model "glm-5.3-flash" (UNKNOWN_MODEL)`
   through the `workflow` path and
   `LLM provider "opencode-go" serves model "glm-5.3-flash", but that model is not configured for this deployment (child LLM route "opencode-go/glm-5.3-flash" is not allowed for this Session)`
   through the direct `subagent` tool — breaking any error-matching
   automation.

## Root cause

- `dsh-tool-workflow`'s recorder watched `workflow/agent-start`/`agent-end`
  only to mirror them into the parent session; `finish()` appended
  `{runId, stopReason}` and nothing else.
- The route diagnostic was duplicated: `dsh-llm-pi-ai`'s `modelOf` threw its
  adapter-local `pi-ai provider … has no configured model …` (code
  `UNKNOWN_MODEL` for both "not configured" and "unknown id"), while
  `dsh-tool-subagent`'s three-source classifier (bug 012) rendered its own
  served-but-not-configured and unknown-id sentences.

## Fix design

**`run-end` failure summary (recorder-local, no engine change).** The
recorder keeps a first-failure summary per active run while it already sees
every `workflow/agent-end`; `finish()` appends `failedAgents` (the count) plus
the first failure's `error`, `requestedProvider`, and `requestedModel`.
`abandon()` clears it with the active entry. Per-member detail remains on each
`agent-end`; the run record now answers "did anything fail in this run, and
why" without a second scan. `dsh-tool-workflow/lib/types/types.d.ts` gains
the fields (and the `agent-start`/`agent-end` `requestedProvider`/`requestedModel`/`error`
fields bug 014 added to the engine types but never to this event map).

**One shared formatter (no duplicate wording anywhere).**
`@deepseek-ai/dsh-llm` exports `modelResolutionDiagnostic(provider, model, served)`
returning `{code, message}`:

- `MODEL_NOT_CONFIGURED` / `LLM provider "p" serves model "m", but that model is not configured for this deployment`;
- `UNKNOWN_MODEL` / `LLM provider "p" does not serve a model with id "m"`.

`dsh-llm-pi-ai`'s `modelOf` classifies an unresolvable id against the
provider catalog (`catalogModels(provider).has(model)`, the bug-005/012
surface) and throws `LlmError` with the shared message/code. The direct
tool's `modelRouteRejection` returns an `LlmError` too: the
configured-but-outside-allowlist class keeps its Session-specific wording and
a new `ROUTE_NOT_ALLOWED` code, the served-but-unconfigured and unknown-id
classes render through the shared formatter, and both call sites now
`throw await modelRouteRejection(...)` so the code reaches the caller.

## Rejected alternatives

- **Fix only the wording and leave `run-end` alone.** The drill's complaint is
  that a completed run record can hide a failed member; a wording-only change
  leaves the record incomplete.
- **Derive the failure summary from the script's return value.** `agent()`
  resolves `null` for every failure by contract (bug 014b documents the run
  record as the attribution channel); the return value deliberately carries
  no reason.
- **Put the shared message in `dsh-llm-pi-ai` only.** The direct path's
  classifier is provider-neutral; a pi-ai-local string would not be shared by
  other adapters, and `dsh-tool-subagent` cannot import adapter internals.
- **Make the pi-ai message include the tool's child-route parenthesis.**
  `modelOf` serves every session, not only child routes; a "child LLM route"
  claim there would be false for a lead's own model.
- **List every failure on `run-end`.** Bounded record, single attribution:
  the first failure is the representative spawn rejection (the others usually
  cascade), the count carries multiplicity, and each `agent-end` keeps the
  full per-member detail.

## Files patched

- `@deepseek-ai/dsh-llm/lib/index.js`
  (`patches/dsh-llm-model-resolution-diagnostic.patch`; stacks on bugs
  009/012)
- `@deepseek-ai/dsh-llm-pi-ai/lib/index.js`
  (`patches/dsh-llm-pi-ai-model-resolution-diagnostic.patch`; stacks on bugs
  003/005/012)
- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-model-resolution-diagnostic.patch`; stacks on
  bugs 007/008/009/011/012/019)
- `@deepseek-ai/dsh-tool-workflow/lib/index.js`
  (`patches/dsh-tool-workflow-run-end-failure.patch`; stacks on bugs
  014/014b)
- `@deepseek-ai/dsh-tool-workflow/lib/types/types.d.ts`
  (`patches/dsh-tool-workflow-run-end-types.patch`)

The wording move also required updating the **class** markers in bug 009's
and bug 012's `check.sh` (the STATUS.md-noted precedent: a superseding fix
updates the superseded check to assert the class wherever it lives — never
one copy of the wording). No fix patch of 009/012 was touched.

## Acceptance evidence

See `EVIDENCE.md`. Live on the headless profile with a temporary `--patch`
overlay adding fixed-pin direct rows (`scripts/fixture/pin-rows.patch.yml`):

- `tool-workflow/run-end` for a run whose two `agent()` pins were rejected:

  ```json
  {"runId":"fb61c378-…","stopReason":"completed","failedAgents":2,
   "error":"LLM provider \"opencode-go\" serves model \"glm-5.3-flash\", but that model is not configured for this deployment (MODEL_NOT_CONFIGURED)",
   "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
  ```

- the same condition through the direct-subagent path:
  `Error: LLM provider "opencode-go" serves model "glm-5.3-flash", but that model is not configured for this deployment`
  with error payload `{"name":"LlmError","code":"MODEL_NOT_CONFIGURED"}`;
- the unknown-id condition: `… does not serve a model with id "totally-invented-model-xyz" (UNKNOWN_MODEL)`
  on the workflow record and the same sentence with `code: UNKNOWN_MODEL`
  through the direct path.

**Verification limit (disclosed):** the live direct-path probe reaches the
shared formatter through the pi-ai preflight (a fixed-pin row), not through
the Session-allowlist classifier, because the headless profile mounts no
agent presets and `modelSelectionSettings` rows require a scoped preset
context. The classifier change is covered by code inspection, the updated
check markers, and the v12 drill (which exercises the Orchestrator's
select-capable `subagent` row).
