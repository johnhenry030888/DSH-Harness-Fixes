# Evidence — bug 013

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v7.md` §7 "Fork 5.1/5.2" and §9 friction
  #3/#12: descriptor `{version:3, mode:"continuable", provider:"fork", …}` with
  **no seed field**; the only marker is `session/end-seed {"inherited": true}` at
  seq 562 (v7) / 708 (v8).
- `~/Desktop/orchestrator-drill-report-v8.md` §7: cold child `57197a0f`
  (`isSeeded:false`, `session/end-seed` seq 28 `{}`, token not recalled); seeded
  children `e764b113`/`b119a95f` (`isSeeded:true`, seq 708, token recalled with
  zero tool calls); "no spawn-time notice" for either.
- Precondition: a reply through `ask_user_question` creates no `turn/end`, so
  the second-turn fork attempt 1 (`cfbca693`) stayed cold.

## Fix markers (checked by `scripts/check.sh`)

- `function optionalCount(`, `This layer inherited ${inheritedEventCount}
  completed event`, `inheritedEventCount` in `dsh-subagent`;
- `inheritedEventCount: activationBoundary` in
  `dsh-subagent-in-process-driver`;
- `fork child of session` + `inherits ${inheritedEventCount} completed events`
  in `dsh-subagent-fork-in-process`.

## Live re-verification (2026-09-26, installed bundle, `dsh web`)

### Cold fork (parent inside its first, unbalanced turn)

Session `session-dc37f2a3-8bdd-4823-8d04-9523e824ee5d` (orchestrator), turn 1
step 1 → `subagent_fork`; child `31ee60c0-5339-4b6b-8589-da7616315abf`:

- `subagent/descriptor` (child transcript, seq 0):
  `{"version":3,"mode":"one-shot","provider":"fork","label":"Fork self-report
  probe","toolFilter":{…17 names…},"inheritedEventCount":0}`
- child runtime context contains
  `This layer inherited 0 completed events from parent agent
  "session-dc37f2a3-8bdd-4823-8d04-9523e824ee5d" (0 means it started cold …)`
- child answer (no tools): `INHERITED=0`

### Seeded fork (parent has completed turns)

Session `session-bddb308e-68e1-4ef3-ad74-4aeb3fd14d75`, turn 5 (turns 1–4
completed) → `subagent_fork`; child
`c888b27c-50c3-44ff-9c5c-fd714358b8af`:

- `subagent/descriptor`: `"inheritedEventCount": 75`
- child runtime context: `This layer inherited 75 completed events …`
- child answer (no tools): `INHERITED=75`
- the parent's own log at the boundary: `session/end-seed {"inherited": true}`
  immediately before `turn/start turn=5`

### Host warning, both directions

`scripts/seed-announcement-check.mjs` (installed modules, stub logger):

```
warnings: ["subagent-fork-in-process: fork child of session session-open inherits 0 events — …"]
infos:    ["subagent-fork-in-process: fork child of session session-completed inherits 4 completed events"]
coldDescriptor: {"version":3,"mode":"one-shot","provider":"fork","label":"cold","toolFilter":{"deny":["workflow"]},"inheritedEventCount":0}
folded:         same, read back through foldSubagentDescriptor
SEED-ANNOUNCEMENT-CHECK PASS
```

The web host's logger does not print `ctx.logger.warn/info` to stdout (bug 007
recorded the same sink limitation), so the host half is verified at module level;
the child-visible half is verified live above.

## Commands

```bash
node bugs/013-fork-seed-announcement/scripts/seed-announcement-check.mjs
zstd -dc ~/.dsh/sessions/--home-john-Documents-Projects-DSH--/31ee60c0-5339-4b6b-8589-da7616315abf/session.v3.jsonl.zstd | grep -o '"inheritedEventCount": [0-9]*'
```
