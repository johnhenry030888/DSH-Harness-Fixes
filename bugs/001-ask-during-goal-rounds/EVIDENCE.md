# Evidence -- bug 001

All evidence below was read from the local DSH session store (no live system
was modified during investigation).

## Looping session

- Project session dir: `~/.dsh/sessions/--home-john-Documents-Projects-CAPS~0020NWT~0020Gr~00205~0020~002B~00206--/`
- Sibling session: `session-0a63fd9b-1336-47b8-92a7-a76cc71c4376`
  (`session.jsonl.zstd`, 4757 lines at time of inspection).
- Its goal: `goal-2dffaba7-9eaf-4719-8c1f-d63481408fb1` ("analyse this project
  ... so dsh/opencode work can proceed efficiently"), 256-round cap.

## First ask (turn 3, step 20)

- `tool/call` seq 1894: `run_code` program
  `await tools.ask_user_question({questions: [{id: "spec-direction", ...}]});`
  followed by `return "asked";` -- return value discarded by construction.
- Inner dispatch `tool/code-dispatch-start` seq 1895 -> `tool/code-dispatch`
  seq 1896 (~8.5 min later -- the human answering) with content
  `{"answers":[{"id":"spec-direction","selected":["Rebuild specs + rewire"]}]}`.
- Outer `tool/result` seq 1897: just `"asked"`. The model never saw the answer.

## Second ask (turn 27, step 1)

- Same wrapper pattern, questions `gates-7` + `hybrid`.
- Inner result seq 4956:
  `{"answers":[{"id":"gates-7","selected":["Rebuild SW-Wisk specs"]},
  {"id":"hybrid","selected":["Formally drop"]}]}`.
- Outer `tool/result` seq 4957: just `"asked"` again.
- Turn 27 step 2 text claims the two answers are "the only path to full
  completion" while never acting on them.

## The loop

- Rounds 28-62: rotating verification slices ending in variants of
  "Round N done. Goal left active. ... Awaiting your two decisions".
- Tails inspected at turns 58-62 (identical verifier + awaiting-decisions text).

## Harness code references (installed bundle 0.1.1-rc.2)

- `dsh-tool-ask-user/lib/index.js`: `execute()` forwards `exec.agent` to
  `ctx.userQuestions.ask()`; result rendered as compact JSON -- but only for
  top-level calls. Nested Code Mode results surface solely via outer logs/return.
- `dsh-user-questions/lib/index.js`: rejects only `CALLER_NOT_LIVE` /
  `DELEGATED_CALLER`; a goal-round root passes both checks.
- `dsh-tools/lib/index.js` Code Mode section: SDK sub-dispatches carry the
  outer `parent` token and are exempt from the `UNKNOWN_TOOL` collapse.
- `dsh-tools/lib/index.js`: `guard()` is monotonic, sync, agent-scopable with
  an explicit disposer; precedent: `dsh-subagent-in-process-driver` registers
  `childCtx.tools.guard(...)`. Agents expose `.ctx` (`parent.ctx.agents.create`).
- `dsh-goal-round-driver/lib/index.js`: attempt lifecycle queued -> claimed ->
  admitted, with `inbox/inserted|claimed|discarded`, `session/event`,
  `agent/pre-step`, `agent/status`, `goal/changed`, teardown handlers.
  `ToolExecution` carries no turn number -- the reason the guard must be owned
  by the driver rather than derived downstream.
