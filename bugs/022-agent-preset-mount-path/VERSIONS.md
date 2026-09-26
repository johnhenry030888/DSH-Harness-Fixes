# Versions — bug 022

- First analyzed broken: `@deepseek-ai/dsh-agent-presets` 0.1.5-rc.2
  (installed bundle with fixes 007–019 applied), from drill v9 §7 #6 and
  v10 §10 #9 / §0 setup note.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - both patches apply to pristine published sources with no fuzz
    (`npm pack` sources, `diff -q` confirmed identical to the installed
    files before the fix);
  - `node --check` clean on the patched JS;
  - `scripts/check.sh` exit 1 pre-fix, 0 post-fix; `scripts/reapply.sh`
    idempotent (twice);
  - live: a headless session with a temporary `agent-presets` overlay recorded
    `mountPath: "direct"` after `mount()` and `mountPath: "switch"` after
    `select()`, both with `rowMount: "mounted"`, and both sessions still ran
    normally (exit 0). The web create-then-pick flow itself could not be
    exercised without restarting the user's `dsh web` (disclosed in README).
- Pristine sources: `npm pack @deepseek-ai/dsh-agent-presets@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `function setSessionAgentPreset(session, agentPreset, mountPath, rowMount)`,
  `setSessionAgentPreset(session, preset.id, "direct", "mounted");`,
  `setSessionAgentPreset(agent.session, preset.id, "switch", "mounted");`,
  `mountPath: 'direct' | 'switch';`.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 022 is MISSING,
  run `scripts/reapply.sh`; if the patch no longer applies, check whether
  upstream recorded mount provenance in the preset event (then mark
  UPSTREAMED).
