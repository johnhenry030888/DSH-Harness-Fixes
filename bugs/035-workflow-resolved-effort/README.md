# Bug 035 — workflow stages do not record their resolved effort, and adapters can omit the key

Severity: **medium** (an effort-matched comparison is unfalsifiable; a stage
silently ran at the lead's `max`). Local fix: **APPLIED** to the
`dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

- **v16 F5 / v17 §2**: a stage-1 workflow child silently ran at the **lead's**
  `max` while its sibling recorded `null`; the run records carried
  `requestedProvider`/`requestedModel` only.
- **v19 §5 item 2 / v25 §5 item 2**: the platform ran two "effort-matched"
  candidates at unmatched effort because one route's request header carried
  **no `reasoningEffort` key at all** (longcat-2.0). The comparison was
  therefore unfalsifiable from the transcript.
- **v26 §6 item 2** re-confirmed both as open, source-basis.

## Root cause

1. `tool-workflow/agent-start` and `agent-end` records
   (`dsh-tool-workflow/lib/index.js:58–70`) appended only the requested route
   fields; the resolved effort and its provenance existed nowhere in the run
   record.
2. `dsh-llm`'s `resolveCallWithInfo()` materialized `reasoningEffort` only
   when the caller requested one or the adapter exposed a model
   `defaultEffort`. A reasoning-capable model with neither produced a header
   config with **no key**, so "did these two run at the same effort?" could not
   be answered from `request/header`.

## Fix design

1. **Run record** (`dsh-tool-workflow`): a new `effortFields(agent)` helper
   appends `resolvedEffort` and `effortSource` to both `agent-start` and
   `agent-end`. It prefers the child's live `request/header` config (the
   authoritative read), falls back to the creation-time resolution the engine
   attached, and never omits the fields: an unresolvable value is
   `{resolvedEffort: null, effortSource: "unknown"}`.
2. **Creation-time resolution** (`dsh-workflow-worker-thread` host
   `startChild`): `resolveChildEffort(request, run)` reads the child's own
   options, the parent's live request header, and the adapter's model default
   and returns `{resolvedEffort, effortSource}` with source `pinned`,
   `inherited`, `default`, or `unknown`; the value is attached to
   `workflow/agent-start`/`agent-end` before the recorder sees them.
3. **Adapter honesty** (`dsh-llm`): when a model supports reasoning but neither
   the caller nor the adapter pinned a level, `resolveCallWithInfo()`
   materializes the explicit `"default"` sentinel, so the logged header always
   carries a `reasoningEffort` key for a reasoning-capable model. The
   `dsh-llm-pi-ai` and `dsh-llm-deepseek` adapters treat the sentinel as "no
   explicit effort" and fall back to their own defaults, preserving wire
   behaviour byte-for-byte.
4. Types updated: `WorkflowAgentInfo` (`resolvedEffort`/`effortSource`) and
   `LlmCallConfig` (the sentinel).

## Rejected alternatives

- **Add `effort` to `agent()` opts.** The workflow script contract explicitly
  rejects it (documented) and the drills rely on that; recording the resolved
  effort is the missing half, not a new pinning surface.
- **Read the header only.** At `agent-start` the header is not logged yet, so
  the record would always be `unknown`; creation-time resolution is what makes
  the start record useful, and the header still wins once present.
- **Emit `null` instead of the `"default"` sentinel.** Re-opens the v19/v25
  ambiguity: a missing key is indistinguishable from a non-reasoning model.
- **Change the adapters to always send a concrete default.** Would silently
  change wire behaviour for models whose provider default is the correct
  choice; the sentinel is a header-honesty marker, not a dispatch change.

## Files patched

- `@deepseek-ai/dsh-tool-workflow/lib/index.js`
  (`patches/dsh-tool-workflow-effort-record.patch`; stacks on 028/014/014b/024)
- `@deepseek-ai/dsh-workflow-worker-thread/lib/index.js`
  (`patches/dsh-workflow-worker-thread-effort-resolution.patch`; stacks on
  028/014/006)
- `@deepseek-ai/dsh-llm/lib/index.js`
  (`patches/dsh-llm-default-effort-sentinel.patch`; stacks on 024/012)
- `@deepseek-ai/dsh-llm/lib/types/call-config.d.ts`
  (`patches/dsh-llm-call-config-type.patch`; same stack)
- `@deepseek-ai/dsh-llm-pi-ai/lib/index.js`
  (`patches/dsh-llm-pi-ai-default-sentinel.patch`; stacks on 024/012)
- `@deepseek-ai/dsh-llm-deepseek/lib/index.js`
  (`patches/dsh-llm-deepseek-default-sentinel.patch`; raw pristine)
- `@deepseek-ai/dsh-workflow/lib/types/types.d.ts`
  (`patches/dsh-workflow-agent-info-type.patch`; stacks on 028/014)

## Acceptance evidence

`EVIDENCE.md`: the live `scripts/effort-probe.sh` runs one three-stage
workflow (longcat-2.0, deepseek-v4-flash, route-inheriting) and shows
`resolvedEffort`/`effortSource` on every `agent-start` record — including
`resolvedEffort: "max", effortSource: "inherited"` for the inheriting stage —
and a `reasoningEffort` key on every child's `request/header`
(`longcat-2.0 → "default"`).
