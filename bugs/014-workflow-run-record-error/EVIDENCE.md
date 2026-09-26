# Evidence — bug 014

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v6.md` §7 and §9 friction #4: three route
  rejections left `tool-workflow/agent-end {"outcome":"failed"}` with no error
  text and no child session dir.
- `~/Desktop/orchestrator-drill-report-v7.md` §7 (run
  `8083071f-f893-42cd-b404-7c15adc3401c`): `agent-start` has no provider/model,
  `agent-end` is `{"seq":1,"outcome":"failed"}`, and the rejection text appears
  in neither the run record nor the child session.
- `~/Desktop/orchestrator-drill-report-v8.md` §7 (run `499f0232…`): identical
  bare record; `agent()` resolved a bare `null`.
- Source: child `91e94c89`'s own `turn/end` already carried
  `{"reason":{"kind":"error","error":{"message":"pi-ai provider \"opencode-go\"
  has no configured model \"glm-5.3-flash\"","code":"UNKNOWN_MODEL"}}}` — the
  text existed and was dropped on the way to the record.

## Fix markers (checked by `scripts/check.sh`)

- `function turnDiagnostic(` + `...diagnostic === void 0 ? {} : { diagnostic },`
  in the in-process driver;
- `...result.diagnostic !== void 0 ? { diagnostic: result.diagnostic } : {},` in
  the worker-thread host;
- `requestedProvider: opts.provider`, `requestedModel: opts.model`,
  `error: result.diagnostic ??` in `worker.cjs`;
- `agent.error === void 0 ? {} : { error: agent.error }` and the requested-route
  spreads in `dsh-tool-workflow`;
- `requestedProvider?: string;` + `on host-synthesized cancellations` in
  `dsh-workflow/lib/types/types.d.ts`.

## Live re-verification (2026-09-26, installed bundle)

Session `session-bddb308e-68e1-4ef3-ad74-4aeb3fd14d75` (orchestrator), turn 4:
one `workflow` call (`meta.name: "reject-pin-v9"`) whose only `agent()` pinned
`provider: opencode-go, model: glm-5.3-flash`. Run
`7500cc87-2e99-4db6-a53f-7793a98ca30e`, transcript events seq 64–69:

```
tool-workflow/run-start   {"runId":"7500cc87…","name":"reject-pin-v9"}
tool-workflow/agent-start {"runId":"7500cc87…","seq":1,"label":"reject-pin","phase":"reject",
                           "childId":"aee7763e-9e63-40f3-80b9-2abcf4358522",
                           "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
tool-workflow/agent-end   {"runId":"7500cc87…","seq":1,"outcome":"failed",
                           "error":"pi-ai provider \"opencode-go\" has no configured model \"glm-5.3-flash\" (UNKNOWN_MODEL)",
                           "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
tool-workflow/run-end     {"runId":"7500cc87…","stopReason":"completed"}
```

The rejection text and the requested route are both in the run record; the error
string is the child's own turn-end failure rendered with its code. The workflow
tool result still returns `{"caught":null,"resolvedValue":null,"wasBareNull":true}`
for the script (documented `agent()` contract; see README "Rejected
alternatives").

## Commands

```bash
zstd -dc ~/.dsh/sessions/--home-john-Documents-Projects-DSH--/session-bddb308e-68e1-4ef3-ad74-4aeb3fd14d75/session.v3.jsonl.zstd \
  | python3 -c "import sys,json
for l in sys.stdin:
    d=json.loads(l)
    if d.get('type','').startswith('tool-workflow/'): print(d['type'], json.dumps(d['data']))"
```
