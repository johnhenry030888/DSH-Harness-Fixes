# Evidence — bug 009

## Primary evidence (reports)

- `~/Desktop/orchestrator-drill-report-v4.md` §6 (negative tests):
  - N1 `subagent` `glm-5.3-flash` @ `high` →
    `Error: child LLM route "opencode-go/glm-5.3-flash" is not allowed for this Session`
  - N2 `subagent` `deepseek-v4.1-flash` @ `medium` →
    `Error: provider "opencode-go" model "deepseek-v4.1-flash" does not support reasoning effort "medium"`
  - N3 `subagent` `gpt-5.6-luna` @ `high` → identical to N1.
  - §9 friction 9: "Unknown model → `not allowed for this Session`; invalid
    effort → `does not support reasoning effort` … only the effort error tells
    you the model was valid."
- `~/Desktop/orchestrator-drill-report-v3.md` §5: N1/N2/N3 ordering evidence
  (route validation before filter construction).
- `~/Desktop/orchestrator-drill-report.md` §4 and `-report-v2.md` §5: the same
  two error classes from the earlier drills.
- `~/Desktop/orchestrator-drill-evidence-v3.json` / `-v4.json`
  (`negative_tests`).

## Source references (pristine 0.1.5-rc.2)

- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  - `assertAllowedModelSelection` (line ~97): policy miss → one message.
  - `listSubagentModels` exact-model branch (line ~162): the same message.
- `@deepseek-ai/dsh-llm/lib/index.js`
  - `resolveCallWithInfo` (lines ~2120/2124): effort rejection without the
    advertised ladder, although `info.reasoning.efforts` and
    `info.reasoning.defaultEffort` are in hand.

## Live re-verification (2026-09-25, installed bundle with the fix)

Headless runs with a temporary orchestrator-copy preset
(`~/.dsh/.agent-presets/probe-tmp`, deleted afterwards); the user's
`orchestrator` preset was never edited. `agent-presets.default` was overridden
for the run through a temporary headless `--patch` overlay. Tool results
quoted from the lead's reply and the session transcript.

Invented (unserved) model id:

```
Error: LLM provider "opencode-go" does not serve a model with id
"totally-invented-model-xyz" (child LLM route
"opencode-go/totally-invented-model-xyz" is not allowed for this Session)
```

Served but outside the Session's allowed routes (N1/N3 re-run):

```
Error: child LLM route "opencode-go/glm-5.3-flash" is not allowed for this
Session: the provider serves this model id, but it is outside the Session's
allowed routes
```

(identical classification for `mimo-v2.6-pro`.)

Unsupported effort (N2 re-run):

```
Error: provider "opencode-go" model "deepseek-v4.1-flash" does not support
reasoning effort "medium" — supported: low, high, max
```

`(default: …)` is appended when the adapter advertises a default effort; this
model advertises none, so the ladder renders without it. The plain
`does not support reasoning effort` headline is preserved for existing
matchers.

Note: the discovery-tool branch (`list_subagent_models`) carries the identical
classification and is verified by code inspection plus the stacked patch
dry-run; the live run could not reach it because the harness's late preset
mount did not install the per-agent discovery tool in time (an artifact of the
temporary-mount harness, not of the fix).
