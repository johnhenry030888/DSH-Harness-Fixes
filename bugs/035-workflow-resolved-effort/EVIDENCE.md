# Evidence — bug 035

## Primary evidence (pre-fix)

- Drill **v16 F5 / v17 §2**: a stage-1 workflow child silently ran at the
  **lead's** `max` while its sibling recorded `null`; the run records carried
  `requestedProvider`/`requestedModel` only.
- Drill **v19 §5 item 2**: "one sibling's header had no `reasoningEffort` key
  at all while its pair carried `max`, so 'effort-matched by model choice' is
  unfalsifiable — check each child's own request header afterwards."
- Drill **v25 §5 item 2 / §6 item 2**: resolved effort absent from workflow
  records, confirmed open (unexercised — 0 workflow calls that run).
- Drill **v26 §6 item 2**: "Resolved effort absent from workflow run records —
  confirmed_open (source basis): run records carry
  `requestedProvider`/`requestedModel` only; `reasoningEffort` appears in
  session header/config records."

## Fix markers (checked by `scripts/check.sh`)

- `dsh-tool-workflow`: `const effortFields = (agent) => {`,
  `resolvedEffort: headerEffort ?? agent.resolvedEffort ?? null`,
  `...effortFields(agent)`.
- `dsh-workflow-worker-thread`: `async resolveChildEffort(request, run)`,
  `this.childEfforts.set(run.id, await this.resolveChildEffort(request, run));`,
  `effortSource: "default"`, `resolvedEffort: null`.
- `dsh-workflow/lib/types/types.d.ts`: `resolvedEffort?: string | null;`,
  `effortSource?: 'pinned' | 'inherited' | 'default' | 'unknown';`.
- `dsh-llm`: `defaulted.reasoningEffort === "default" ? void 0 : defaulted.reasoningEffort`,
  the sentinel materialization, `reasoningEffort: "default"`.
- `dsh-llm-pi-ai` and `dsh-llm-deepseek`:
  `options.reasoningEffort === "default" ? void 0 : options.reasoningEffort`.

## Before/after check output

```
$ (pre-035) DSH_AGENT_BASE=/tmp/opencode/shadow035 bash bugs/035-.../scripts/check.sh
missing: const effortFields = (agent) => { (in lib)
missing: resolvedEffort: headerEffort ?? agent.resolvedEffort ?? null (in lib)
missing: ...effortFields(agent) (in lib)
missing: async resolveChildEffort(request, run) (in lib)
missing: this.childEfforts.set(run.id, await this.resolveChildEffort(request, run)); (in lib)
missing: effortSource: "default" (in lib)
missing: resolvedEffort: null (in lib)
missing: resolvedEffort?: string | null; (in types)
missing: effortSource?: 'pinned' | 'inherited' | 'default' | 'unknown'; (in types)
missing: defaulted.reasoningEffort === "default" ? void 0 : defaulted.reasoningEffort (in lib)
missing: else if (defaulted.reasoningEffort !== "default") resolvedConfig = { (in lib)
missing: reasoningEffort: "default" (in lib)
missing: options.reasoningEffort === "default" ? void 0 : options.reasoningEffort (in lib)
missing: options.reasoningEffort === "default" ? void 0 : options.reasoningEffort (in lib)
bug-035 fix MISSING
exit=1

$ (installed) bash bugs/035-.../scripts/check.sh
bug-035 fix PRESENT
exit=0
```

## Live probe (scratch `DSH_HOME`, real `~/.dsh` untouched)

`scripts/effort-probe.sh` runs one three-stage workflow through the shipped
headless profile: stage 1 pinned `opencode-go/longcat-2.0`, stage 2 pinned
`opencode-go/deepseek-v4-flash`, stage 3 with no route (inherits the lead's
`deepseek-v4.1-flash @ max`).

```
bug 035 live probe — scratch home /tmp/orch-drill-035/home

    | dsh: reasoning:
    | I need to route three sequential agent stages with specific provider and model configurations—stage 1 with opencode-go and longcat-2.0, stage 2 with opencode-go and deepseek-v4-flash, and stage 3 inheriting the default route.
    | EFFORT-PROBE-DONE
  PASS  the lead completed the workflow run

agent-start records:
  seq=1 label=stage-one requested=opencode-go/longcat-2.0 resolvedEffort='default' effortSource='default'
  seq=2 label=stage-two requested=opencode-go/deepseek-v4-flash resolvedEffort='default' effortSource='default'
  seq=3 label=stage-three requested=None/None resolvedEffort='max' effortSource='inherited'

child request headers:
  opencode-go/longcat-2.0 reasoningEffort='default'
  opencode-go/deepseek-v4-flash reasoningEffort='default'
  opencode-go/deepseek-v4.1-flash reasoningEffort='max'
  opencode-go/deepseek-v4.1-flash reasoningEffort='max'
  PASS  at least three agent-start records
  PASS  every agent-start record carries resolvedEffort + effortSource
  PASS  the route-inheriting stage records the lead's effort as inherited
  PASS  a route-changed stage records the adapter default
  PASS  every child request header carries a reasoningEffort key
  PASS  the longcat-2.0 pin shows a concrete value or the default marker

bug-035 live probe: PASS
scratch home kept for inspection: /tmp/orch-drill-035
```

Every `agent-start` record carries both fields; the inheriting stage proves the
`"inherited"` provenance with the lead's `max`; every child's `request/header`
carries a `reasoningEffort` key and `longcat-2.0` shows the explicit
`"default"` marker (v19's missing key is closed).

## Patch round-trip

```
forward apply (031->032->036->033->034->035) == installed bundle: OK
reverse apply (035->034->033->036->032->031) == pre-batch baseline: OK
ROUNDTRIP PASS
```

`scripts/reapply.sh` chains 024 (llm/pi-ai) and 028 (tool/worker/types) as
needed and is idempotent (verified twice on a shadow bundle).

## Verification limits (disclosed)

- `resolveChildEffort` resolves at creation; a stage that fails before its
  first request still records the resolved value (it cannot fail before
  creation). If the LLM registry is absent the record is
  `{null, "unknown"}` rather than omitted.
- The `"default"` sentinel is a header/record marker: both shipped adapters
  translate it to their own default, so wire requests are unchanged.
