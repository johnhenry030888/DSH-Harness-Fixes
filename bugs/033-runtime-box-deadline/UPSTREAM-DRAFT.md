# Upstream draft — bug 033

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** No runtime-enforced delegation deadline: overrunning lanes return
nothing and lose their partial work

**Body:**

Delegation boxes are prompt discipline only. Drill v23's verify lane ran a
300 s box to ~600 s, wrote `SELF_ABORT`, and executed **0 of 19 mutants**.
Drill v24 had three lanes overrun 2×/1.6×/1.8×; two were interrupted and two
returned nothing — while the one lane whose job ran inside a deadline-checked
loop finished 19 mutants in 13 s. Drill v26 lost an entire mutation sweep and
the whole token/share/measurement bundle to two lanes that produced **no
artifact at all** after 662 s and 323 s.

Nothing in the runtime accepts a deadline or reports a partial result when one
is exceeded. Proposal:

1. Accept `boxSeconds` (whole seconds, ≥ 5) on a `tool-subagent` row and per
   call; unset keeps today's behaviour.
2. On expiry, durably append `subagent/box {boxSeconds, elapsedSeconds,
   hit: true}` to the child, interrupt it exactly the way `interrupt_agent`
   does, and return the box hit with the child's last assistant text as a
   partial result — `agent "<id>" hit its <n> s box and was interrupted after
   <m> s; partial output follows: …`.
3. The settlement notice for a background child says the stop was a box hit,
   not a completion, and carries the same `box` field.

Independent of `maxDepth`/`toolFilter`; the box reuses the existing interrupt
semantics rather than adding a second stop path.
