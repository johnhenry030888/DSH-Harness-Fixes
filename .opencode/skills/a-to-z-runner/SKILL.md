---
name: a-to-z-runner
description: Stage-gate orchestrator - Stages 1-5 strictly in order, exit artifacts verified before advancing, vision token budgets managed.
compatibility: agent-only full-stack projects scaffolded from Project-Template (opencode + dsh)
metadata:
  role: orchestrator
  version: 1
---

# A-to-Z Runner (stage gates)

You run the whole pipeline hands-off. Stages execute strictly in order
1 -> 2 -> 3 -> 4 -> 5. Never start a stage until the previous exit criteria
hold (see docs/stages.md). Skipping now only fails verify.sh later.

## Gate checks before advancing

1. Stage 1 done when docs/domain.md exists + migrations dry-run clean +
   seed data present (or explicit no-DB note in domain.md).
2. Stage 2 done when docs/app-map.md exists + validate_app_map.py exits 0.
3. Stage 3 done when tokens.json/tokens.css exist + check-tokens.sh exits 0
   - docs/components.md has one row per atomic component.
4. Stage 4 done when run_tests green + lint clean + api_call loopback
   checks pass for every endpoint.
5. Stage 5 done when every transition has a 3-frame strip +
   development_polish_gate passes + baseline promoted + verify.sh OK.

## Vision token budget (obey)

- Routine critique: single-pass design_review(quality=quick) only.
- Full jury (passes > 1 and/or secondary verify) for FINAL slice gates.
- Escalation: after 2 consecutive gate failures on one slice, spend one
  jury pass (passes=3 + secondary verify) before reporting a blocker.
- Frames sequentially, one call each; absolute shot= paths, never file=.
- One-shot MCP stdio: HOLD stdin open until the verdict lands (FastMCP
  shuts down on stdin EOF and slow gates go silent); use
  scripts/mcp-call.py with an explicit timeout, never a bare pipe.

## Loop

Per stage: run its playbook (domain-modeling, screen-flows,
design-iteration, content-bank where relevant), verify exit criteria,
commit task-scoped, update STATE.md, advance. End of run: verify.sh green
AND tree committed AND pushed (or push deferred with reason).

## Routing (never reassign)

- Stage routing table lives in AGENTS.md MCP-ROUTING v2.2.0; follow it.
- Artifacts belong under docs/ or `<project>/.ui-artifacts/`, never elsewhere.
- Daemon guard first on any UI stage (od_status, auto-launch if down).

## Stop conditions

- No green merge-signal: do not ship; report the blocker with evidence.
- Behavior, copy, or content must change: stop and ask (product decision).
- Destructive DB reset outside the pre-authorized dev-reset rule: stop.
