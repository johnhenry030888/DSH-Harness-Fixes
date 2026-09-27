# Bug 041 — no harness patch by design

Bug 041's deliverable is **repo tooling**: `scripts/check-all.sh` now ends with
one machine-readable total:

```
TOTAL: <present> fixes present, <missing> missing
```

and exits non-zero when `missing > 0`. Nothing in the installed bundle needs to
change; the fix exists to stop drills reconciling a spec count against the
tool's per-fix lines by hand (drill v27 §0/§6 F1: the brief predicted "39 fixes
PRESENT" while the tool printed 37 ids and 77 assertion lines). The patch is
therefore empty; `scripts/check.sh` asserts the TOTAL line's presence and its
tally behaviour against a temp copy.
