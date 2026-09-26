# Bug 028 — a failed workflow `agent()` reaches the script as a bare `null`, and the two call paths disagree on the code

Severity: **medium** (a pipeline silently drops an item it cannot distinguish
from "the child returned nothing"). Local fix: **APPLIED** to the
`dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

After fixes 014/024a the run record is good (`agent-end` carries `error` +
`requestedProvider`/`requestedModel`; `run-end` reports `failedAgents: 1`),
but the script still receives a bare `null` — indistinguishable from "the
agent produced nothing" — so a pipeline silently drops the item (drill v12
§7/§10 friction #6, 014b). Separately (024b) the workflow path appends
` (MODEL_NOT_CONFIGURED)` while the direct subagent path exposes the code
`MODEL_NOT_CONFIGURED` directly, so the same condition has two shapes.

## Root cause

In `worker.cjs`, `agent()`'s non-`completed` stop-reason branch emitted the
observer `agent-end` and `return null`; the structured failure code carried by
the child's terminal `turn/end` reason (`{message, code}`) was flattened into
prose by `turnDiagnostic()` and never crossed the worker boundary as data.
`SubagentResult` had `diagnostic` but no `errorCode`, so the host's
`child-settled` snapshot dropped it.

## Fix design

A discriminated failure with one stable code on both paths:

1. `dsh-subagent-in-process-driver` preserves the terminal turn failure's code
   as `SubagentResult.errorCode` (new `turnFailureCode()`); the out-of-process
   `settleRunResult()` in `dsh-subagent` does the same from the thrown error.
2. `SubagentResult` declares `errorCode?: string`; the workflow host forwards
   it in the `child-settled` snapshot.
3. `worker.cjs`'s `agent()` **rejects** a failed child with a non-fatal
   `WorkflowError` whose `code` is the child's own code (or `AGENT_RESULT` when
   none exists) and whose message is the diagnostic. Non-fatal keeps
   `pipeline()`/`parallel()` semantics: a failed item still maps to `null`,
   while a direct `await agent(...)` can `try/catch` and branch on
   `error.code`.
4. The observer `agent-end` (and therefore `tool-workflow/agent-end`) and the
   `run-end` failure summary carry `errorCode` beside the prose, and the tool
   description documents the contract.

## Rejected alternatives

- **`{ok:false, error:{code,message}}` return value.** Silently changes the
  shape of every existing script's successful-path data handling and makes
  `.filter(Boolean)` no longer mean "keep successes"; an awaited rejection is
  the language-native discriminator and cannot be mistaken for data.
- **Fatal `WorkflowError`.** Would make one failed child kill the whole script
  through `pipeline()`/`parallel()`, breaking the documented per-item `null`
  combinator contract.
- **Parse the code out of the diagnostic prose in the worker.** The code is
  present as data at the source; parsing `(MODEL_NOT_CONFIGURED)` from text is
  exactly the fragility this fix removes.
- **Suffix the code on both prose strings only (024b wording fix).** Still a
  bare `null` to the script; the task's acceptance needs a branchable value.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js` + `lib/types/types.d.ts`
  (`patches/dsh-subagent-failure-code.patch`,
  `patches/dsh-subagent-result-error-code-types.patch`)
- `@deepseek-ai/dsh-subagent-in-process-driver/lib/index.js`
  (`patches/dsh-subagent-in-process-driver-error-code.patch`)
- `@deepseek-ai/dsh-workflow-worker-thread/lib/index.js` + `lib/worker.cjs`
  (`patches/dsh-workflow-worker-thread-forward-error-code.patch`,
  `patches/dsh-workflow-worker-thread-typed-agent-failure.patch`)
- `@deepseek-ai/dsh-tool-workflow/lib/index.js` + `lib/types/types.d.ts`
  (`patches/dsh-tool-workflow-agent-failure-contract.patch`,
  `patches/dsh-tool-workflow-record-error-code-types.patch`)
- `@deepseek-ai/dsh-workflow/lib/types/types.d.ts`
  (`patches/dsh-workflow-agent-end-error-code-types.patch`)

Stacks: driver on 013/014/019; worker-thread on 006/014; tool-workflow on
014/014b/024; workflow types on 014; subagent on the 026–030 chain.

## Acceptance evidence

See `EVIDENCE.md`. Live: a workflow containing one rejected pin caught
`error.code === "MODEL_NOT_CONFIGURED"` inside the script and returned the
branch value in the tool result, while the direct `subagent` path reported the
same code for the same condition.
