---
name: project-autonomy
description: Use for greenfield project requests and existing project work so scaffolding, stack selection, audits, gates, commits, and push evidence continue without routine user prompts.
---

# Project Autonomy

Use the fleet as an execution loop, not as a menu of suggestions.

## Recognize the project

1. For a substantial multi-round request such as an app, game, or service, arm
   one long-running session goal before implementation and keep it active until
   completion. Do not create competing goals; feedback reopens the same project
   iteration after the prior one is complete.
2. The host bootstrap or MCP initialize instructions may have already supplied
   this contract before project-local files exist. Inspect the current directory
   with `context-index` (`index` -> `search` -> `summary`) before editing an
   unfamiliar tree.
3. If there is no source or project instruction file, call
   `project_intake` with the absolute target path and the user's one-line goal.
   Leave `stack` and `features` omitted unless the user explicitly chose them so
   intent and detected files can select them.
4. If `.scaffold.json` exists, or the target is an unmarked non-empty project,
   `project_intake` automatically audits it when `audit` is omitted and
   `stack` is omitted or `auto`.
   Use `allowNonEmpty:true` only when adopting a foreign remote is intentional;
   the audit still refuses such remotes without that confirmation.
5. Read the returned `stackDecision`, `workflowStart`, `next`, and `STATE.md`.
   An existing project may safely add a requested runtime when the decision marks the
   expansion additive; existing manifests and source stay intact, while
   destructive migrations remain explicit and must not be guessed.

## Execute the loop

1. Start or resume the durable workflow with `workflow_start` or
   `workflow_resume`.
2. Implement the smallest useful production slice. Do not stop to ask about
   routine tool, framework, file, or sequencing choices; choose the option
   supported by the detected stack and the user's goal.
3. Run the routed quality loop: `linter-formatter` lint/format/tests, database
   dry-runs and loopback probes where relevant, UI/design gates for UI work,
   and `./scripts/verify.sh` plus `scripts/audit-secrets.sh`.
4. Record gate evidence, checkpoint and push the work, update `STATE.md`, then
   continue until the workflow can be completed. If a gate fails, fix it and
   retry; use `workflow_resume` for a recorded blocked state.
5. Call `workflow_complete` only with valid commit evidence and either push
   evidence or a concrete, recorded deferral reason.

## Boundaries

Preserve user code and live data. Never commit secrets, rewrite pushed history,
or silently overwrite customized managed files. Product behavior decisions that
are genuinely unspecified may be chosen autonomously; ask only when the choice
would change user intent, safety, or live content.
