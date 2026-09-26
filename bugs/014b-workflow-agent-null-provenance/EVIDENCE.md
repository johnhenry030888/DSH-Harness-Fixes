# Evidence — bug 014b

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v10.md` §8 Phase 7 ("rejected pin
  inside a workflow — fix 014 confirmed") and §10 friction #4: `agent-end`
  carried the full diagnostic while `scriptSaw:"null"`, and the description
  did not mention the run record.
- `~/Desktop/orchestrator-drill-report-v9.md` §9 #2 (same residual).
- Source: the workflow tool's `DESCRIPTION` documented only
  "Resolves `null` when the child fails (filter with `.filter(Boolean)`)."

## Fix markers (checked by `scripts/check.sh`)

- `read the run record, never the return value`
- `a rejected route and a child that produced nothing are both`
- `when the child failed before producing output`

## Live verification (2026-09-26, installed bundle, headless profile)

Asked the headless lead to quote the relevant part of the `workflow` tool
description; it returned under `WORKFLOW-NULL-DOC`:

> `agent(prompt, opts?): Promise<any>` — … Resolves `null` when the child
> fails (filter with `.filter(Boolean)`) — the return value deliberately says
> nothing about WHY, so a rejected route and a child that produced nothing
> are both `null`. To attribute a failure, read the run record, never the
> return value: every stage emits `workflow/agent-start`/`agent-end` records
> in the caller's run history whose `agent-end` carries the `error`
> diagnostic plus `requestedProvider`/`requestedModel` when the child failed
> before producing output.

i.e. the model-facing description itself now carries the run-record lookup.

## Commands

```bash
bash bugs/014b-workflow-agent-null-provenance/scripts/check.sh
dsh --profile headless "Quote verbatim the part of your workflow tool's description that says what agent() resolves to when a child fails, and what to read to attribute the failure."
```
