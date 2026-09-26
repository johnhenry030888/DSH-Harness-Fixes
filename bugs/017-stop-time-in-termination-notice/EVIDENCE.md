# Evidence — bug 017

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v9.md` §9 #2 and
  `~/Desktop/orchestrator-drill-report-v10.md` §8 (Phase 8 — kill) / §10
  friction #6: the notice text is only
  `Background subagent 28a4341b-… was stopped before it finished.` with no
  `stopTime`; v10 measured a ~7.35 s stop tail from the child's own last
  session write and recorded `notice_has_stop_time: false`.
- Source: `createActivationObserver.capture()` kept `{stopReason, output}`;
  `createSettlementMessage()` built the notice from those two fields only.

## Fix markers (checked by `scripts/check.sh`)

- `dsh-subagent/lib/index.js`: `const lastActivityTime = own.at(-1)?.time;`,
  `stopTime: Date.now(),`, both spread guards, and the notice text marker
  `Stop time: ${new Date(stopTime).toISOString()}`.
- Types: `readonly stopTime?: number;` in `types.d.ts` and `lifecycle.d.ts`,
  `readonly lastActivityTime?: number;` in `types.d.ts` and
  `continuation-messages.d.ts`.

## Live verification (2026-09-26, installed bundle, headless profile)

Probe: the lead spawns the generic continuable `subagent` (prompt: touch
`.p17-started`, then `sleep 120`), waits 15 s (the marker file existed), calls
`interrupt_agent` with the child id, waits 20 s, then quotes the notice.

- Lead session `session-56478b3d-4a05-4a1a-a257-0c419581f040`
- Child session `ce1df1eb-ee1e-4c65-8127-c6889d173a02`

Durable notice event (decoded from the lead transcript):

```
EVENT seq=45 time=1790414961931
SOURCE {"kind": "subagent-settled", "form": "notice",
        "summary": "Background subagent ce1df1eb-ee1e-4c65-8127-c6889d173a02 was stopped before it finished.",
        "senderSessionId": "ce1df1eb-ee1e-4c65-8127-c6889d173a02",
        "stopTime": 1790414939218, "lastActivityTime": 1790414939195}
CONTENT [{"type":"text","text":"Background subagent ce1df1eb-… was stopped before it finished."},
         {"type":"text","text":"Stop time: 2026-09-26T09:28:59.218Z; the child's last recorded activity: 2026-09-26T09:28:59.195Z."},
         {"type":"text","text":"Its closing message:"},
         {"type":"reasoning","text":"Now run the second command and let it finish. `sleep 120 ;` …"},
         {"type":"tool-call","id":"call_…","name":"bash","arguments":"{\"command\":\"sleep 120 ;\",…}"}]
DELTA_MS 23
```

Child's own final event (its transcript):

```
LAST_EVENT type=turn/end seq=24 time=1790414939195
TURN_END (24, 1790414939195, '{"turn": 1, "reason": {"kind": "aborted", "reason": {"kind": "parent"}}}')
```

Conclusions:

- `lastActivityTime` equals the child's own last write (its aborted
  `turn/end`) byte-for-byte: `1790414939195`.
- `stopTime` (`1790414939218`) is 23 ms later — the teardown capture moment,
  inside the cancellation window.
- The notice event's envelope `time` (`1790414961931`) is 22.7 s later
  (the lead's `sleep 20` plus delivery), which is the conflation the fix
  removes.
- The lead model quoted the new text line verbatim when asked for the notice.

## Commands

```bash
S=~/.dsh/sessions/--home-john-Documents-DSH-Harness-Fixes-.p21-live-suite--
zstd -dc $S/session-56478b3d-4a05-4a1a-a257-0c419581f040/session.v3.jsonl.zstd \
  | grep -o '"kind": "subagent-settled"[^}]*}'
zstd -dc $S/ce1df1eb-ee1e-4c65-8127-c6889d173a02/session.v3.jsonl.zstd \
  | tail -1
```

The probe ran on the plain headless profile with the temporary bug-021 row
overlay (irrelevant to the interrupt path); the child was the unconstrained
generic `subagent`.
