# Versions — bug 041

- First analyzed broken: the repo's own `scripts/check-all.sh` as of batch 7
  (2026-09-27), from drill v27 §0/§6 F1 (spec count vs 37 id lines vs 77
  assertion lines).
- Verified fixed-locally (2026-09-28):
  - the real suite's last line is `TOTAL: 42 fixes present, 0 missing` with
    exit 0;
  - a temp copy of `scripts/check-all.sh` + `bugs/` with one `check.sh` forced
    to exit 1 reads `TOTAL: 41 fixes present, 1 missing` and exits 1; an
    all-stub control run reads `TOTAL: 42 fixes present, 0 missing` and exits 0;
  - `scripts/check.sh` exit 1 with the old tool (no TOTAL marker), exit 0 with
    the new one; `scripts/reapply.sh` idempotent.
- No bundle patch (`patches/00-no-bundle-change.md`).
- Fix markers (checked by `scripts/check.sh`, never the version):
  `TOTAL: $present fixes present, $missing missing`,
  `present=$((present + 1))`, `missing=$((missing + 1))`, `exit "$fail"`.
- After a `dsh` update nothing here needs re-applying (repo-side); run
  `scripts/check-all.sh` and quote its TOTAL line.
