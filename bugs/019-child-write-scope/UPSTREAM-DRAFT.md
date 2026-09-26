# Upstream draft — bug 019

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** delegation rows have no structural write scope — a child can modify
lead-owned files

**Body:**

A `toolFilter` removes a child's orchestration tools but nothing constrains its
file writes. A fork child told "Write no files" made 7 `edit` calls on a
lead-owned report plus a `bash` python rewrite of an evidence JSON, then
`present`; the changes mixed verified facts with wrong numbers. File ownership
is prompt-only.

Proposal (smallest useful step): an optional per-row `readOnly: true` on a
`tool-subagent` row that

- installs a child-scoped tool guard refusing `edit`/`write`/`present` with the
  child id, the tool, and the target path, fail-closed (`allowed write paths:
  none`);
- pins the child's file policy to `read-only` (a `sandbox/mode` override with
  `source: delegation`), so shell mutations are refused by the kernel rather
  than by prompt;
- is recorded on the descriptor so a cold resume re-applies it.

Larger follow-up: `writeScope`/`pathScope` globs relative to the workspace,
enforced across bash and the fs tools — the current sandbox modes are whole-mode
with one workspace root, so that needs a new enforcement dialect.
