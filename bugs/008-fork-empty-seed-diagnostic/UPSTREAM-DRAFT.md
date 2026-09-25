# UPSTREAM DRAFT — `subagent_fork` silently starts cold inside the parent's own turn

Status: NOT-FILED.

---

**Packages:** `@deepseek-ai/dsh-subagent-fork-in-process` 0.1.5-rc.2,
`@deepseek-ai/dsh-tool-subagent` 0.1.5-rc.2

## Summary

The fork provider seeds the child with `completedTurnPrefix(parent)` — events
through the last `turn/end` — and passes no seed (with no diagnostic) when the
parent has not completed a turn. The tool description says the child inherits
"all completed turns so far (it does not see the current in-flight turn)",
which reads as "this turn's earlier context is available". In a normal
one-turn orchestrator session the fork therefore starts cold and the lead
trusts a context that does not exist.

Drill v4 measured it: the lead session ran as one turn (`turn/start` seq 7, the
only `turn/end` seq 482), the fork fired at seq 66, and the child reported no
prior turns.

## Suggested fix (does not change the seeding rule)

1. Log a host warning when the prefix is empty, naming the parent session and
   stating that 0 events were inherited and what to do instead
   (`send_message` to a continuable child, or restate the context in the
   prompt).
2. Correct `providerWording(true)`: state that inheritance starts at the last
   completed turn, and that forking before the first turn completes (including
   from within the parent's current turn) gives the child no prior
   conversation.
3. Leave the durable descriptor alone. `Session.inheritedEventCount` already
   records the truth (0 / `isSeeded:false` for the empty case; > 0 with
   `session/end-seed` otherwise), and bumping
   `SUBAGENT_DESCRIPTOR_VERSION` for a non-composition fact would make existing
   v3 children unreadable on cold resume.

**Rejected:** seeding the in-flight turn (an unbalanced prefix is not a valid
child session — the module docstring already says so), and failing the fork on
an empty seed (a self-contained prompt makes a mid-turn fork legitimate).

## Local patch

`bugs/008-fork-empty-seed-diagnostic/` carries both patches, a
`seed-check.mjs` exercising the installed provider, and live evidence
(mid-turn fork child header `isSeeded:false`, no `session/end-seed`).
