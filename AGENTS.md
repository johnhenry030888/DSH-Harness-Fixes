# Agent guidance -- DSH-Harness-Fixes

This folder is a batch project for DeepSeek Harness bug fixes. Conventions:

## Adding a new bug (bugs/<NNN>-<slug>/)

1. Pick the next number (`ls bugs`). Copy the file set of bug 001 as a template.
2. `README.md`: symptoms, root cause (with file/package references), fix design,
   rejected alternatives and why.
3. `EVIDENCE.md`: session ids, sequence numbers, logs -- everything needed to
   re-verify without the original conversation.
4. `VERSIONS.md`: first version seen broken, versions verified fixed-locally.
   Regenerate with `npm pack <pkg>@<version>` from the registry for pristine
   sources; never reconstruct pristine files by hand.
5. `patches/*.patch`: unified diffs (`diff -u pristine installed`). Verify with
   `patch --dry-run` against a pristine copy before storing.
6. `scripts/check.sh`: must exit 0 when the fix is present, 1 when the bug is
   present. Check by grepping for unique fix markers, never by version alone.
7. `scripts/reapply.sh`: runs check.sh; applies missing patches with
   `patch -N -s <target> <patch>`; re-runs check.sh; syntax-checks touched JS
   with `node --check`. Must be idempotent.
8. `UPSTREAM-DRAFT.md`: Discussion post ready to paste + submission status.
9. Update root `STATUS.md`. Never edit the installed bundle without storing the
   matching patch here first (bundle edits are lost on update).

## After a dsh update

1. Run `scripts/check-all.sh`.
2. For each MISSING bug: try `scripts/reapply.sh`. If the patch fails, check
   whether upstream fixed it (then mark UPSTREAMED) or the code moved (then
   re-investigate and cut a new patch).
3. Update `STATUS.md` and the bug VERSIONS.md.

## Rules

- This project documents and patches the harness install only. Never touch the
  CAPS/working project from here.
- Keep patches minimal and seams-clean: prefer enforcement in the component
  that already owns the lifecycle (as in bug 001: the goal-round driver).
- Record rejected alternatives; upstream reviewers will ask.

<!-- MCP-ROUTING v2.2.0 (managed by scaffold_project; audit may refresh this block even when the rest of the body is customized) -->

## MCP routing (house rule — obey without prompting)

Default profile is `fullstack` (10 servers: computer, playwright, ui-slim,
git, linter-formatter, context-index, postgres, db-manage,
sequential-thinking, opendesign) plus `whisper` on demand — the 11-server
fleet. `whisper` stays unloaded unless audio input exists (prompt-tax
rule: no audio, no load).
Add the `caps` overlay (caps-ingest + figure-forge) only for CAPS/educational
figure work — otherwise leave those ~23 niche tools unloaded. Keep full
`opendesign` loaded whenever UI/design work is in scope (it ships in
fullstack for that reason; never drop it on UI tasks).
Every scaffold/audit ends with a post-scaffold Zero-Debt Gate
(`scripts/verify.sh` + `scripts/audit-secrets.sh`, run by the engine unless
`skipGate:true`): a red gate fails the operation — never commit a red tree.

Guide-first (call once before first real use of that server):

- `whisper`: `list_whisper_models` first (local audio transcription only).
- `ui`: `ui_guide(topic="map")` (or `"loop"` before UI work).
- `opendesign`: `od_guide` + `od_status` (daemon down → report remediation, do not silently skip design).
- `figure-forge`: `forge_guide` + `list_figure_types`.
- unfamiliar repo: `context-index` `index` → `search` → `summary` before editing.

Strict delegation (canonical — never reassign):

- `playwright` = web browser interaction and DOM automation only.
- `computer` = OS/desktop automation on virtual Xvfb `:99` only
  (`--display :0` is an explicit per-launch opt-in, never the default).
- `ui` = app serving (`development_run`), polish/a11y gates, visual
  regression, mobile lifecycles (+ gradio). Never raw browser-DOM or OS-window tasks.

### Operational protocols (how, why, where, when — obey automatically)

- `db-manage` (local dev-DB writes ONLY, loopback only): HOW `db_migrate` /
  `db_seed` / `db_explain`. WHY: all schema changes and seed writes live here —
  `postgres` is SELECT-only and never migrates. WHERE: local `app_dev` via
  `POSTGRES_URL` (never commit credentials). WHEN: dry-run first, then apply;
  destructive resets need `confirm:true` — never unconfirmed.
- `postgres` (STRICTLY read-only): HOW `query` with `SELECT`/`WITH`/`EXPLAIN`
  only. WHY: inspection of local data. WHERE: loopback `POSTGRES_URL`.
  WHEN: any data check. Writes, migrations, seeds → `db-manage`, never here.
- `linter-formatter` (every change, no hand-rolled tool calls): HOW `lint`
  first, `format` to apply. WHY: one call covers ruff/biome/shfmt/shellcheck/
  yamllint/typos instead of five shell invocations. WHEN: `run_tests` for
  suites (before push), `api_call` for loopback REST probes, `perf_gate` for
  bundle-size/latency budgets on UI or API work.
