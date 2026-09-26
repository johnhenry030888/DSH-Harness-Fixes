# Versions — bug 021

- First analyzed broken: `@deepseek-ai/dsh-sandbox-local` and
  `@deepseek-ai/dsh-sandbox` 0.1.5-rc.2 (installed bundle with fixes
  007–019 applied), from drill v10 §2 / friction #3.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - both patches apply to pristine published sources with no fuzz
    (`npm pack` sources, `diff -q` confirmed identical to the installed files
    before the fix);
  - `node --check` clean on both files;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice);
  - `scripts/sandbox-temp-check.mjs` PASS (bwrap/Landlock/Seatbelt argv and
    profile shapes);
  - live on a temporary `readOnly: true` headless row: pre-fix the bare
    pinned `python3 -m pytest --import-mode=importlib` failed with
    `No usable temporary directory found` (exit 1); post-fix it completed
    `3 passed` (exit 0) while the workspace shell append stayed refused; an
    unconstrained fork child still wrote its scratch file.
- Pristine sources: `npm pack @deepseek-ai/dsh-sandbox-local@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-sandbox@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `function tempWriteRoots()`, `const CONFINED_TEMP_DIR = "/tmp"`,
  `...tempWriteRoots()`, `policy.mode === "read-only" ? tempWriteRoots() :
  writableRoots(policy)`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 021 is MISSING,
  run `scripts/reapply.sh`; if a patch no longer applies, re-investigate or
  check whether upstream gave `read-only` a temp grant (then mark UPSTREAMED).
