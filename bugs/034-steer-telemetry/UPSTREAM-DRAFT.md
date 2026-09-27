# Upstream draft — bug 034

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** Steer delivery has no timestamps: the deliveredAt → boundary →
reply split is unmeasurable (and once measured negative)

**Body:**

`send_message` confirms only "message delivered to agent …"; the child records
nothing at admission, and the step boundary where the steer is adopted records
nothing. Every drill since v18 has had to reconstruct the steer split from the
child's own log or give up: v25 measured the total (50.044 s) but got
**boundary→reply = −0.306 s** because the child's message timestamp precedes
its `step/start`; v26 could only report the 14 s total. The split is the one
number that separates harness latency from lane latency, which is exactly what
the drills need to judge a slow steer.

Proposal:

1. `send_message` returns/renders `deliveredAt` (ISO 8601, ms precision) and
   passes it through to the service.
2. The child gets a durable `subagent/steer {messageId, target,
   senderSessionId, deliveredAt}` at admission.
3. The inbox claim that consumes a steer at a step boundary appends
   `subagent/steer-boundary {messageId, deliveredAt, boundaryAt, boundarySeq}`,
   so `deliveredAt <= boundaryAt <= reply` is derivable from the transcript
   without cooperation from the child model.
4. Delivery semantics, the 030 cancel-then-replan behaviour, and the existing
   confirmation wording are unchanged (the stamp is appended).
