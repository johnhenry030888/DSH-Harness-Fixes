# Upstream draft — bug 013

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** fork seed size is invisible to the child and the parent

**Body:**

`subagent_fork` seeds a child with the parent's completed turns, but nothing in
the child's descriptor, runtime context, or the parent's tool result says
whether the seed was empty. The only durable marker is a count-less
`session/end-seed {"inherited": true}` (or `{}`), which the model never sees.

Observed on 0.1.5-rc.2:

- mid-turn fork (parent inside its first turn): child descriptor has no seed
  field; the child must be asked to learn it started cold;
- second-turn fork: the seed is real (the child recalls facts from inherited
  context with zero tool calls), but the descriptor still carries no count.

Proposal:

1. add a numeric `inheritedEventCount` to `subagent/descriptor` (0 = cold,
   N = seeded), stamped by the in-process driver / continuation manager and
   validated on fold;
2. announce it in the child's runtime context (one line) and log it host-side in
   both directions;
3. keep the completed-turn contract wording.

Also worth documenting: a reply delivered through `ask_user_question` is a tool
result inside the current turn and creates no `turn/end`, so it cannot produce a
seeded fork — the "second turn" needs a genuine new user turn.
