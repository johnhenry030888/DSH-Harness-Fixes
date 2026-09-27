# Versions — bug 040

- First analyzed broken: `@deepseek-ai/dsh-subagent` 0.1.5-rc.2 (installed
  bundle with fixes 001–039 applied), from drill v27 §6 F2 and the refused
  delegation transcript at parent seq 67.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-28):
  - the patch applies to the 039-fix guard with no fuzz; `node --check` clean;
  - forward/reverse round trip byte-identical; `scripts/check.sh` exit 1
    pre-fix, 0 post-fix; `scripts/reapply.sh` idempotent;
  - `scripts/guard-reader-scope-check.mjs` FAIL (9 cases) pre-fix, PASS
    post-fix; `bugs/031/scripts/guard-scope-check.mjs` and
    `bugs/032/scripts/guard-pair-check.mjs` still PASS on the patched bundle
    (v26 A3 writer case included);
  - `scripts/reader-scope-probe.sh` live: disjoint `/tmp` declaration admitted
    while a writer is live, overlapping declaration refused naming the pair
    with `scopeBasis: declared`, same declaration admitted after settlement;
    the durable `subagent/inspection-scope` records hold all three outcomes.
- Pristine source: `npm pack @deepseek-ai/dsh-subagent@0.1.5-rc.2`, then the
  batch 6–7 reapply chain (031/032 stack on the same region).
- Fix markers (checked by `scripts/check.sh`, never the version):
  `READ_SCOPE_CUE`, `declaredReadScopePaths`, `declaredPromptScope`,
  `droppedIncidental`, the `ignored as incidental/scratch` refusal wording, and
  031/032's basis/refusal text.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 040 is MISSING, run
  `scripts/reapply.sh` (it chains 031/032 first); if the patch no longer
  applies, re-investigate or check whether upstream added cue-based reader
  declarations (then mark UPSTREAMED).
