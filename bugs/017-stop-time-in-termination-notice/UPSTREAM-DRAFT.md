# Upstream draft — bug 017

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `interrupt_agent` settlement notices carry no stop time: "work
stopped" and "notice sent" are indistinguishable

**Body:**

When a continuable subagent is stopped, the parent receives a settlement
notice whose entire timing content is the notice envelope:

```
Background subagent ee1df1eb-… was stopped before it finished.
Its closing message:
```

The message event's own `time` dates *delivery* (which happens at the
parent's next step/wake), not the stop. In a measured case the envelope was
**22.7 s** after the child's last write, so a verifier cannot tell when work
actually stopped without opening the child's transcript.

The observer already has the facts at capture time:

```js
capture: (child) => {
    const own = child.session.snapshotEvents(boundary);
    const output = finalAssistantOutput(own);
    captured = { stopReason: epochStopReason(own), ...output… };
}
```

Proposal: put them in the payload.

- `stopTime` — epoch ms at capture (the stop record); also used on the
  teardown-failure fallback.
- `lastActivityTime` — epoch ms of the child's last recorded session event in
  the settling epoch, when one exists.

Carry both on the `subagent/end` lifecycle payload and on the
`subagent-settled` notice `source` (numeric, durable), plus one text block
`Stop time: <ISO>; the child's last recorded activity: <ISO>.` beside the
existing sentence — the sentence itself is unchanged. Types
(`ActivationTerminal`, `SubagentRunEndInfo`, `SubagentSettledMessageSource`)
gain the optional fields.

Measured live after the change: `stopTime` = `1790414939218`,
`lastActivityTime` = `1790414939195` (the child's aborted `turn/end.time`
exactly), notice envelope `time` = `1790414961931`.
