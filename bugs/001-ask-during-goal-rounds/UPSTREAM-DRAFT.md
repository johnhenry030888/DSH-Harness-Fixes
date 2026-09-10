# Upstream submission -- bug 001 (NOT yet filed)

Post to https://github.com/deepseek-ai/deepseek-harness/discussions as a new
Discussion with a beetle-emoji `Bug:` title. Draft body below the line.
Update the status line at the top once filed.

Submission status: FILED as deepseek-ai/deepseek-harness discussion #6074; argszero engaged (root cause confirmed, in-tree PR requested). Rebased TS port + regression test delivered on-thread (branch johnhenry030888/deepseek-harness@goal-round-ask-guard, 57/57 + oxlint clean + scoped tsc clean); direct PR creation denied by token scope — maintainer may open from the branch.

---

Title: Beetle-emoji + `Bug: ask_user_question usable (and silently discardable) during autonomous goal rounds -> loop`

Environment: dsh 0.1.1-rc.2, Code Mode (`run_code`), same-session goal (256-round cap).

What happened:

During a goal run the agent called `ask_user_question` nested inside `run_code`:
`await tools.ask_user_question({...}); return "asked";`. I answered twice (answers
visible in the session log as inner `tool/code-dispatch` results), but the outer
`tool/result` the model sees was just `"asked"` both times. The agent then looped
30+ goal rounds running verifier slices ending in "Awaiting your two decisions".

Root causes (two independent facts combining):

1. Goal rounds run as the same runtime root, and `dsh-user-questions` only rejects
   live subagents (`DELEGATED_CALLER`), so nothing stops interactive asks during
   autonomous rounds. A pending question declares no timeout budget -- my first
   answer took ~8.5 minutes to arrive while the driver stalled.
2. In Code Mode only the program logs/return re-enter model context, so a nested
   answer is silently discarded unless the program returns or logs it.

Suggested fix (implemented + tested locally against 0.1.1-rc.2):

- Primary: `dsh-goal-round-driver` registers an agent-scoped monotonic
  `ctx.tools.guard()` denying `ask_user_question` for the lifetime of each admitted
  goal attempt (install on inbox claim + admit; dispose on turn/end, discard,
  competing input, pre-step rejections, teardown). Denial tells the model to proceed
  or record `update_goal(blocked)`. A guard denial surfaces in Code Mode as a
  catchable `ToolCallError`, unlike `restrict()`-hiding.
- Secondary: one line in both `tools:sdk` usage blocks warning that binding results
  reach the model ONLY via logs/return.

Happy to share the full diff (two files) here if wanted. Thanks for all the work
on the harness.
