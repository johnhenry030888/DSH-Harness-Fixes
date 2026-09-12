# App Map — {{PROJECT_NAME}} (Stage 2)

> Screen inventory, routes, FSM links, back-stack / deep-link / guard rules.
> Instantiated from `docs/app-map.template.md` at scaffold time. Keep this
> file current: every new screen adds a row AND an FSM transition before code.
> Validated by `scripts/validate_app_map.py` (run via `scripts/verify.sh`).

## Screens

<!-- Columns: Screen (human name), Route (must start with /), FSM (state
machine in .ui-artifacts/interaction-schema.json), Guard (empty when public),
Fallback (required when Guard is set: state shown when guard denies). -->

| Screen | Route | FSM | Guard | Fallback |
| --- | --- | --- | --- | --- |
| Home | / | home-flow | | |
| Details | /details | details-flow | | |
| Settings | /settings | settings-flow | auth | Home |

## Back-stack

- Back from Details returns to Home; back from Settings returns to Home.
- Deep link `/details` cold-starts Home first, then pushes Details (never a
  bare Details with an empty stack).
- Guarded route `/settings` without auth shows the Fallback state (Home).

## Focus restore

- Every view transition restores focus to the triggering element on close
  (focus restore), verified across the 3-frame transition strip (State A ->
  Mid-Transition -> State B).
- Modals trap focus while open and return it on dismiss.
