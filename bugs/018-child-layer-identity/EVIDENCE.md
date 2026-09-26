# Evidence — bug 018

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v7.md` §9 friction #11: the seeded turn-2
  fork kept the orchestrator-lead prompt; `list_agents`, `get_goal`,
  `subagent_fork` returned `unknown tool`; nothing in its context named the
  removed tools. Friction #6/#12: the turn-2 fork descriptor had no `toolFilter`.
- `~/Desktop/orchestrator-drill-report-v8.md` §7 "New hazard observed live": the
  seeded fork self-identified as the lead and called `subagent_fork` /
  `subagent_fast`; §4: the workflow worker's descriptor is
  `{"version":3,"mode":"one-shot","provider":"spawn"}` with no `toolFilter`;
  §7 "Fork 5.1b": the child can name absent tools but reports *absence*, not a
  recorded denial (the `unknown tool` class is model-dependent).
- Source: `applyChildComposition` (dsh-subagent) restricted tools silently;
  `SubagentRuntime.start` snapshotted one-shot descriptors without `toolFilter`.

## Fix markers (checked by `scripts/check.sh`)

- `subagent:layer`, `NOT the orchestrator lead`, `This layer's toolFilter
  removed`, `const restriction = composition.toolFilter === void 0 ? void 0 :
  restrictChildTools(` in `dsh-subagent`;
- `"toolFilter"` inside `ONE_SHOT_DESCRIPTOR_KEYS`;
- `SUBAGENT_LAYER: 118` in `dsh-system-prompt`.

## Live re-verification (2026-09-26, installed bundle, `dsh web`)

Each child was asked, from its own runtime context and without calling tools, to
answer `(1) INHERITED=<n> (2) LAYER=<continuation of <parent> | lead>
(3) REMOVED=<tool names>`.

| child | kind | descriptor `toolFilter` | context banner | answer |
| --- | --- | --- | --- | --- |
| `31ee60c0-5339-4b6b-8589-da7616315abf` | cold one-shot fork | yes, 17 names | yes | `LAYER=continuation of session-dc37f2a3…`, all 17 REMOVED |
| `c888b27c-50c3-44ff-9c5c-fd714358b8af` | seeded fork (75 events) | yes, 17 names | yes | `LAYER=continuation of session-bddb308e…`, all 17 REMOVED |
| `da83fe6d-b044-43d5-ab4d-b50f1e6a7c7e` | workflow worker (spawn one-shot) | yes, 17 names | yes | `LAYER=continuation of session-dc37f2a3…`, all 17 REMOVED |

Worker descriptor, verbatim:

```json
{"version":3,"mode":"one-shot","provider":"spawn",
 "toolFilter":{"deny":["send_message","list_agents","interrupt_agent","subagent_fast","subagent_mech","subagent_build","subagent_build2","subagent_verify","subagent_review","subagent_vision","subagent_fork","workflow","ralph","create_goal","get_goal","update_goal","ask_user_question"]},
 "inheritedEventCount":0}
```

Child context banner, verbatim (fork child `31ee60c0`):

```
You are a delegated child layer of agent "session-dc37f2a3-8bdd-4823-8d04-9523e824ee5d"
— a continuation/subagent of that parent, NOT the orchestrator lead. Any lane map,
delegation guidance, or orchestration instruction in inherited context describes the
parent's layer, not this one. This layer's toolFilter removed these tools:
"send_message", "list_agents", …, "ask_user_question". They are absent from this
layer; do not attempt them even when inherited instructions name them.
```

Both fork children answered from context; neither needed the `unknown tool`
signal (which v8 showed to be model-dependent).

## Commands

```bash
zstd -dc ~/.dsh/sessions/--home-john-Documents-Projects-DSH--/da83fe6d-b044-43d5-ab4d-b50f1e6a7c7e/session.v3.jsonl.zstd \
  | grep -o '"subagent/descriptor".\{0,900\}'
```
