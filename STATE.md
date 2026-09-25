# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: bugs 006-010 added; all ten local fixes applied to `dsh` 0.1.5-rc.2.
- What changed this turn (2026-09-25, bugs 006-010 from the orchestrator drill
  v3/v4 findings):
  - **006** (`dsh-workflow-worker-thread`): added deployment-owned
    `toolFilter` to the engine `Config` and passed it on every
    `subagents.start()` in `WorkerRun.startChild()` — workflow workers now
    honor the same leaf policy as direct lanes. Unset default unchanged
    (live negative control).
  - **007** (`dsh-subagent` + `dsh-tool-subagent`): tolerant child composition
    (`restrictChildTools` drops unknown names, warns with the child id and
    every dropped name, never silently widens) plus row-identified
    `assertKnownToolFilterNames` validation before a spawn and on
    `agent/created`. `restrict()` itself stays strict (rejected alternative).
  - **008** (`dsh-subagent-fork-in-process` + `dsh-tool-subagent`): host
    warning when a fork's seed is empty (0 inherited events, parent named) and
    a corrected fork tool description stating the completed-turn contract.
    Seeding rule untouched.
  - **009** (`dsh-tool-subagent` + `dsh-llm`): route rejections now classify
    served-but-not-allowed vs provider-does-not-serve (via `llm.listModels`);
    effort rejections append `— supported: <ladder> (default: <id>)`.
  - **010** (`dsh-jobs-local`, `dsh-tool-subagent-control`,
    `dsh-agent-loop`, `dsh-system-prompt`): agent-id hint on `unknown job`;
    `list_agents` rows carry `checkedAt` (ISO sample time); new `agent:route`
    runtime-context section renders the agent's effective provider/model/effort.
  - New files: `bugs/006-…` … `bugs/010-…` (README, EVIDENCE, VERSIONS,
    UPSTREAM-DRAFT, patches, check/reapply scripts + three `.mjs` live
    checks); `STATUS.md` updated.
- Verification:
  - per bug: pristine `patch --dry-run` clean (the three `dsh-tool-subagent`
    patches stack 007 -> 008 -> 009), `node --check` clean, `check.sh` exit 1
    on pristine / 0 after `reapply.sh`, `reapply.sh` twice = idempotent.
  - root gates: `check-all.sh` exit 0, `verify.sh` exit 0,
    `audit-secrets.sh` exit 0, `linter-formatter lint` clean
    (shfmt/shellcheck/biome/typos).
  - live smoke: `dsh --profile headless "Reply with exactly the single word:
    pong"` -> `pong`, exit 0, empty stderr (twice).
  - live 006: temporary `--patch` override of the `workflow-worker-thread` row
    -> worker catalog omits all 7 denied tools and a nested `workflow` is
    ABSENT; option unset -> v4 surface reproduced (PRESENT).
  - live 007: temporary copy of the orchestrator preset with the v3 deny list
    -> child spawned (`READY`, space-bunny-free @ medium), all 17 restrictable
    names absent from its request header, `subagent`/`list_subagent_models`
    present (own layer); bogus name -> row-identified error
    (`row "include:agent-presets:tool-subagent" … "subagnt_fast"`);
    `tolerance-check.mjs` passes (warning names every dropped name; all-unknown
    deny -> `deny: []`, all-unknown allow -> fail-closed).
  - live 008: `seed-check.mjs` passes (empty seed -> warning; completed turn ->
    4-event seed); live mid-turn fork child `isSeeded:false`, no
    `session/end-seed`.
  - live 009: invented id -> "does not serve a model with id"; served-but-not-
    allowed id -> "the provider serves this model id, but it is outside the
    Session's allowed routes"; effort -> `— supported: low, high, max`.
  - live 010: `list_agents` -> `[running as of <iso>]`; `job_output(agent id)`
    -> teaching hint; transcript snapshot contains the resolved route line
    (`high (resolved)` after the first request, `unresolved …` on step 1).
- Settings note: the `opencode-go` `models:` pin re-added before drill v3 was
  removed again so bug 005's live catalog is served (backup:
  `~/.dsh/settings.yaml.bak-pre-bug010-20260925`). Restoring that pin makes
  `check-all.sh` fail bug 005 by design.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` `lint`) — shellcheck/shfmt/biome/typos clean
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `c1418c3` (bugs 006-010 fixes + docs)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes` accepted `0682a5b..c1418c3` on `main`; pre-push hooks passed (node/pytest/cargo/go/secrets all green)
  - [x] update this file (every turn ends by updating it)
- Open items:
  - the running `dsh web` host still has the pre-006..010 bundle in memory; the
    human should restart it when convenient (their live session is untouched).
  - 009's discovery-tool branch (`list_subagent_models`) carries the same
    classification and is code-verified + dry-run verified; the live harness
    could not install the per-agent discovery tool in time (late-mount
    artifact), so only the delegation branch is live-verified.
  - 010's effort line is honest about being unresolved on the first step
    (nothing is pinned yet); it resolves from step 2 onward.
  - `UPSTREAM-DRAFT.md` for bugs 006-010 are NOT-FILED.
- Decisions: see `docs/decisions.md`.
