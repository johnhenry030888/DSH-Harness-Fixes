# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: bugs 014b/017/021/022 added from drill v9/v10; all twenty local fixes
  applied to `dsh` 0.1.5-rc.2 (017 and 021 live-verified; 022 live-verified on
  both mount paths; 014b verified from the rendered tool description).
- What changed this turn (2026-09-26, follow-up from drill v9/v10):
  - **021** (`dsh-sandbox` + `dsh-sandbox-local`): the roots seam exports
    `tempWriteRoots()` (canonical `/tmp` + `os.tmpdir()`), and every confined
    mode now gets a writable temp area — bwrap mounts the private ephemeral
    `--tmpfs /tmp` in the base profile (was workspace-write only), Landlock
    grants the temp roots under read-only, Seatbelt (untested on this Linux
    host) allows `file-write*` under them. The fs fence still refuses
    `read-only` mutations and the workspace stays kernel-read-only. Live with a
    temporary `readOnly: true` headless row: pre-fix the bare pinned
    `python3 -m pytest --import-mode=importlib` died with
    `No usable temporary directory found`; post-fix `3 passed` exit 0 with no
    workaround flags, while the shell append was still refused; an
    unconstrained fork lane still wrote its scratch file.
  - **017** (`dsh-subagent` + three `.d.ts`): the settlement notice now carries
    `stopTime` (capture moment) and `lastActivityTime` (child's last epoch
    event) on the `subagent-settled` source, the notice text, and
    `subagent/end`. Live interrupt of a child inside `sleep 120`: `stopTime`
    23 ms after `lastActivityTime`, which equals the child's aborted
    `turn/end.time` exactly; notice envelope 22.7 s later (the conflation the
    fix removes).
  - **022** (`dsh-agent-presets`): one event writer
    (`setSessionAgentPreset`) records `mountPath: "direct"|"switch"` +
    `rowMount: "mounted"`; `mount()` writes direct, `swap()` writes switch.
    Live via a headless `--patch` overlay + probe: direct and switch events
    both recorded and both sessions ran (`pong`, exit 0). The web
    create-then-pick flow itself could not be run (no web restart allowed) —
    disclosed in the README/EVIDENCE.
  - **014b** (`dsh-tool-workflow`): the `agent()` bullet in the workflow tool
    description now says the `null` is deliberately unattributed and points at
    the run record (`agent-end` `error` + requested route). Live: the lead
    quoted the new passage verbatim.
  - New file sets: `bugs/014b-…`, `bugs/017-…`, `bugs/021-…`, `bugs/022-…`
    (README, EVIDENCE, VERSIONS, UPSTREAM-DRAFT, patches, check/reapply
    scripts + `sandbox-temp-check.mjs`).
- Verification:
  - per bug: `patch --dry-run` clean against pristine (017/021/022; 014b
    against raw and 014-stacked pristine), `node --check` clean,
    `check.sh` exit 1 on the pre-fix state / 0 after `reapply.sh`,
    `reapply.sh` twice = idempotent.
  - root gates: `check-all.sh` exit 0 (all 20 checks PRESENT), `verify.sh`
    exit 0, `audit-secrets.sh` exit 0, house lint (biome/shfmt/shellcheck/
    typos) clean on all new files.
  - live smoke: `dsh --profile headless "Reply with exactly the single word:
    pong"` -> `pong`, exit 0, empty stderr.
  - live 021: children `5ec99c10` (pre-fix failure), `006a5364` (post-fix
    `3 passed` + refusal), `5a0fce9b` (unconstrained fork writes FREE).
  - live 017: lead `session-56478b3d`, child `ce1df1eb` (notice source
    `stopTime` 1790414939218 / `lastActivityTime` 1790414939195).
  - live 022: direct `session-dfa78142`, switch `session-cc2c51c6`.
  - live 014b: headless quote of the new workflow description passage.
- Settings note: the `opencode-go` `models:` pin is **deliberately present**
  (curated 8-route deployment); bug 012 keeps rejections honest under it.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` `lint`) — biome/shfmt/shellcheck/ruff/typos/yamllint clean on new files
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `9ed184e` (bugs 014b/017/021/022 fixes + docs, STATUS/STATE)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes` accepted `bb36ce0..9ed184e` on `main`; pre-push hooks passed (pytest 4 passed, node/cargo/go/secrets green)
  - [x] update this file (every turn ends by updating it)
- Open items:
  - 016 (catalog introspection) remains NOT implemented; no seam-clean
    callable exists in the current composition (a new global tool family is a
    product decision, not a patch).
  - 022 was not exercised through the live web create-then-pick flow (would
    require restarting the user's `dsh web`); both service methods were
    driven live from a headless probe instead.
  - Seatbelt (macOS) temp grants in 021 are parity code, untested on this
    Linux host.
  - The human should restart their own `dsh web` when convenient so it loads
    the patched bundle (it was not restarted this turn).
- Decisions: see `docs/decisions.md`.
