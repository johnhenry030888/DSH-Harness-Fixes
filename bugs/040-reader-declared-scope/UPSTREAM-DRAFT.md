# Upstream draft — bug 040

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** The ordering guard drops a reader's declared scratch scope as an
"incidental mention" and then refuses the delegation as undeclared

**Body:**

After fixing the declared-path overlap (032), the incidental-mention filter is
still applied to **both** sides of the ordering guard. On the writer side that
is correct — a writer whose prompt only mentions `/tmp` and
`/tmp/v26_tstart` as a timestamp sentinel must not be treated as declaring work
there (drill v26 Appendix A3). On the reader side it erases a genuine
declaration:

```
Read only the /tmp scratch area.
Your read scope is declared as: /tmp/
Check whether the file /tmp/dsh-v27-sentinel.txt exists right now …
```

The context around `/tmp` contains the words "scratch" and "sentinel", so the
harvest returns `[]`; fail-closed 031 then refuses the delegation as
maximally scoped while any writer is live (drill v27 §6 F2). `/tmp` is exactly
where the sandbox puts a lane's own scratch, so this is the common case, not
an edge case.

Proposal:

1. Give an **explicit read-scope cue** precedence on the reader side
   (`read scope:`, `only read`, `read only`, `scope:`, `reads from`, `limited
   to`): from the cue onward, paths are declared whatever words surround them.
   Do not weaken the writer-side filter.
2. Treat scratch roots like any other declarable root: reader `/tmp/x` vs live
   writer `/tmp/x` refuses naming the pair; disjoint is admitted.
3. When a reader's harvest yields nothing but mentions were filtered, name the
   dropped paths in the refusal (and on the durable `subagent/inspection-scope`
   record) instead of the bare "declared no read scope" message.
4. Keep the fail-closed maximal default for a genuinely empty declaration.

Evidence: reproduced pre-fix in a module probe (declared `/tmp` scope →
`scopeBasis: maximal` refusal) and post-fix live (declared `/tmp` scope
admitted while a writer is live; overlapping declaration refused naming the
pair; same call admitted after settlement), with the v26 A3 writer case still
admitted. The failure cost drill v27 a whole acceptance row.
