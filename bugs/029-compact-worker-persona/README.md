# Bug 029 — child layers inherit the lead's full persona (20,414 chars, lane map included)

Severity: **medium** (per-child token cost on every request + the seeded-fork
impersonation hazard). Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

Drill v12 measured a child's inherited system prompt at **20,414 characters**,
including the whole ORCHESTRATOR lane map (the deployment persona suffix). Every
child — workers, workflow agents, forks — pays that prompt cost on every
request, and the lane map tells them to use tools their filter removed. The v8
seeded-fork impersonation hazard is a direct consequence: a fork child reads
instructions meant for the lead and acts on them.

## Root cause

`applyChildComposition()` joins the parent's preset (which composes the
deployment persona) and only shadows `deployment:persona-prefix` when the
delegation row sets its own `persona`. Two gaps:

1. a row persona never suppressed the parent's **suffix**, so the whole lane
   map still composed for that child;
2. a row without a persona (every row in the shipped Orchestrator preset)
   shadowed nothing at all — the child inherited the lead's identity verbatim.

## Fix design

Child composition now installs a compact worker persona for every child:

- `deployment:persona-prefix` is the row's own `persona` when one is set,
  otherwise a short worker statement naming role, parent, filter contract and
  return contract (~520 chars);
- `deployment:persona-suffix` is shadowed with `""`, so the parent's persona
  suffix (the lane map) never reaches a child — including when the row sets
  its own persona, matching the existing per-child-persona documentation
  ("SHADOWING the deployment's persona for this child alone") which the prefix
  alone never fulfilled;
- the lead's own composition is untouched (only child creation calls
  `applyChildComposition`), and the fix-018 `subagent:layer` banner (with the
  027 count) remains the identity contract.

## Rejected alternatives

- **Trim the lane map out of the parent's suffix only.** Requires the persona
  row to know what "orchestration prose" is; the same suffix is correct for
  the lead and no string edit can preserve its meaning while cutting tokens
  safely.
- **Suppress persona sections by name in `dsh-system-prompt` for every child.**
  Puts delegation policy in the prompt registry, which must not know which
  scope is a child; the child composition window is the seam that owns this.
- **Rely on the 018 banner alone (say "ignore inherited instructions").**
  Keeps the 20k tokens; the drill's fork hazard shows saying "ignore it" is not
  a control.
- **A per-row persona in the preset.** Deployment-owned config the harness
  does not control; the default must be safe without preset edits.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-worker-persona.patch`; stacks on bugs
  007/013/017/018/019/023/026/027/028 of the same file)

## Acceptance evidence

See `EVIDENCE.md`. Live: a direct child, a workflow worker and a fork child
each show a system prompt far under half the lead's character count, still
identify as delegated child layers (banner), and return usable work; the lead's
own prompt is byte-identical before and after.