- `context-index` (orient + bootstrap + structural edits): HOW `index` →
  `search` → `summary` in unfamiliar repos; `scaffold_project` for greenfield;
  `rename_symbol` / `move_file_with_imports` / `preview_codemod` for structural
  refactors. WHY: ranked search beats guessing; AST-verified renames and
  import-rewriting moves beat sed. WHEN: dry-run preview first, checkpoint
  with `git` before applying, `apply:true` only after reviewing the diff.
- `ui` / `playwright` (preview + gates, token-efficient): HOW `development_run`
  (loopback serve, artifacts under `.ui-artifacts/`), the
  `development_polish_gate`, `responsive_a11y_gate` and `development_assert`
  gates, plus Playwright 3-frame layout strips
  (State A → Mid-Transition → State B) for transitions. WHY: gates
  decide, screenshots alone prove nothing. WHEN: every UI slice; pass
  `quality=quick` on vision critics for routine checks (strict only for final
  sign-off) to save vision tokens.
- `whisper` (audio input ONLY — the 11th server): HOW `list_whisper_models`
  first, `download_whisper_model` when the needed model is missing,
  `transcribe_audio` for the work. WHY: local transcription, voice-prompt
  processing, and audio context extraction without cloud round-trips
  (models live in `~/.whisper/`). WHERE: any project with audio files or
  voice input. WHEN: never loaded for text-only work (prompt-tax rule);
  transcription output is plain text — quote it, never attach audio blobs.
- `audit-secrets.sh` (secret scanning, no exceptions): HOW
  `sh scripts/audit-secrets.sh` (full tree) and `--staged` (pre-push fast
  path). WHY: fail on high-confidence secret shapes in tracked files (DB URLs
  with passwords WARN only). WHERE: `lefthook.yml` pre-push + `verify.sh`.
  WHEN: before every push and every verify — a HIT fails the gate.

| Server | WHEN to call | WHEN NOT to call |
| --- | --- | --- |
| `context-index` | orient in any unfamiliar repo; `search`/`summary` during implement; structural refactors via `rename_symbol`/`move_file_with_imports`/`preview_codemod` (dry-run first) | small familiar tree where host file tools suffice |
| `linter-formatter` | every change: `lint` first, `format` to apply; `run_tests` for suites, `api_call` for loopback probes, `perf_gate` for budgets | never bypass it for hand-rolled ruff/biome/shfmt calls |
| `git` | checkpoints, safe reverts, status/log/diff, PRs/issues via GitHub tools | never ask the user for routine stage/commit/revert |
| `ui` | serve (`development_run`), `development_polish_gate`, `responsive_a11y_gate`, `development_assert`, `visual_regression`, `inspect_bundle`, gradio/mobile lifecycles | DOM automation (use `playwright`), desktop windows/keys (use `computer`) |
| `opendesign` | every UI task: directions/tokens first, `od_export_component`, `design_review` | non-UI work; never as a second uncoordinated design critic |
| `playwright` | web DOM automation, headless + isolated, loopback-only | app serving/gates (use `ui`), desktop (use `computer`) |
| `computer` | deterministic desktop on `:99` (capture/windows/mouse/keys/clipboard) | day-to-day browser work (use `playwright`), app gates (use `ui`) |
| `postgres` | read-only `query` (`SELECT`) for local data checks; `POSTGRES_URL` override, never commit credentials | writes/migrations/seeds (use `db-manage`) |
| `db-manage` | local dev-DB writes: `db_migrate`/`db_seed` (dry-run first, loopback only) + read-only `db_explain` plans | production data, unconfirmed resets (needs `confirm:true`) |
| `sequential-thinking` | opt-in only when stuck, planning, or branching alternatives (revision/branch thoughts) | per-task narration — the model already reasons stepwise |
| `whisper` | local audio transcription; `list_whisper_models` first, `download_whisper_model` when missing (models live in `~/.whisper/`) | full-stack/UI work with no audio input |
| `caps-ingest` | CAPS projects only: paper search/fetch, doc conversion, structuring, ATP/topic packs | general full-stack sessions (prompt tax + scan noise) |
| `figure-forge` | CAPS/figure work only: generate with `preview`, look, `validate_figure`, one `vision_qa` per finished candidate, `bank_record` | general sessions; never bulk `read_image` (provider image budget ~50/request — prefer server-side `vision_qa`) |

Conventions (all servers): loopback-only automation (`localhost`/`127.0.0.1`
or project-contained `file://`); artifacts (screenshots, downloads, previews)
belong under `<project>/.ui-artifacts/`, never the server dir; keep `ui`
on a slim profile (`DSH_UI_PROFILE=development`, not the full `all` profile)
unless browser+desktop+gradio are all needed; checkpoint with `git` before
risky `format`/refactors (preview `rename_symbol`/`preview_codemod` first);
vision critics default to `quality=quick` (strict only for final sign-off);
`sh scripts/audit-secrets.sh` must pass before push and inside `verify.sh`;
never claim hot reload — config/server changes need a host restart.

