# Bug 041 — `check-all.sh` prints one authoritative total

Severity: **low** (reporting friction, but it burned a lead call reconciling
three numbers by hand). Deliverable: repo tooling, **no harness patch**.
Upstream: **NOT-FILED**.

## Symptoms

Drill **v27 §0/§6 F1** (verbatim): "the drill brief predicted '39 fixes
PRESENT' while the tool printed 37 ids and 77 assertion lines, and the lead
spent a call reconciling the three numbers by hand ('reported as a
spec-vs-tool count mismatch')". The three numbers were: bug folders (one
`[name] fix PRESENT` id line each), individual marker assertions (`fix
PRESENT` lines emitted by each bug's own `check.sh`), and the brief's count.

## Root cause

`scripts/check-all.sh` printed only the per-fix id lines and exited with the
aggregate status; it never printed a count, so every consumer had to count
lines whose meaning differed (bug ids vs assertion markers).

## Fix design

`scripts/check-all.sh`:

1. Tally `present`/`missing` once per bug folder (a missing or non-executable
   `check.sh` counts as missing, preserving the old fail behaviour).
2. Emit the final line exactly as
   `TOTAL: <present> fixes present, <missing> missing`.
3. Keep every per-fix line and the exit convention (`exit 0` only when
   `missing == 0`).

`scripts/check.sh` for this bug:

- greps the TOTAL-line printf and both tally increments in
  `scripts/check-all.sh`;
- copies the real `check-all.sh` and `bugs/` tree to a temp root, replaces
  every copied `check.sh` with a deterministic stub, forces exactly one to
  `exit 1`, and asserts the tool reads `TOTAL: N-1 fixes present, 1 missing`
  and exits non-zero (and that the all-stub run reads `N fixes present,
  0 missing`). The real suite is never touched and `check-all.sh` never
  recurses into its own check.

## Rejected alternatives

- **Drop the per-fix lines and print only the total.** Drills cite the id
  lines as evidence of *which* fixes are present; only the count was missing.
- **Count bug directories at the top (`ls bugs | wc -l`).** Counts directories
  that have no check at all, which is exactly the stale-tree case the tool
  must expose as missing.
- **Make `check.sh` parse `check-all.sh`'s output of the real suite.** Recursion
  (041's own check runs inside check-all) and it would mutilate the suite to
  test the failure path; the temp copy tests the same code path in isolation.

## Acceptance evidence

`EVIDENCE.md`: the new final line and exit code on the real suite
(`TOTAL: 42 fixes present, 0 missing`, exit 0), the forced-broken temp copy
(`TOTAL: 41 fixes present, 1 missing`, exit 1), and the pre-fix tool's tail
(no TOTAL line).
