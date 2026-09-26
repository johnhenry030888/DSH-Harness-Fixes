# Upstream draft — bug 018

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** a filtered child keeps the parent's system prompt and is never told
which tools its layer removed

**Body:**

A fork/worker child joins the parent's preset, so it inherits the parent's
system prompt — including an orchestrator lead's lane map that tells it to use
`subagent_fork`, `list_agents`, and the goal tools — while its live catalog is
the filtered leaf set. The only layer-level text is the trailing
`You are a delegated subagent: your permission scope was fixed …`, which says
nothing about identity or removed tools.

Consequences observed on 0.1.5-rc.2:

- a seeded second-turn fork inherited the full lead context and
  **self-identified as the orchestrator lead**, re-running the drill until the
  filter denied every call;
- a child asked which tools it lacked could only report *absence* (the
  `unknown tool` error class is model-dependent), not a recorded denial;
- one-shot fork/worker descriptors carried no `toolFilter` (only continuable
  descriptors did), so the applied filter was unauditable from the record.

Proposal:

1. a leading runtime-context banner (`subagent:layer`) naming the parent session
   and the tools the filter removed (or the effective allow set), plus "you are
   a continuation/subagent, not the lead";
2. record `toolFilter` on one-shot descriptors too;
3. where feasible, give a fork layer a child-appropriate prompt instead of the
   parent's.

We ship 1+2 locally; 3 is recorded as the larger follow-up.