### Stage-gate server routing (A-to-Z pipeline — obey per stage)

- Stage 1 (Domain): `context-index` (`index`/`search`/`summary`) +
  `db-manage` (`db_migrate`/`db_seed`, dry-run first) + `postgres`
  (read-only `query`). Playbook: `domain-modeling`.
- Stage 2 (Screen Flows): `ui` (`development_run`, gates) +
  `playwright` (3-frame strips) + `scripts/validate_app_map.py` (exit 0).
  Playbook: `screen-flows`.
- Stage 3 (Element-First UI): `opendesign` +
  (directions/tokens/export/review) + `scripts/check-tokens.sh` (exit 0) +
  `ui_guide`. Playbook: `design-iteration`.
- Stage 4 (Full-Stack Impl): `linter-formatter` (`lint`/`format`/`run_tests`/
  `api_call`/`perf_gate`) + `git` (checkpoints). Playbooks:
  `domain-modeling` + `content-bank` where relevant.
- Stage 5 (Polish & Gates): `development_polish_gate` +
  `responsive_a11y_gate` + `development_assert` + `verify.sh` (Zero-Debt
  Gate). Orchestrator: `a-to-z-runner`.
- Never advance a stage until its exit criteria hold (see `docs/stages.md`);
  `a-to-z-runner` enforces the order hands-off.

### Pre-authorized dev-reset protocol (hands-off DB resets)

- An agent may run `db_seed` with `reset:true` + `confirm:true` WITHOUT
  stopping for human authorization only when ALL hold: greenfield project,
  loopback database (`POSTGRES_URL`, default `app_dev`), unpushed work, and
  a clean `git` checkpoint taken this run.
- Record the reason in `docs/decisions.md`. Anything else — live data,
  pushed work, missing checkpoint — needs explicit human confirmation.
  Never touch live learner state or live content banks.

<!-- /MCP-ROUTING -->

<!-- UI-POLISH v1.6.1 (managed by scaffold_project; audit may refresh this block even when the rest of the body is customized) -->

## UI polish from the start (mandatory — un-gated UI is incomplete)

Applies whenever `features` contains `ui`/`design`, or the tree has UI files
(`.tsx`/`.jsx`/`.ts`/`.html`/`.css`, tailwind/vite/next): design quality is
built
in from the first component, never a fix-up phase afterwards.

1. Orient: `od_guide` + `ui_guide(topic="loop")`, then
   `design_knowledge_search`/`get`, `od_directions`,
   `development_design_tokens`. Daemon guard first: verify the OpenDesign
   daemon is UP at `http://127.0.0.1:7456` (via `od_status`); if down,
   auto-launch the canonical fleet launcher in the background before
   proceeding with any UI work:
   `/home/john/Documents/mcp-servers/opendesign/run.sh &` (fallback:
   `python3 /home/john/Documents/mcp-servers/opendesign/od/od_server.py &`),
   then re-check `od_status` until it reports HTTP 200 on port 7456.
2. Motion tokens first (with design tokens): materialize the canonical motion
   scale into the project token files (`tokens.css` / `tokens.json` or
   equivalent) when absent — Durations `fast: 150ms`, `normal: 250ms`,
   `slow: 400ms`; Easings `emphasized: cubic-bezier(0.2, 0, 0, 1)`,
   `decelerate: cubic-bezier(0, 0, 0.2, 1)`,
   `spring-snappy: spring(stiffness 400, damping 30)`. Every motion use
   references these tokens and ships a `prefers-reduced-motion` fallback.
3. Lock state & motion before code: write
   `.ui-artifacts/interaction-schema.json` (States incl. Idle, Loading,
   Active, Morphing, Reviewing; Events; Transitions; Shared Layout IDs) and
   tag shared elements with `layoutId` / `view-transition-name` per the
   schema (see the `design-iteration` skill).
4. Build with `od_export_component` / `od_export_tokens` (tokens first,
   Tailwind classes pass through verbatim).
5. Gate every UI slice with `design_review`, `development_polish_gate`,
   `development_responsive_a11y_gate` and `development_assert`
   (`no-overflow`, `no-console-error`); serve loopback-only via
   `development_run`, artifacts under `.ui-artifacts/`. Capture multi-frame
   flows, never single shots alone: Playwright records a 3-frame transition
   strip (State A → Mid-Transition/Morph → State B) for any view or panel
   transition, and the critic judges the whole sequence against layout
   continuity (landmark stability, focus retention, non-jank morphing).
   Always pass the absolute PNG screenshot path via `shot=` (never `file=`
   — `file=` runs lint only, no vision) when invoking the vision critic on
   multi-frame transition strips.
   Note: frame 2 uses non-linear easing (`emphasized`, `decelerate`,
   `spring-snappy`), so a non-halfway dimension at duration/2 is expected
   easing behavior, not layout distortion — judge motion presence and
   edge anchoring, not linear interpolation.
   Fix the top finding and re-verify (max 3–5 cycles);
   `development_promote_baseline` on pass.

Screenshots prove nothing alone — gates decide.

<!-- /UI-POLISH -->
