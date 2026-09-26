# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: bugs 011-014 + 018/019 added; all sixteen local fixes applied to
  `dsh` 0.1.5-rc.2 (live-verified on the real Orchestrator switch path).
- What changed this turn (2026-09-26, follow-up from drill v6/v7/v8):
  - **011** (`dsh-tool-subagent`): the `agent/created` boot arm no longer
    throws synchronously (which aborted agent creation and rolled back the
    model-selection row's own-layer registrations — the v6 176-tool
    regression). It catches, logs a row/agent-named deferral diagnostic, and
    the pre-spawn arm remains the hard failure. Live: four `standard` →
    `orchestrator` switch sessions at 178 tools with `subagent` +
    `list_subagent_models`; a bogus filter name still fails its own spawn with
    the row id.
  - **012** (`dsh-llm` + `dsh-llm-pi-ai` + `dsh-tool-subagent`): route
    rejections classify against configured ids, the provider catalog
    (adapter ∪ live cache, new `listCatalogModels`), and the allowlist. Live:
    `glm-5.3-flash`/`gpt-5.6-luna` → "serves model … not configured for this
    deployment"; invented id → "does not serve"; `mimo-v2.5` spawns.
  - **013** (`dsh-subagent` + `dsh-subagent-in-process-driver` +
    `dsh-subagent-fork-in-process`): numeric `inheritedEventCount` on the
    descriptor (0 cold / N seeded), both-direction host log, and a visible
    child runtime-context line. Live: cold fork child `31ee60c0` count 0,
    seeded child `c888b27c` count 75, both answered from context.
  - **014** (`dsh-subagent-in-process-driver` + `dsh-workflow-worker-thread`
    + `dsh-tool-workflow` + `dsh-workflow` types): the child's turn failure
    becomes `SubagentResult.diagnostic`, crosses the worker boundary, and lands
    on `tool-workflow/agent-start`/`agent-end` with
    `requestedProvider`/`requestedModel`. Live: rejected pin records
    `error:"pi-ai provider \"opencode-go\" has no configured model
    \"glm-5.3-flash\" (UNKNOWN_MODEL)"` + the route.
  - **018** (`dsh-subagent` + `dsh-system-prompt`): a leading
    `subagent:layer` runtime-context banner names the parent and the removed
    tools, and one-shot descriptors declare `toolFilter` (also 015's descriptor
    half). Live: cold fork, seeded fork and workflow worker each answered
    `LAYER=continuation of <parent>` + all 17 removed names from context.
  - **019** (`dsh-tool-subagent` + `dsh-subagent` +
    `dsh-subagent-in-process-driver`): per-row `readOnly: true` installs a
    child-scoped guard refusing `edit`/`write`/`present` with a named,
    path-aware error and pins the child's file policy to `read-only` for shell
    mutations; durable on the descriptor. Live: refusal names the child id and
    path; bash append denied by the sandbox; an unconstrained child still
    writes; lead-owned file hash unchanged.
  - Also updated: bug 005's check no longer fails on the deliberate settings pin
    (prints NOTE); bug 009's check asserts its class (012 supersedes the exact
    wording). New files: `bugs/011-…` … `bugs/019-…` (README, EVIDENCE,
    VERSIONS, UPSTREAM-DRAFT, patches, check/reapply scripts +
    `seed-announcement-check.mjs` and `read-only-check.mjs`).
- Verification:
  - per bug: pristine `patch --dry-run` clean at each stack point,
    `node --check` clean, `check.sh` exit 1 on the pre-fix tree / 0 post-fix
    (verified against staged pristine trees via `DSH_AGENT_BASE`), `reapply.sh`
    twice = idempotent (verified on a fake bundle tree).
  - full round-trip: pristine published sources + 003/005/006/007/008/009/010 +
    011/012/013/014/018/019 patches == the installed bundle, byte-for-byte
    (all touched files).
  - root gates: `check-all.sh` exit 0, `verify.sh` exit 0 (biome/typos/token
    gates green), `audit-secrets.sh` exit 0.
  - live smoke: `dsh --profile headless "Reply with exactly the single word:
    pong"` -> `pong`, exit 0, empty stderr.
  - live 011: sessions `62c4ace0`, `bfcdbb55`, `bddb308e` (standard→orchestrator)
    + `cf26ff18` on the restarted host — all 178 tools, both names; bogus-name
    session `cc817fa7` mounts and fails its own spawn with the row id.
  - live 012: session `bddb308e` seq 27/32/37/43 (verbatim in EVIDENCE).
  - live 013: children `31ee60c0` (0) and `c888b27c` (75).
  - live 014: workflow run `7500cc87-2e99-4db6-a53f-7793a98ca30e`.
  - live 018: children `31ee60c0`, `c888b27c`, worker `da83fe6d`.
  - live 019: temporary `orchestrator-ro` preset, session `8b1795be`, children
    `e4b2d67e` (edit refusal), `24900c3c` (bash denied), `db62c697` (free write);
    fixture sha256 unchanged.
- Settings note: the `opencode-go` `models:` pin is **deliberately present**
  (curated 8-route deployment); bug 012 keeps rejections honest under it.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` `lint`) — shellcheck/shfmt/biome/typos clean
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `82460ba` (bugs 011-014/018/019 fixes + docs)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes` accepted `7f10bbc..82460ba` on `main`; pre-push hooks passed (node/pytest/cargo/go/secrets all green)
  - [x] update this file (every turn ends by updating it)
- Open items:
  - a probe `dsh web` (ours) was started for live checks; stopped at the end of
    the turn. The human should start their own `dsh web` when convenient so it
    loads the patched bundle.
  - temporary probe presets `~/.dsh/.agent-presets/orchestrator-ro` and
    `orchestrator-bogus` were used for 019/011 live checks; removed at the end
    of the turn (the user's `orchestrator` preset was never edited).
  - 014 residual: a failed child still reaches the workflow script as `null`
    (documented `agent()` contract); only the run record was in scope.
  - 015/016/017/020 are stretch and NOT-FILED (015's descriptor half is covered
    by 018; 020 is documented NOT-FILED in STATUS.md).
- Decisions: see `docs/decisions.md`.
