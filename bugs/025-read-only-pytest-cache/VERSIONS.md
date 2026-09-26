# Versions — bug 025

- First analyzed broken: `@deepseek-ai/dsh-tool-bash` 0.1.5-rc.2 (installed
  bundle with fixes 001–024 applied), from drill v10 §2 / v11 §2 and the
  optimization plan §22.3 residual 4.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - the patch applies to pristine published sources with no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice); the shadow-bundle round trip is byte-identical;
  - live on a temporary read-only headless row: the bare pinned
    `python3 -m pytest --import-mode=importlib` exited 0 with `3 passed` and
    **no** `PytestCacheWarning`, `PYTEST_ADDOPTS=-p no:cacheprovider`, the
    workspace write probe still refused; the write-capable lane ran the same
    command with an empty `PYTEST_ADDOPTS` and a successful write.
- Pristine source: `npm pack @deepseek-ai/dsh-tool-bash@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `function readOnlyPytestAddopts(ambient)`,
  `policy?.mode === "read-only" ? { env: { PYTEST_ADDOPTS: … } }`, and the
  description sentence.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 025 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream injected the flag itself (then mark UPSTREAMED).
