# Upstream draft — bug 023

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** No mechanical guard for the verify→review ordering rule: a live
write-capable child can corrupt a concurrent read-only review's evidence

**Body:**

The orchestrator doctrine says "never overlap a destructive step with an
observation of the same tree" — verify must settle before review is
dispatched. Nothing in the harness enforces it, so it stays persona prose and
gets violated. Drill v10 dispatched `subagent_review` while
`subagent_verify` was still live; the verifier mutated the artifact in place
and the reviewer reported **3 failures that were really the verifier's
mutation**. Drill v11 repeated the scheduling mistake and was saved only
because the verifier happened to mutate a private copy.

Two facts already exist in the runtime but are never joined:

- every live Agent's status (`running` includes inside a long tool call);
- every child's resolved `sandbox/mode` fold — the one property that says
  whether it may still modify files (read-only delegation lanes write
  `sandbox/mode: read-only`; every other child carries the inherited policy
  pin).

Proposal:

1. `ctx.subagents.start()` / `startContinuable()` consult the live sibling
   registry before creating a `readOnly: true` child: if a direct child of the
   same parent is **running** and its resolved sandbox policy is not
   `read-only`, and its session cwd overlaps the parent's tree by path
   prefix, refuse with a structured `SubagentError` (`code:
   INSPECTION_CONFLICT`) naming the conflicting child id(s) and the tree, and
   tell the caller to wait for the settlement notice or
   `interrupt_agent`, then retry the unchanged call.
2. `list_agents` rows expose the same state: `filePolicy`
   (`read-only` / `writes`) and `tree`, so a caller can sequence before
   dispatch instead of discovering the conflict from a corrupted review.

A settled child holds no claim (the settlement notice is the handoff), a
write-capable spawn is never affected, and unrelated trees/workspaces are
untouched.
