# Versions — bug 003

- First seen broken: `@deepseek-ai/dsh` 0.1.1-rc.2 (installed bundle,
2026-09-07) with `@earendil-works/pi-ai` 0.85.0 (nested dep).
- Verified fixed-locally: patch applied to the installed bundle
2026-09-07 (`scripts/reapply.sh`: patch applied, `node --check` clean,
`scripts/check.sh` exit 0). Helper truth table 4/4 (see EVIDENCE.md).
- Fix markers checked by `scripts/check.sh`:
  - `opencodeSessionHeaders` in
    `dsh-llm-pi-ai/lib/index.js`
  - `x-opencode-session` in `dsh-llm-pi-ai/lib/index.js`
- Pristine sources for diffing: `npm pack
  @deepseek-ai/dsh-llm-pi-ai@0.1.1-rc.2` from the registry
  (tarball `deepseek-ai-dsh-llm-pi-ai-0.1.1-rc.2.tgz`, 19 files).
- After a `dsh` update: run `scripts/check.sh`. If MISSING, run
  `scripts/reapply.sh`; if the patch no longer applies, re-investigate (code
  moved?) or check whether upstream fixed it (mark UPSTREAMED in STATUS.md).
