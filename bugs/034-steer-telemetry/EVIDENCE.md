# Evidence — bug 034

## Primary evidence (pre-fix)

- Drill **v21 §4.3**: the steer split had to be reconstructed from the child's
  own log.
- Drill **v23 §5 item 5**: "no steer timestamp stamp" confirmed open; the
  boundary→reply half was not measurable.
- Drill **v25 §5 item 8**: total 50.044 s, steer→boundary 50.35 s,
  **boundary→reply −0.306 s** ("ordering anomaly; only the first segment is
  trustworthy"); §7 friction #8: "stamp the steer delivery in the child's own
  record."
- Drill **v26 §5 item 5**: "`send_message` returns only 'message delivered' —
  no delivery timestamp and no record id — so the steer split must be taken
  from the settlement notice (done: 14 s)."

## Fix markers (checked by `scripts/check.sh`)

- `dsh-subagent`: `function steerDeliveryRecord(messageId, target, senderSessionId, deliveredAt)`,
  the `subagent/steer` append, `steer: true,`.
- `dsh-agent-loop`: `function steerBoundaryRecord(message, boundaryAt, boundarySeq)`
  and the `subagent/steer-boundary` append inside `claim()`.
- `dsh-subagent/lib/types/types.d.ts`: `readonly deliveredAt?: string;`.
- `dsh-tool-subagent-control`: `deliveredAt: {` in the output schema and
  `message delivered to agent ${args.agent_id} — deliveredAt ${value.deliveredAt}`.

## Before/after check output

```
$ (pre-034: 033 applied) DSH_AGENT_BASE=/tmp/opencode/shadow034 bash bugs/034-.../scripts/check.sh
missing: function steerDeliveryRecord(messageId, target, senderSessionId, deliveredAt) (in lib)
missing: activation.handle.agent.session.append("subagent/steer", steerDeliveryRecord(messageId, activation.childId, parent.id, deliveredAt)); (in lib)
missing: steer: true, (in lib)
missing: function steerBoundaryRecord(message, boundaryAt, boundarySeq) (in lib)
missing: this.session.append("subagent/steer-boundary", steerBoundaryRecord(message, new Date().toISOString(), this.session.seq)); (in lib)
missing: readonly deliveredAt?: string; (in types)
missing: deliveredAt: { (in lib)
missing: message delivered to agent ${args.agent_id} — deliveredAt ${value.deliveredAt} (in lib)
missing: const deliveredAt = new Date().toISOString(); (in lib)
missing: deliveredAt (in lib)
bug-034 fix MISSING
exit=1

$ (installed) bash bugs/034-.../scripts/check.sh
bug-034 fix PRESENT
exit=0
```

## Module-level behavioural probe (fake clock)

`scripts/steer-check.mjs` extracts the installed `claim()` method and the two
record builders, binds `claim` to a fake inbox, and advances a fake clock by
250 ms between delivery and boundary. Pre-fix the extraction fails because
neither builder exists (the pre-034 bundle is
`/tmp/opencode/shadow034`, 033 applied).

```
$ node bugs/034-steer-telemetry/scripts/steer-check.mjs /tmp/opencode/shadow034/dsh-agent-loop/lib/index.js /tmp/opencode/shadow034/dsh-subagent/lib/index.js   # pre-034 (033 applied)
FAIL: function steerBoundaryRecord(message, boundaryAt, boundarySeq) { is not present in /tmp/opencode/shadow034/dsh-agent-loop/lib/index.js
exit=1

$ node bugs/034-steer-telemetry/scripts/steer-check.mjs   # installed
ok: 1: the steer message is claimed
ok: 1: a boundary record is appended
ok: 1: deliveredAt <= boundaryAt, both ISO millisecond stamps
ok: 1: the boundary seq is recorded
ok: 1: the message id is recorded
ok: 2: non-steer messages are not stamped
ok: 3: a steer without deliveredAt still records boundaryAt + boundarySeq
ok: 4: the child's subagent/steer record carries deliveredAt/target/messageId
STEER-CHECK PASS
exit=0
```

## Live probe (scratch `DSH_HOME`, real `~/.dsh` untouched)

`scripts/steer-probe.sh` starts a continuable child told to `sleep 60`, steers
it, and waits for the child to settle. The transcript shows all three values
and the ordered triple. (The second `send_message` result in the output is the
child's own message to its parent — also delivered through `send_message` —
which the pairing logic correctly ignores.)

```
bug 034 live probe — scratch home /tmp/orch-drill-034/home

    | The whole final reply should be that verbatim text, then STEER-PROBE-DONE.
    | message delivered to agent c66303c3-47ff-4c6f-b77a-5641e2113cfc — deliveredAt 2026-09-27T20:53:43.297Z
    | 
    | STEER-PROBE-DONE

  send_message results: ['message delivered to agent c66303c3-47ff-4c6f-b77a-5641e2113cfc — deliveredAt 2026-09-27T20:53:43.297Z', 'message delivered to agent session-87b08f38-813d-41aa-b2d3-d4c315b9147c — deliveredAt 2026-09-27T20:53:49.413Z']
  subagent/steer:       [{'messageId': 'af23d880-178a-447b-bfcd-29e97922ea48', 'target': 'c66303c3-47ff-4c6f-b77a-5641e2113cfc', 'senderSessionId': 'session-87b08f38-813d-41aa-b2d3-d4c315b9147c', 'deliveredAt': '2026-09-27T20:53:43.297Z'}]
  steer-boundaries:     [{'messageId': 'af23d880-178a-447b-bfcd-29e97922ea48', 'deliveredAt': '2026-09-27T20:53:43.297Z', 'boundaryAt': '2026-09-27T20:53:43.435Z', 'boundarySeq': 24}]
  PASS  the send_message result carries deliveredAt
  PASS  the child records subagent/steer with deliveredAt/target/messageId
  PASS  the child stamps subagent/steer-boundary with boundaryAt/boundarySeq
  PASS  a delivery pairs with its child record and an ordered boundary/reply
  ordered triple: deliveredAt=2026-09-27T20:53:43.297Z boundaryAt=2026-09-27T20:53:43.435Z reply=1790542429370

bug-034 live probe: PASS
scratch home kept for inspection: /tmp/orch-drill-034
```

## Patch round-trip

```
forward apply (031->032->036->033->034->035) == installed bundle: OK
reverse apply (035->034->033->036->032->031) == pre-batch baseline: OK
ROUNDTRIP PASS
```

`scripts/reapply.sh` chains 033 and 030 as needed and is idempotent (verified
twice on a shadow bundle).

## Verification limit (disclosed)

The first live run showed the race the probe now controls for: if the steer
arrives before the child's first step, it queues instead of cancelling, and the
boundary lands after the sleep. The probe delays the steer by one `list_agents`
call so the in-flight cancellation path (fix 030) is exercised; the ordering
assertion holds either way.
