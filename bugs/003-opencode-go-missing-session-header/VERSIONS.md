# Versions — bug 003

- First seen broken: `@deepseek-ai/dsh` 0.1.1-rc.2 (installed bundle,
2026-09-07) with `@earendil-works/pi-ai` 0.85.0 (nested dep).
- Verified fixed-locally on 0.1.1-rc.2: patch applied to the installed bundle
2026-09-07 (`scripts/reapply.sh`: patch applied, `node --check` clean,
`scripts/check.sh` exit 0). Helper truth table 4/4 (see EVIDENCE.md).
- Re-verified and re-applied to `0.1.5-rc.2` (2026-09-20) with
`@earendil-works/pi-ai` 0.85.1. The second hunk's old context no longer
matched (the `streamSimple` call site gained `options.signal, model.id`
arguments), so the patch was regenerated against pristine
`@deepseek-ai/dsh-llm-pi-ai@0.1.5-rc.2`. The fix itself is unchanged and
still required: pi-ai 0.85.1 still never emits `x-opencode-session`, and the
`opencode-go` catalog still marks `openai-responses` models
`"sessionAffinityFormat": "openai-nosession"`. The regenerated patch applies
with no fuzz, `node --check` is clean, and a pristine->reapply round-trip
reproduces the fixed bytes exactly.
- Fix markers checked by `scripts/check.sh`:
  - `opencodeSessionHeaders` in
    `dsh-llm-pi-ai/lib/index.js`
  - `x-opencode-session` in `dsh-llm-pi-ai/lib/index.js`
- Pristine sources for diffing: `npm pack
  @deepseek-ai/dsh-llm-pi-ai@<version>` from the registry.
- After a `dsh` update: run `scripts/check.sh`. If MISSING, run
  `scripts/reapply.sh`; if the patch no longer applies, re-investigate (code
  moved?) or check whether upstream fixed it (mark UPSTREAMED in STATUS.md).
