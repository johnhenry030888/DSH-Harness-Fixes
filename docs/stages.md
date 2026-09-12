<!-- markdownlint-disable MD013 -->
# A-to-Z Stage Gates (v1.10.0)

A new project moves through five stages in order. Each stage has entry
criteria (what must be true to start), required artifacts (files that must
exist), and exit criteria (what the gates check). `scripts/verify.sh`
enforces presence on UI projects: missing stage artifacts warn; Stage 4/5
code without Stage 1-3 baselines FAILS the gate.

| Stage | Name | Entry | Required artifacts | Exit (gate) |
| --- | --- | --- | --- | --- |
| 1 | Domain & Schemas | scaffold exists | `docs/domain.md`, DB migrations, seed data (or explicit no-DB note) | `docs/domain.md` present; `db_migrate` dry-run clean |
| 2 | Interaction & Screen Flows | Stage 1 exit | `docs/app-map.md` (screen inventory, routes, FSM links, back-stack/deep-link/guard rules) | `scripts/validate_app_map.py` exits 0 |
| 3 | Element-First UI | Stage 2 exit | `tokens.json`/`tokens.css` (durations, easings, colors, spacing) + `docs/components.md` (atomic registry) | `scripts/check-tokens.sh` exits 0 |
| 4 | Full-Stack Implementation | Stage 3 exit | code, unit/integration tests, API loopback checks (`api_call`) | `run_tests` green, `lint` clean |
| 5 | Visual Polish & Gates | Stage 4 exit | 3-frame transition strips, `development_polish_gate` pass, baseline screenshots, Zero-Debt Gate | `verify.sh` OK + baselines promoted |

## Rules

- Never skip stages: code (Stage 4) before tokens (Stage 3), or pages before
  the app-map (Stage 2), fails `verify.sh` on UI projects.
- `docs/app-map.md` is instantiated from `docs/app-map.template.md` at
  scaffold time (never clobbered afterwards); edit the `.md`, not the template.
- `tokens.json` is scaffolded for `ui`/`design` features (and `node`/`polyglot`
  stacks); every motion/color/spacing value ships from tokens with a
  `prefers-reduced-motion` fallback.
- Behavior, copy, or content changes remain product decisions: stop and ask.
  Everything else runs hands-off until `verify.sh` passes AND the tree is
  committed AND pushed (or push explicitly deferred with reason).
