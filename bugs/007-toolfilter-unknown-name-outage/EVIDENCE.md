# Evidence — bug 007

## Primary evidence (reports)

- `~/Desktop/orchestrator-drill-report-v3.md` §2, §3a, §8 friction 1:
  - all 11 delegation rows failed at spawn with (verbatim):
    `tools.restrict() names unknown global tools "list_subagent_models",
    "subagent"; known global tools: ask_user_question, bash, create_goal, …
    workflow, write`;
  - ordering evidence: "Stages run in this order: **argument validation →
    route/effort validation → toolFilter construction**", so N1/N2/N3 stayed
    green while every lane was dead.
- `~/Desktop/orchestrator-drill-report-v4.md` §4a: with the deny list reduced
  to the 17 restrictable names, direct children have no `send_message`, no
  pins, no `workflow`, no goal tools — the layer works once constructed.
- `~/Documents/Projects/DSH/ORCHESTRATOR-OPTIMIZATION-PLAN.md` §13.1–13.5
  ("`tools.restrict()` rejects unknown names instead of ignoring them, and
  those two are not restrictable"; gap 2: "a tolerant branch, or a boot-time
  preset invariant that constructs every row's filter and names the offending
  row").
- `~/Desktop/orchestrator-drill-evidence-v3.json` (lane matrix, all FAIL).

## Source references (pristine 0.1.5-rc.2)

- `@deepseek-ai/dsh-tools/lib/index.js:2803` — `restrict()` throws on unknown
  names; `view(scope).restrictableNames` excludes the scope's own layer.
- `@deepseek-ai/dsh-subagent/lib/index.js:542`/`554` —
  `applyChildComposition()` called `restrict()` unguarded.
- `@deepseek-ai/dsh-tool-subagent/lib/index.js` —
  - `modelSelectionSettings === true` rows install their tool per agent
    (`installScoped` → `candidate.ctx.inject(...)`), which is why bare
    `subagent` and `list_subagent_models` live in each agent's own layer;
  - the v3 failure came from `applyChildComposition`, not from `apply()`.

## Live re-verification (2026-09-25, installed bundle with the fix)

### Module-level (`scripts/tolerance-check.mjs`, installed `dsh-subagent`)

```
v3-like deny list
  warning: subagent: child child-123 toolFilter names tools that cannot be
           restricted in its scope (dropped from the filter): "subagent",
           "list_subagent_models", "not_a_tool"; …
  restricted: [{ deny: ["workflow"] }]
all-unknown deny list
  warning names "subagent", "list_subagent_models"
  restricted: [{ deny: [] }]          # explicit no-op, never silent
partial allow list
  warning names "subagent"
  restricted: [{ allow: ["bash"] }]   # fail-closed remainder
TOLERANCE-CHECK PASS
```

### Live delegation (`probe-tmp`, a temporary copy of the orchestrator preset)

The generic row's deny list was replaced by the **v3 list** (the 17 restrictable
names plus `list_subagent_models` and `subagent`), then a headless session was
mounted on it (temporary preset, `agent-presets.default` overridden via a
temporary headless `--patch`; the user's `orchestrator` preset untouched).

- Child spawned and replied `READY` (route `opencode-go/space-bunny-free @
  medium`, from the child's `request/header`).
- Child's request header tool names: `send_message`, `list_agents`,
  `interrupt_agent`, all eight pins, `workflow`, `ralph`, `create_goal`,
  `get_goal`, `update_goal`, `ask_user_question` — all **ABSENT**;
  `subagent` and `list_subagent_models` — PRESENT (own-layer, correctly
  non-restrictable).
- The tolerant warning (`ctx.logger.warn`) is exercised and captured by the
  module-level check; the plain headless profile has no log sink, so it is not
  visible on stderr there.

### Bogus name

Same temporary preset with `subagent_fast` → `subagnt_fast` in the generic
row's deny list. The first delegation failed verbatim:

```
Error: tool-subagent: row "include:agent-presets:tool-subagent" toolFilter
names a tool absent from the child catalog: "subagnt_fast" — correct the name
or remove it from the filter
```

On the plain headless host (where the pins are genuinely absent), the same
check fails agent creation at boot, naming the row
(`include:tool-subagent`) and every absent name — see the transcript of
`--patch /tmp/opencode/livecheck/007a.yml` (exit 1, no session created).

### Valid filters unchanged

The user's `orchestrator` preset keeps its 17-name deny lists and mounts; the
regression check is that all 11 rows still construct (drill v5 preflight).

### `scripts/drill-007-probe.sh` — re-runnable live probe (2026-09-26)

Run in a scratch harness home (`/tmp/orch-drill-007/home`, real `~/.dsh` only
read) with a targeted overlay on the headless profile's own delegation row.
Observed on the installed 0.1.5-rc.2 bundle:

```
variant A — filter drops present names plus the non-restrictable subagent
  PASS  delegation survived the non-restrictable name (child replied READY)
  PASS  no unknown-name failure for a name the child scope cannot restrict
  child tools: bash,edit,job_kill,job_list,job_output,read,write
  PASS  the filter really applied: the child's catalog dropped the restrictable names
variant B — same list with subagnt_fast (typo)
  PASS  the typo is named in the failure
  PASS  the failure names the offending loader row
  PASS  no child session was created on the poisoned filter (exit 0)
bug-007 live probe: PASS (both variants)
```

Variant B's verbatim error:

```
Error: tool-subagent: row "include:tool-subagent" toolFilter names a tool
absent from the child catalog: "subagnt_fast" — correct the name or remove it
from the filter
```

Why the list is not the preset's 17-name one: those names are the *pins*, which
the headless host does not compose, so the pre-spawn check would flag them as
absent for the wrong reason (observed, then corrected). Why `list_subagent_models`
is absent from the live list: enabling model selection on a standing row is
rejected (`tool-subagent: standing \`modelSelectionSettings\` requires a scoped
preset Context`), so that name stays unit-verified in `tolerance-check.mjs`.
