# Bug 008 — `subagent_fork` silently starts cold inside the parent's own turn

Severity: **medium**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

A fork child reports it has no prior turns; a positive-control probe could not
recall a fact the parent established earlier in the same turn, while the tool
description implies inherited conversation — so the lead trusts a context that
does not exist.

- Drill v4 §7 (Phase 5): child `5bcc100a-ee86-4f18-a351-bf7426af0cb6` reported
  its context began with the task prompt and nothing else; it reconstructed
  the fix from the docstring. "Did inherited history help? Honestly: no."
- Drill v4 §4/§14.2: the lead session
  `session-7f17108c-46ab-4bdf-b19b-3e0b5df2dd77` ran as **one turn**
  (`turn/start` seq 7, the only `turn/end` seq 482) and the fork call fired at
  **seq 66** — the seed was empty by construction.

## Root cause

`@deepseek-ai/dsh-subagent-fork-in-process/lib/index.js`:

- `completedTurnPrefix(parent)` returns `[]` when the parent's log has no
  `turn/end`;
- `start()`/`prepareContinuable()` then pass no `seed` and emit **no
  diagnostic**, so the caller sees an ordinary successful fork;
- `providerWording()` in `@deepseek-ai/dsh-tool-subagent` described the fork as
  "seeded with all completed turns so far (it does not see the current
  in-flight turn)", which a lead reasonably reads as "this turn's earlier
  context is available".

The child session already records the truth durably: `inheritedEventCount`
(`Session`) is the seed length — `0` for an unseeded start, and
`header.isSeeded` is false. Nothing surfaced it.

## Fix design

1. **Diagnostic on the seed decision** (`dsh-subagent-fork-in-process`): the
   provider holds the host logger; `reportSeed(parent, inheritedEventCount)`
   logs a warning when the prefix is empty, naming the parent session id and
   stating that no conversation was inherited and what to do instead
   (`send_message`, or restate the context). Non-empty seeds log nothing.
   `inheritedEventCount` on the child session remains the durable record
   (0 / `isSeeded:false` for the empty case; > 0 with `session/end-seed` for
   the seeded case).
2. **Correct the tool description** (`dsh-tool-subagent.providerWording`):
   state the completed-turn contract explicitly — the seed ends at the last
   `turn/end`; forking while still inside the first turn gives the child **no**
   prior conversation; put the facts in the prompt or continue an existing
   child with `send_message`.
3. **Do not change the seeding rule.** The module docstring's reasoning stands:
   the current tool-call turn is unbalanced and cannot be replayed as a valid
   child session.

## Rejected alternatives

- **Seed the in-flight turn.** Rejected: an unbalanced prefix is not a valid
  child session (no `turn/end`; the child would inherit a dangling tool-call
  frame). The module docstring already records this.
- **Extend the durable `subagent/descriptor` with `inheritedEventCount`.**
  Rejected: `SUBAGENT_DESCRIPTOR_VERSION` is strict and bumping it makes
  existing v3 children unreadable on cold resume; the seed count is not child
  composition, it is derivable from the child's own session
  (`inheritedEventCount`, `isSeeded`, `session/end-seed`). Not cheap, so the
  warning + description carry the signal instead.
- **Make the fork provider fail on an empty seed.** Rejected: a mid-turn fork
  is legitimate when the prompt is self-contained; failing would break the
  one-shot fork lane. A warning plus honest wording keeps it usable.
- **Surface the count only in the child's first result.** Rejected: the result
  is the child's answer, not host metadata; corrupting it would misreport the
  child's output. The host warning is the right channel.

## Files patched

- `@deepseek-ai/dsh-subagent-fork-in-process/lib/index.js`
  (`patches/dsh-subagent-fork-in-process-seed-diagnostic.patch`)
- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-fork-wording.patch`, stacks on bug 007)

## Acceptance evidence

- `scripts/check.sh` exit 1 before, 0 after; `reapply.sh` idempotent (re-applies
  bug 007 first when needed); stacked dry-run clean.
- `scripts/seed-check.mjs` (installed bundle): a parent with no completed turn
  → no seed, warning names the parent session and `inherits 0 events`; a
  parent with a completed turn → 4-event seed, no warning.
- Live headless mid-turn fork: the child session header records
  `isSeeded: false` and its log has no `session/end-seed` event (the durable
  `inheritedEventCount: 0`), and the fork child had no inherited fact (it read
  the file it was pointed at).
