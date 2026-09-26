# Versions — bug 011

- First analyzed broken: `@deepseek-ai/dsh-tool-subagent` 0.1.5-rc.2 (installed
  bundle with fixes 006–010 applied), from drill v6 (2026-09-25, session
  `c9f92826`). The throwing arm is fix 007's; upstream 0.1.6-alpha.2 has no
  `agent/created` validation arm at all (its `restrict()` still throws, but the
  boot arm was this project's addition).
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - the patch applies to pristine published sources with 007/008/009 applied,
    no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 1 pre-fix (verified against a pristine+existing
    tree), 0 post-fix; `scripts/reapply.sh` idempotent;
  - live: three `standard` → `orchestrator` switch sessions at **178** tools
    with `subagent` + `list_subagent_models`; a bogus filter name still fails
    its own spawn with the row id; the session mounts.
- Pristine source: `npm pack @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `boot toolFilter validation deferred for agent`,
  `the row's pre-spawn check re-validates`, and a `try {`-guarded
  `agent/created` listener.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 011 is MISSING, run
  `scripts/reapply.sh`; if the patch no longer applies, re-investigate (code
  moved?) or check whether upstream made the boot arm non-destructive (then mark
  UPSTREAMED in root `STATUS.md`).
