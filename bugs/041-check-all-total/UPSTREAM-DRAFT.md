# Upstream draft — bug 041

Status: **NOT-FILED** (repo-side tooling only; no upstream code to patch.)

---

This one is not an upstream discussion candidate: `check-all.sh` is this
repo's own batch tool, not part of `@deepseek-ai/dsh`. Recording it here so
the batch convention (every bug folder carries an UPSTREAM-DRAFT) holds.

If a similar per-fix checker ships upstream, the same rule applies: print the
one authoritative total (`TOTAL: N fixes present, M missing`) and make the
exit status follow `M`, so consumers never count heterogeneous lines.
