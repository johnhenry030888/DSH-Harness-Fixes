# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: bugs 023/024/025 added from drill v11; all twenty-three local fixes
  applied to `dsh` 0.1.5-rc.2 (023, 024, 025 live-verified this turn on
  temporary headless overlays; 009/012 check markers updated for 024's shared
  formatter).
- What changed this turn (2026-09-26, drill v11 polish batch):
  - **023** (`dsh-subagent` + `dsh-tool-subagent-control`): a mechanical
    verify→review guard. `treesOverlap` + `inspectionConflicts` scan the live
    direct children of the parent for a *running* child whose resolved
    `sandbox/mode` is not `read-only` and whose tree overlaps the parent's;
    both creation paths (`SubagentRuntime.start` and `startContinuable`)
    refuse a `readOnly: true` spawn with `SubagentError` code
    `INSPECTION_CONFLICT`, naming the conflicting child and tree. `list_agents`
    rows now expose `filePolicy` (`read-only`/`writes`) and `tree`. Live:
    writer `b72a493a` still running → read-only call refused (code
    `INSPECTION_CONFLICT`), `list_agents` showed `[writes in …]`, and after the
    writer's settlement notice the identical call returned `READY`.
  - **024** (`dsh-llm` + `dsh-llm-pi-ai` + `dsh-tool-subagent` +
    `dsh-tool-workflow`): `run-end` now carries `failedAgents` + `error` +
    `requestedProvider`/`requestedModel` from the first failed member; a new
    shared `modelResolutionDiagnostic` in `dsh-llm` renders
    `MODEL_NOT_CONFIGURED` vs `UNKNOWN_MODEL` for both the pi-ai resolution
    path and the delegation classifier (both sites now throw `LlmError`).
    Live: workflow `run-end` `{"stopReason":"completed","failedAgents":2,
    "error":"…(MODEL_NOT_CONFIGURED)",…}`; the direct path produced the same
    canonical sentence with code `MODEL_NOT_CONFIGURED`; unknown id likewise
    `UNKNOWN_MODEL`.
  - **025** (`dsh-tool-bash`): a read-only policy now exports
    `PYTEST_ADDOPTS="-p no:cacheprovider"` (appended to any inherited value,
    idempotent), documented in the tool description. Live: read-only lane bare
    pinned pytest `3 passed` with no `PytestCacheWarning`; write lane
    unchanged (`PYTEST_ADDOPTS` empty, write succeeded).
  - **Check updates** (`bugs/009`/`bugs/012` `check.sh`): the
    served-but-unconfigured/unknown-id wording moved into the shared `dsh-llm`
    formatter, so those checks now assert their classes wherever they render.
    No 009/012 fix patch changed.
  - New file sets: `bugs/023-inspection-ordering-guard/`,
    `bugs/024-workflow-diagnostics/`, `bugs/025-read-only-pytest-cache/`
    (README, EVIDENCE, VERSIONS, UPSTREAM-DRAFT, patches, check/reapply
    scripts, fixtures; 023 also ships `inspection-check.mjs`).
- Verification:
  - per bug: `patch --dry-run` clean against pristine-with-stack (023:
    007→013→017→018→019 and 010; 024: 007→008→009→011→012→019, 009→012,
    003→005→012, 014→014b; 025: raw pristine), `node --check` clean,
    `check.sh` exit 1 on the shadow pre-fix state / 0 after `reapply.sh`,
    `reapply.sh` twice = idempotent, shadow round trips byte-identical.
  - root gates: `check-all.sh` exit 0 (all 23 checks PRESENT), `verify.sh`
    exit 0, `audit-secrets.sh` exit 0, Verify's lint/format/test gates clean.
  - live smoke: `dsh --profile headless "Reply with exactly the single word:
    pong"` -> `pong`, exit 0, empty stderr (two clean runs; one earlier run
    emitted an ordinary model reasoning trace on stderr, not a harness
    message).
  - live 023: lead `session-1dd23223`, writer `b72a493a`, read-only success
    `0bb8ffc0`.
  - live 024: lead `session-4b3f46c9`, run `fb61c378`, children `d961d930` /
    `9fe1d6bb`.
  - live 025: lead `session-4c00e538`, read-only child `2cb4c34d`, write child
    `25e58a4e`.
- Settings note: the `opencode-go` `models:` pin is **deliberately present**
  (curated 8-route deployment); bug 012 keeps rejections honest under it.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` `lint`) — biome/shfmt/shellcheck/ruff/typos/yamllint clean on new files
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `65f7b15` (bugs 023/024/025 fixes + docs,
    STATUS/STATE, 009/012 check-class updates)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes`
    accepted `2115b57..65f7b15` on `main`; pre-push hooks passed (pytest, node,
    cargo/go skips, secrets green)
  - [x] update this file (every turn ends by updating it)
- Open items:
  - 016 (catalog introspection) remains NOT implemented; no seam-clean
    callable exists in the current composition (a new global tool family is a
    product decision, not a patch).
  - 020: scriptable local session creation not pursued beyond the existing
    NOT-FILED note (no supported non-GUI path discovered this turn).
  - 023 acceptance disclosed limit: the live proof used a temporary headless
    `--patch` overlay with the Orchestrator row shape (the 021 precedent),
    because the headless profile does not auto-mount agent presets. An attempt
    to mount the real Orchestrator preset via an `agent-presets` overlay
    booted but did not compose the preset (headless creates its session
    outside the preset mount path), so it was abandoned rather than forced.
  - 024 acceptance disclosed limit: the direct-path live probe used fixed-pin
    rows (pi-ai preflight), not the Session-allowlist classifier, which needs
    `modelSelectionSettings` under a scoped preset; the v12 drill covers it.
  - The human should restart their own `dsh web` when convenient so it loads
    the patched bundle (it was not restarted this turn).
- Decisions: see `docs/decisions.md`.
