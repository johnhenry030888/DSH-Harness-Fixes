# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: **all thirty-one local fixes applied** to `dsh` 0.1.5-rc.2 (batch 5 —
  016, 020, 026-030 — landed from drill v12's findings plus the orchestrator
  efficiency pass). Drill v13 then closed fix 011: **ten clean
  `standard → orchestrator` switch samples**, no 176-tool mount in any.
- Desktop sweep (2026-09-26): every drill artifact except the active v18 prompt
  moved to `~/Documents/dsh-drill-archive/` — `prompts/` (18, plus `prompts/opencode/`
  with the 5 batch-fix prompts), `reports/` (16), `evidence/` (16), `roots/` (16
  drill working directories, 12 MB total) and `orchestrator-switch-path-log.md`.
  Nothing was deleted. Drill v18's setup/output paths now write into the archive
  (`roots/orchestrator-drill-v18-<STAMP>`, `reports/`, `evidence/`), so the Desktop
  stays clean between runs.
- What changed this turn (2026-09-26, drill v17 follow-up):
  - **drill v17 (efficiency re-run): PASS, with one honest negative result.**
    1 677 s / 853 109 tokens / 10 children / 171 calls; suite 47 passed with
    **11/11 mutations RED (0 survivors)** including both that v16's suite missed;
    the owner-settled guard was correctly dispatched through a read-only row and
    the steer cost 4.98 s (1.46 s to boundary, 3.52 s to reply) against a lane
    whose own steps cost 3.3-6.0 s. The negative: doctrine fix 2 (effort-match the
    workflow siblings) did not achieve its aim — the spread worsened to 2.451x and
    the workflow sub-task finished 4.7 s cheaper out of 852 s, because the barrier
    saving was exactly offset by a terminal merge that inherited the lead's `max`
    (395.3 s, 55 702 output tokens).
  - **Persona corrected for the negative result and the new frictions** (backup
    `agent.cordis.yml.pre-v18-20260926`, five sentences): right-size the terminal
    merge deliberately (v16's cheap 53.6 s merge was correct, v17's heavy 395 s
    merge was the error); every `agent()` stage inherits your effort and the
    record hides it, so verify effort per child afterwards and route
    effort-critical stages through the pinned `subagent*` rows; keep your own
    verification delegated (lead input share regression 15.6% -> 24.0%); a
    read-only lane's `/tmp` is wiped between calls, so a mutation reproduction
    must be one self-contained invocation; and `subagent/descriptor` — not a
    "quote your system prompt" probe — is the authoritative child identity (4/4
    children quoted its filter sentence correctly; 1 of 4 faked the prompt line).
    A workflow-spawned child advertises **162** tools vs a direct child's 161 —
    recorded so it is not misread as a lost filter.
  - **Open items now four** (top first): (1) resolved effort + provenance on the
    workflow agent events, and an explicit effort-or-default marker from every
    adapter (v17 friction #1, high); (2) `list_agents` should render the
    delegation's declared target, which the ordering guard already computes (v16
    F2 / v17 #2); (3) surface the steer delivery/boundary stamps — the transcript
    already carries `agent/inbox/spliced` with a timestamp (v17 #3); (4) one
    persistent scratch dir for read-only lanes (v17 #4, low).
  - **Drill v18 written** (`~/Desktop/orchestrator-drill-prompt-v18.md`): the
    bounded efficiency run — same end-to-end shape with a right-sized merge, and
    explicit bars (workflow sub-task ≤ ~500 s vs 852/848 s, lead input share
    ≤ ~17%, 0 surviving mutations, all regressions green).
- Earlier this turn (2026-09-26, drill v16 follow-up):
  - **drill v16: end-to-end PASS** (report + evidence on the Desktop; 37 min 15 s,
    942 467 tokens, 14 children, 141 model calls). The full lane set ran in the
    prescribed order with no rule violated; the deliverable is real
    (`wordstats.py` + `test_wordstats.py`, `47 passed` when the lead ran it) and a
    genuine RED falsification was captured twice by independent lanes. Its own
    honest caveat: the suite is green **and** two single-line mutations survive it
    (case-only tie ordering, the untested default `-n`).
  - **Persona corrected for the three legibility gaps it exposed** (backup
    `agent.cordis.yml.pre-v17-20260926`, four sentences): only `subagent_review`
    and `subagent_vision` are `readOnly: true` (so a write-capable lane's probe is
    admitted by design — reading that as a guard failure cost v16 ~28 s and ~58 k tokens);
    `agent()` **inherits the lead's effort** and the run record hides it (v16's
    stage-1 siblings ran at unmatched effort: 798 s vs 378 s, 36 % of the run);
    a build task now carries a **discrimination checklist** (one adversarial input
    per contract clause); and the review lane must **re-run** claimed mutations.
  - **Drill v17 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v17.md` (was on the Desktop)): the
    efficiency re-run — same end-to-end task, but with the three doctrine fixes
    exercised and the telemetry diffed against v16's baseline; its explicit bar is
    that v16's two surviving mutations go RED.
  - Three open items recorded in the ledger (see the STATUS verification note):
    the `list_agents` declared-tree render, the steer delivery/boundary stamp, and
    the resolved stage effort in the workflow run record.
- Earlier this turn (2026-09-26, drill v15 follow-up):
  - **drill v15: 31/31 PASS, 0 FAIL, 0 NOT RUN** (report + evidence on the
    Desktop, since archived under `~/Documents/dsh-drill-archive/reports/`; drill root `~/Documents/dsh-drill-archive/roots/orchestrator-drill-v15-20260926-1923`). Every
    local fix in the project is now observed live: v15 itself exercised 001
    (answer arrives as the `ask_user_question` tool result inside a goal round,
    `roundsStarted: 0`), 002 (GitHub `list_commits` + postgres `select 1` —
    `${VAR}` env expansion live), 004 (operator confirms the Codex sign-in entry),
    010a/b/c (job-tool teaching hint, `checkedAt` rows, own route line), 019
    (`write` refused **and** a shell mutation denied by the read-only sandbox,
    while the build lane still wrote), 021/025 (read-only pytest: no temp-dir
    error, no cache warning, and the suite falsified both ways), plus 016b/020b,
    018/020/022/023/026/027/029 and the three regressions.
  - **Two v15 frictions remain open** (recorded here rather than half-fixed):
    `list_agents` shows the child's session cwd, not its declared target tree
    (the guard's `declaredTreesOf` is the right source; it lives in
    `dsh-subagent` and the listing is projection-backed), and a steer's
    delivery/boundary timestamps are not surfaced for measurement.
  - **Cheap v15 follow-ups landed:** the 020 helper reports `webPid` (+ `kept`)
    so a "no stray server" assertion is baseline-relative, and the 025 README
    documents the self-invalidating assertion trap (`has_plugin("cacheprovider")
    is False`, never a `.pytest_cache` directory check).
  - **Persona corrected** (backup `agent.cordis.yml.pre-v16-20260926`): the job
    tools' teaching hint and `checkedAt` semantics, the `[writes in …]`
    tree caveat (never read it as the declared target), the second and third
    steering-band samples with the model-bound split, and the falsification
    pitfall.
  - **Drill v16 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v16.md` (was on the Desktop)): the
    closure run — one real end-to-end task through the whole lane set
    (partition → build → verify + falsification → review → lead merge), a
    two-stage `workflow` sub-task, an efficiency-telemetry table (wall clock per
    phase, prompt sizes, tokens, steers/retries), a short regression sweep, and
    the two open frictions re-checked as observations.
- Earlier this turn (2026-09-26, drill v14 follow-up):
  - **drill v14 results (report on the Desktop): 21 PASS / 1 FAIL / 7 NOT RUN.**
    Closed live: 007 (probe, both variants), 020, 027 (161 = header on direct /
    workflow / fork), 028 (`UNKNOWN_MODEL` on both paths), 029 (555-char worker
    persona, no lane map), 030 (steer → reply in 4.1 s behind a 90 s sleep,
    `AbortError`/`ABORTED`). Its single FAIL: 016's `catalog: true` was silently
    accepted with `provider`/`model`.
  - **016b** (new, 31st fix; `dsh-tool-subagent`): the catalog branch now refuses
    route arguments by name and the tool description states the rule. Verified
    **live** on a freshly booted process via a second `dsh web`: both mixed calls
    rejected with the named message, while `{catalog:true}` alone still returned
    `{count:178,names:178}` and `{provider}` alone still listed 8 routes.
  - **020b** (helper, `bugs/020…/scripts/dsh-local-session.mjs`): a prompted run
    now waits for the first `turn/end` and reports `turnCompleted`,
    `headerToolCount`, `assistantText`, `turnEndReason`, `waitedMs`. Two real
    defects were found and fixed while validating it: the store is **multi-frame**
    zstd (Node's single-shot `zstdDecompressSync` returned 198 B of a 47 KB
    transcript, so the wait never saw `turn/end`) and the wait must happen before
    the SIGTERM. Verified live: `headerToolCount: 178`, `waitedMs: 16958`.
  - **Persona corrected again** (backup `agent.cordis.yml.pre-v15-20260926`):
    the steering band is now stated as model-bound with v14's numbers, the mount
    tripwire names `list_subagent_models({catalog:true})` as the authoritative
    self-count (and as a standalone mode), and delegation-failure attribution
    points at `tool/result.error.code` / `workflow … errorCode`, never the
    descriptor.
  - **Drill v15 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v15.md` (was on the Desktop)):
    required phases for the never-observed fixes — 001 (goal-round ask), 002 (MCP
    `${VAR}` expansion via the github + postgres servers), 004 (Codex sign-in
    entry, operator-assisted), 010a/b/c (job-tool teaching hint, `checkedAt`,
    own route), 019/021/025 (one read-only-lane pytest phase), plus 016b and
    020b verification and three regressions.
  - Stray server from a `--keep` run reaped (drill v14 friction #5).
- Earlier this turn (2026-09-26, batch 5 + repo hygiene + 007 probe):
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
  - **Drill v14 written** (`~/Documents/dsh-drill-archive/prompts/orchestrator-drill-prompt-v14.md` (was on the Desktop)): required
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
  - [x] checkpoint/commit (`git`) — `5cce78c` (bug 016b + the turn-aware 020
    helper + STATUS/STATE docs; hooks green) after `baaf069` (bugs 016/020/026-030
    fixes +
    docs; pre-commit `shfmt`/`shellcheck`/`typos` cleared first: the two
    multiline `{ … }` blocks were expanded, the literal-`grep -F` marker
    scripts carry a file-level `# shellcheck disable=SC2016` with the reason,
    and the four wordings that `typos` flagged were rephrased), then `8c9d61e`
    (the bug-007 live probe, its README/EVIDENCE record, and the STATUS/STATE
    updates for it)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes`
    accepted `63ff83d..baaf069`, `baaf069..8c9d61e` and `edcc07c..5cce78c` on
    `main`; pre-push hooks passed on every push (pytest, node, cargo/go skips,
    secrets green)
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
