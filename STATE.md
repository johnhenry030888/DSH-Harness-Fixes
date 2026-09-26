# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: **all thirty local fixes applied** to `dsh` 0.1.5-rc.2 (batch 5 —
  016, 020, 026-030 — landed from drill v12's findings plus the orchestrator
  efficiency pass). Drill v13 then closed fix 011: **ten clean
  `standard → orchestrator` switch samples**, no 176-tool mount in any.
- What changed this turn (2026-09-26, batch 5 + repo hygiene):
  - **026** (`dsh-subagent`): the 023 inspection guard now keys on the
    delegation's **declared target paths** (`declaredTreePaths` extracts
    absolute paths from the instruction text; URLs stripped, system roots
    dropped, normalized + deduped) instead of the session cwd, and the refusal
    names the tested tree. Live (drill v13): refusal named `<…>/project` as the
    target and `<…>/project/stats.py` as the writer's declared work; the same
    call succeeded after settlement. v12's false-refusal caveat is gone.
  - **027** (`dsh-subagent` banner): the `subagent:layer` banner now states the
    layer's **authoritative advertised tool count**, computed from the same
    registry view the filter uses — children no longer have to guess
    (children used to claim 137 or 157 against the real 161).
  - **028** (`dsh-subagent-in-process-driver` + `dsh-subagent`): a terminal
    turn failure now preserves its **code** as `SubagentResult.errorCode`
    (`turnFailureCode()` in-process; `settleRunResult()` out-of-process), so a
    workflow script can distinguish a rejected pin from an agent that returned
    nothing, with one stable code on both paths.
  - **029** (child composition): every child now gets a **compact worker
    persona** (~520 chars: role, parent, filter contract, return contract)
    instead of inheriting the lead's ~20.4 k-char persona; a row's own
    `persona` is honoured when set. Cuts per-child token cost and removes the
    seeded-fork impersonation surface.
  - **030** (`dsh-agent-loop`): **cancel-then-replan** — `AgentLoop` tracks
    `inFlightToolCalls` around `executeToolCalls()` and a steer cancels them so
    the message lands at the resulting boundary instead of waiting out a 60 s
    tool call.
  - **016** (`dsh-tool-subagent`): `list_subagent_models({catalog:true})` — a
    third, mutually exclusive mode returning the agent's authoritative
    `{count,names}`.
  - **020**: scriptable local session helper + documented path (no harness code
    change; authentication untouched).
  - **Repo hygiene finished by the assistant after the batch run stopped short
    of its completion gate:** biome-formatted the two new helper scripts
    (`bugs/020…/scripts/dsh-local-session.mjs`,
    `bugs/026…/scripts/target-path-check.mjs`) so `verify.sh` is green again;
    added `STATUS.md` rows and the header paragraph for all seven new bugs;
    updated this file; committed and pushed.
  - **007 gained a re-runnable live probe** (`bugs/007…/scripts/drill-007-probe.sh`):
    it boots the shipped headless profile twice against a targeted `toolFilter`
    overlay in a scratch harness home, so the last unexercised fix no longer
    needs a user-preset edit. Result: **PASS (both variants)** — the tolerant arm
    spawned a child whose own header proves the filter applied, and the typo arm
    failed loudly with the loader row and `"subagnt_fast"` named and created no
    child session. (Two probe-design traps were found and documented: the
    preset's 17 names are pins the headless host lacks, and a standing row cannot
    enable `modelSelectionSettings`.)
  - **Persona corrected for the batch-5 fixes** (preset backup
    `agent.cordis.yml.pre-v14-20260926`, three edited lines): a child's count is
    now read from the 027 banner instead of being distrusted as a hand count, and
    the steering guidance reflects fix 030 — a steer cancels the in-flight tool
    call, so the ~62 s long-call band is history and > ~20 s behind a long call is
    friction to report.
  - **Drill v14 written** (`~/Desktop/orchestrator-drill-prompt-v14.md`): required
    live probes for 016, 020, 027, 028, 029 and 030, the 007 probe script as a
    required phase, three regression checks, a completion gate and the exact
    report/evidence paths.
- Verification:
  - `bash scripts/check-all.sh` — exit 0, **all 30 checks PRESENT** (026-030
    included).
  - `./scripts/verify.sh` — exit **0** after the formatting fix (it was FAILED:
    biome reported 3 errors + 3 warnings in the two new scripts).
  - `sh scripts/audit-secrets.sh` — exit 0.
  - `dsh --profile headless "Reply with exactly the single word: pong"` →
    `pong`, exit 0, empty stderr (patched bundle boots).
  - Drill v13 (live, real Orchestrator session): **011 CLOSED** (10/10 clean
    switch samples, transcript-corroborated); 006, 008, 009, 010, 012, 013,
    014 (with the 014b residual), 017, 018, 019, 021, 023, 025, 026 all PASS;
    013's fork effort pin verified (`high`, not the lead's `max`).
- Deployment note: `~/.dsh/settings.yaml` deliberately pins the eight
  `opencode-go.models`; the Orchestrator preset now also bounds workflow
  fan-out (`maxConcurrentAgents: 6`, `maxTotalAgents: 64`) and pins the fork
  lane's effort.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` / biome) — clean after the two-script fix
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `baaf069` (bugs 016/020/026-030 fixes +
    docs; pre-commit `shfmt`/`shellcheck`/`typos` cleared first: the two
    multiline `{ … }` blocks were expanded, the literal-`grep -F` marker
    scripts carry a file-level `# shellcheck disable=SC2016` with the reason,
    and the four wordings that `typos` flagged were rephrased)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes`
    accepted `63ff83d..baaf069` on `main`; pre-push hooks passed (pytest, node,
    cargo/go skips, secrets green)
  - [x] update this file (every turn ends by updating it)
- Open items:
  - **Live probes outstanding for 016 / 020 / 027 / 028 / 029 / 030** — applied
    and `check.sh`-green, but no drill has exercised them yet; drill v14 carries
    the probes (catalog self-query and mode exclusivity, scriptable session
    creation, banner count on three child kinds, in-script failure branch, child
    vs lead persona size, steer-cancels-in-flight latency).
  - **007 is no longer waiting on a drill-time preset edit**: the new probe
    script passes locally, but drill v14 still has to run it inside the real
    session and paste the output as its acceptance record.
  - 023/024 disclosed acceptance limits from an earlier turn still stand
    (headless overlays rather than the real preset; the direct-path classifier
    is covered by drills).
  - The human should restart their own `dsh web` so it loads the patched
    bundle.
- Decisions: see `docs/decisions.md`.
