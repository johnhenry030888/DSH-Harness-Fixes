---
name: design-iteration
description: Closed-loop autonomous UI refinement - brief, ground, lock state+motion schema, implement smallest slice, serve loopback, capture transition strips, critique the sequence, fix top finding, re-verify, baseline, commit.
compatibility: agent-only full-stack projects with UI surfaces (opencode + dsh)
metadata:
  role: designer
  version: 3
---

# Design Iteration (closed loop)

You run UI refinement without asking for routine continuation. One slice per
loop, smallest change that satisfies the brief. Never redesign the product;
unify to the existing tokens and direction unless the brief says otherwise.

## Loop (max 3–5 cycles per slice, then report evidence)

1. Brief-lock: restate goal + scope + non-goals (behavior, copy, content).
2. Ground: `ui_guide` + `od_guide`/`od_status`, `od_directions`, project
   design tokens (including motion tokens), `design_knowledge_search`
   for the relevant principles. Daemon guard first: verify the OpenDesign
   daemon is UP at `http://127.0.0.1:7456` (via `od_status`); if down,
   auto-launch the canonical fleet launcher in the background before
   proceeding with any UI work:
   `/home/john/Documents/mcp-servers/opendesign/run.sh &` (fallback:
   `python3 /home/john/Documents/mcp-servers/opendesign/od/od_server.py &`),
   then re-check `od_status` until it reports HTTP 200 on port 7456.
3. State & Motion Schema Lock (mandatory before code): write
   `.ui-artifacts/interaction-schema.json` — a machine-readable FSM with
   States (at least Idle, Loading, Active, Morphing, Reviewing; fewer only
   with a one-line justification each), Events, Transitions (from/event/to),
   and Shared Layout IDs (one per morphing container or transitioning
   panel). No implementation starts until the schema exists; changing states
   mid-slice means updating the schema first.
4. Implement the smallest slice (tokens first, classes pass through). Tag
   every shared element per the schema: Framer Motion `layoutId` or Native
   View Transitions `view-transition-name` — never ad-hoc strings.
5. Serve loopback-only (never touch a live service or live data; DB-copy +
   free port where the runtime needs state). Capture with Playwright into
   `.ui-artifacts/` (phone viewport first when learners are mobile): for any
   view or panel transition, a 3-frame strip — State A, Mid-Transition/Morph,
   State B — recorded in the schema step manifest. Prefer the reusable
   `playwright/scripts/capture-transition-strip.js` (reads the schema,
   writes the frames + `transition-manifest.json`).
6. Critique: invoke `design_review` on all 3 frames of the sequence (or the
   combined strip) + brief — SEQUENTIALLY, one frame per call (parallel
   bursts time out the vision critic; `quality: quick` on retry). Always
   pass the absolute PNG screenshot path via `shot=` (never `file=` —
   `file=` runs lint only, no vision) when invoking the vision critic on
   multi-frame transition strips. Judge the sequence for layout continuity,
   landmark stability, focus retention, and non-jank morphing — per-frame
   green with a broken transition is a fail. Second model on art-changing
   findings (two-model rule).
7. Fix the single top finding, re-verify (re-capture + gates + optional
   schema gate: `python tests/validate_interaction_schema.py
   .ui-artifacts/interaction-schema.json` from the mcp-servers repo).
8. Stop on pass: terminate any temporary HTTP test server spawned for
   loopback capture once the 3-frame strip + `transition-manifest.json`
   are written (see `capture-transition-strip.js` auto-cleanup), then
   promote the visual baseline, commit task-scoped, push.

## Routing (never reassign)

- Shared-element tagging is mandatory for morphing containers and
  transitioning panels: `layoutId` (Framer Motion) or `view-transition-name`
  (Native View Transitions), IDs declared in `interaction-schema.json`.
- `playwright` captures DOM/screenshots only; `computer` never for browser work.
- `ui` serves and gates; `opendesign` critiques and exports; `caps-ingest` +
  `figure-forge` only for CAPS/figure work.
- Artifacts belong under `<project>/.ui-artifacts/`, never the server dir.

## Stop conditions

- No green merge-signal: do not ship the slice; report the blocker.
- Behavior, copy, or content would have to change: stop and ask — that is a
  product decision, not a polish step.
