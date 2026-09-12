---
name: screen-flows
description: App-map to per-screen FSMs - 3-frame transition strips, back-stack and focus-restore verification before code ships.
compatibility: agent-only full-stack projects with UI surfaces (opencode + dsh)
metadata:
  role: designer
  version: 1
---

# Screen Flows (map -> FSM -> strips)

One screen at a time. No implementation starts until its FSM link exists in
docs/app-map.md AND its schema exists in .ui-artifacts/.

## Loop per screen

1. Map: add the Screen row (Route, FSM, Guard, Fallback) to docs/app-map.md.
2. Schema-lock: write .ui-artifacts/interaction-schema.json (States incl.
   Idle, Loading, Active, Morphing, Reviewing; Events; Transitions; Shared
   Layout IDs). Tag shared elements with layoutId / view-transition-name.
3. Cross-check: python3 scripts/validate_app_map.py docs/app-map.md must
   exit 0 (orphans, duplicate routes, guard-without-fallback all fail).
4. Capture: Playwright 3-frame strip (State A -> Mid-Transition -> State B)
   into .ui-artifacts/ with transition-manifest.json. Phone viewport first
   when learners are mobile.
5. Critique the sequence (quick default; jury only for final gate or after
   2 consecutive failures). Judge layout continuity, landmark stability,
   focus retention, non-jank morphing. Per-frame green plus broken
   transition is a FAIL.
6. Fix the single top finding, re-verify, promote baseline, commit.

## Back-stack and focus rules (verify explicitly)

- Every screen declares its back target; deep links cold-start through Home.
- Guarded routes declare a Fallback state shown when the guard denies.
- Every transition restores focus to the trigger on close (focus restore);
  modals trap focus while open. State this per screen, do not assume it.

## Routing (never reassign)

- playwright captures DOM and screenshots only; ui serves and gates;
  opendesign critiques and exports; computer never for browser work.
- Daemon guard first (od_status, auto-launch if down).
- Artifacts under `<project>/.ui-artifacts/`, never the server dir.

## Stop conditions

- validate_app_map.py red: fix the map, do not code around it.
- No green merge-signal: do not ship the slice; report the blocker.
- Behavior, copy, or content would have to change: stop and ask.
