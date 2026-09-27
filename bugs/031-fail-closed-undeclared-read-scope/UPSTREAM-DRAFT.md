# Upstream draft — bug 031

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** The inspection-ordering guard is bypassable by omission: an
undeclared read scope is admitted while write-capable children are live

**Body:**

The 023/026 ordering guard refuses a read-only delegation while a
write-capable sibling is still running against an overlapping declared tree.
Its reader-scope derivation, however, falls back to the parent session cwd
when the delegation prompt declares no paths — and then compares only that cwd
against each writer's declared work. "No declared scope" therefore means "the
parent cwd only", not "the whole workspace", and a caller disables the guard
by naming nothing.

Reproduced twice: drill v25 §5 probe 1 (admitted with four writers live,
while the identical declared call was refused) and drill v26 §5 item 3
(`G1 returned normally`; Appendix A reproduces both sides). Every drill since
v18 has also had to reconstruct the rule from prose because the refusal never
stated which basis it used.

Proposal:

1. Treat an undeclared read scope as **maximal**: refuse while any
   write-capable direct child of the same parent is live, regardless of
   declared trees, with a refusal that says so explicitly and keeps the
   existing retry guidance.
2. Append a durable `subagent/inspection-scope` record to the parent session
   carrying `scopeBasis: "declared" | "maximal"`, `outcome`, the declared
   `readTrees`, and the conflicting writer ids/paths, so the rule that fired is
   machine-readable after the fact.
3. Leave declared scopes exactly as 023/026 defined them: overlap is computed
   on declared paths and a disjoint reader is admitted.
