# Evidence — bug 041

Repo tooling only: `scripts/check-all.sh` (see
`patches/00-no-bundle-change.md`).

## Primary evidence (pre-fix)

Drill **v27 §0/§6 F1** (verbatim): "the drill brief predicted '39 fixes
PRESENT' while the tool printed 37 ids and 77 assertion lines, and the lead
spent a call reconciling the three numbers by hand".

Pre-fix tool tail (from `git show HEAD:scripts/check-all.sh`) — no count line:

```
  fi
done
exit "$fail"
```

## Acceptance 1 — the real suite ends with one total

```
$ ./scripts/check-all.sh
... (per-fix id lines)
TOTAL: 42 fixes present, 0 missing
EXIT=0
```

Last three lines verbatim:

```
[041-check-all-total] fix PRESENT
TOTAL: 42 fixes present, 0 missing
EXIT=0
```

## Acceptance 2 — a deliberately broken check in a temp copy

Temp root: real `scripts/check-all.sh` + a copy of the real `bugs/` tree, every
copied `check.sh` stubbed to `exit 0` except `001-ask-during-goal-rounds`
(forced `exit 1`):

```
$ bash $TMP/scripts/check-all.sh
... (per-fix id lines)
[040-reader-declared-scope] fix PRESENT
[041-check-all-total] fix PRESENT
TOTAL: 41 fixes present, 1 missing
EXIT=1
```

The count drops to 41 present / 1 missing and the tool exits 1. The real tree
was never modified.

## Fix markers (checked by `scripts/check.sh`)

- `TOTAL: $present fixes present, $missing missing` (the printf);
- `present=$((present + 1))`, `missing=$((missing + 1))`, `exit "$fail"`;
- the temp-copy tally probe above.
