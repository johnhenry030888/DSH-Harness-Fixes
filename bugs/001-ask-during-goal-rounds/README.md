# Bug 001 -- ask_user_question usable (and silently discardable) during goal rounds

## Symptoms

During a same-session goal run the agent called `ask_user_question` nested
inside `run_code` as `await tools.ask_user_question({...}); return "asked";`.
The human answered twice; both answers arrived in the session log as inner
`tool/code-dispatch` results, but the outer `tool/result` the model sees was
just `"asked"`. The agent then looped 30+ goal rounds "awaiting" already-given
decisions (verified: rounds 28-62 ran identical verifier slices).

## Root cause (two independent harness facts)

1. No goal-mode scoping on interactive tools. Goal rounds run as the same
   runtime root (`delegationDepth: 0`), and `dsh-user-questions` only rejects
   live subagents (`DELEGATED_CALLER`). Nothing stops interactive asks during
   autonomous rounds, and a pending question declares no timeout budget, so it
   stalls the driver (first ask blocked ~8.5 minutes).
2. In Code Mode only the program logs/return re-enter model context. A nested
   answer is silently discarded unless the program returns or logs it.

## Fix design (applied locally)

- Primary: `dsh-goal-round-driver` registers an agent-scoped monotonic
  `ctx.tools.guard()` denying `ask_user_question` for the lifetime of each
  admitted goal attempt (patch: `patches/goal-round-driver.patch`). Install on
  `inbox/claimed` + admit; dispose on `turn/end` (all reasons), discard,
  competing human input, pre-step rejections, idle pause-after-cancel,
  `session-start`, `agent/disposed`, teardown. Denial directs to
  `update_goal(blocked)` or proceeding autonomously. A guard denial surfaces
  in Code Mode as a catchable `ToolCallError`, unlike `restrict()`-hiding
  (uncatchable, KV-cache churn, documented non-authority seam).
- Secondary: one instruction line in both `tools:sdk` usage blocks (TS + Python)
  warning that binding results reach the model ONLY via logs/return
  (patch: `patches/dsh-tools-sdk.patch`).

## Rejected alternatives

- Prompt-policy text alone (model judgment already failed; `dsh-tool-goal`
  mechanically enforces `blockedAfterConsecutiveRounds` -- same precedent).
- `restrict()`-hiding (wrong seam, see above).
- Service-level check in `userQuestions.ask()` (needs turn-source threading the
  driver already owns -- strictly larger change).
- Post-hoc unused-answer detection in `run_code` (fragile value-flow analysis).

## Verification

- `node --check` clean on both edited files.
- Throwaway driver test (faked ctx/agents/goals/sessions, real `apply()`):
  11/11 assertions -- install on claim, denial text, other tools unaffected,
  survives admit, dispose on turn-end / discard / competing input, reinstall
  across rounds. (Test file removed after the run.)
