---
name: domain-modeling
description: Stage 1 data layer - migrations dry-run-first, seed data, loopback API checks before any screen work.
compatibility: agent-only full-stack projects with persisted data (opencode + dsh)
metadata:
  role: backend
  version: 1
---

# Domain Modeling (data before screens)

Finish Stage 1 before Stage 2 starts. No screen, token, or endpoint ships
on an unmodeled domain. Record every decision in docs/domain.md.

## Loop

1. Model: entities, fields, relations in docs/domain.md (table per entity).
2. Migrate: db_migrate dry-run first, review the plan, then apply. Loopback
   databases only (POSTGRES_URL, default app_dev); never commit credentials.
3. Seed: db_seed (or stack seed path) with representative rows; educational
   projects seed one full topic pack slice, not placeholder lorem.
4. Verify reads: postgres query with SELECT/WITH/EXPLAIN only (never writes
   here; writes live in db-manage). Confirm seed rows read back correctly.
5. API checks: api_call per endpoint (loopback only) with expect_status and
   expect_json_keys; perf_gate when latency or bundle budgets apply.
6. Checkpoint with git before any risky refactor; update STATE.md on Stage 1
   exit (or explicit no-DB note when the project stores nothing).

## Destructive resets (pre-authorized dev-reset rule)

- Allowed hands-off ONLY when all hold: greenfield project, loopback
  database, unpushed work, clean git checkpoint taken this run.
- Then db_seed with reset:true + confirm:true is permitted; record the
  reason in docs/decisions.md. Anything else: stop and ask.
- Never touch live learner state, live content banks, or production data.

## TypeScript note (zero-install baseline)

- The node scaffold tsconfig is strict with no `types` field (no @types
  install required for a green gate). The moment sources import node
  builtins (node:test, node:fs, node:path), run
  `npm i -D @types/node` and add `"types": ["node"]` to tsconfig.json,
  or `tsc --noEmit` fails on the imports. Record the install reason.

## Routing (never reassign)

- postgres reads; db-manage writes; linter-formatter probes (api_call).
- Context: index -> search -> summary before touching unfamiliar schemas.
- Sequential-thinking only when stuck on modeling alternatives.

## Stop conditions

- Migration plan unclear or destructive beyond the dev-reset rule: stop.
- Seed content needs product decisions (real learner data): stop and ask.
