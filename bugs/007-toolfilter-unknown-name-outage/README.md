# Bug 007 — one unknown name in `toolFilter` kills every spawn, with no earlier signal

Severity: **high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

A `toolFilter` deny list containing `subagent` and `list_subagent_models` made
**all 11 delegation rows fail at spawn** (drill v3 §2, §3a):

```
tools.restrict() names unknown global tools "list_subagent_models", "subagent";
known global tools: ask_user_question, bash, create_goal, edit, … workflow, write
```

Route/effort validation runs *before* filter construction, so N1/N2/N3 kept
returning their intended errors while 100 % of real delegation was dead — a
green negative-test suite on a dead layer (the drill's "most dangerous
property"). The two names are non-restrictable because a model-selection
delegation row registers its own `subagent` tool and `list_subagent_models` in
each agent's **own** layer, which `tools.view()` deliberately excludes from
`restrictableNames` (a child must not be able to strip its own answer
machinery).

## Root cause

- `@deepseek-ai/dsh-tools` `restrict()` throws on any unknown name
  (`lib/index.js:2803`).
- `@deepseek-ai/dsh-subagent` calls it during child creation
  (`applyChildComposition`, `lib/index.js:542`/`554`) with no guard and no
  mount-time validation.

## Fix design (two layers)

1. **Tolerant child composition** (`@deepseek-ai/dsh-subagent`,
   `restrictChildTools`): compute the child scope's `restrictableNames`,
   partition the filter into known/unknown, warn with the child label and
   **every** dropped name, and apply the remaining filter. The child is never
   silently unrestricted: an all-unknown `allow` list still restricts to
   nothing (fail-closed), an all-unknown `deny` list still calls
   `restrict({deny: []})` (explicit no-op) and warns loudly. `applyChildComposition`
   gained an optional `label` parameter so the warning names the child's
   durable id (the call site passes `childId`).
2. **Row-identified pre-spawn validation** (`@deepseek-ai/dsh-tool-subagent`,
   `assertKnownToolFilterNames`): every configured filter is checked against
   the calling agent's visible catalog — where the complete surface exists —
   before a child is started, and again on every `agent/created` (the boot-time
   arm for a standing composition). A name that resolves nowhere fails with the
   **loader row id** and the offending names:
   `tool-subagent: row "…" toolFilter names a tool absent from the child
   catalog: "…" — correct the name or remove it from the filter`.
   This row's own registrations (`toolName`, and `list_subagent_models` when
   model selection is enabled) are tolerated by the check, because they are
   known-but-non-restrictable: the composition drops them with the warning
   instead of failing the spawn.

**Child-scope semantics.** The check deliberately mirrors what `restrict()`
will see in a child: the calling agent's catalog including its own layer, so
per-agent registrations are *known* (tolerated, dropped later with a warning)
while a typo is *unknown* (fails with the row id). The README of the preset
should keep the corrected comment: never add `subagent` or
`list_subagent_models` to a `toolFilter` — they cannot be restricted.

**Why the boot-time arm cannot be a literal standing-mount failure.** The
loader starts a composition's rows concurrently (`EntryGroup.update` uses
`Promise.allSettled` over all rows), so while a row's `apply()` runs the
registry cannot answer for a sibling row's tool. A mount-time registry check
would reject the user's valid preset (`workflow`, `ralph`, the pins). The
`agent/created` arm runs after the standing mount is complete; a synchronous
listener throw there fails agent creation, which is the earliest sound
"mount" point. The delegation arm is the hard failure at first use.

## Rejected alternatives

- **Make `restrict()` itself tolerant.** Rejected: it would weaken the typo
  guard for every caller (tools, presets, tests) to fix one caller. The
  tolerant behavior belongs to the delegation seam, which has the context to
  warn about dropped names.
- **Validate only at child creation.** Rejected as the sole guard: the failure
  would still be a runtime outage per row, with no row id. The pre-spawn and
  boot arms name the offending row.
- **Validate `toolFilter` at the row's own `apply()` against the live
  registry.** Rejected: rows mount concurrently and the view is incomplete, so
  this false-fails every valid preset that names a later row's tool (verified
  by a probe that saw all 34 names only because its own import resolved last).
- **Fail the boot for `subagent`/`list_subagent_models`.** Rejected by the
  acceptance itself: the v3 list must still spawn (with a warning naming both),
  because those names are known tools that are merely non-restrictable.
- **Trim the filter inside `dsh-tools.restrict()` and return the dropped
  list.** Rejected: changes a public contract to serve one internal caller;
  the caller can compute the same partition from `view()`.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-tolerant-child-filter.patch`)
- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-filter-validation.patch`) — first patch of a
  three-patch stack on this file; bugs 008 and 009 stack on top.

## Acceptance evidence

- `scripts/check.sh` exit 1 before, 0 after; `reapply.sh` idempotent; the
  stacked patches dry-run clean in order (007 → 008 → 009) and `node --check`
  passes on the final file.
- `scripts/tolerance-check.mjs` (installed bundle, module-level):
  - v3-like deny list → warning names `child-123` and `"subagent"`,
    `"list_subagent_models"`, `"not_a_tool"`; `restrict({deny:["workflow"]})`;
  - all-unknown deny list → warning + `restrict({deny:[]})`;
  - partial allow list → warning + `restrict({allow:["bash"]})`.
- Live (headless with a temporary copy of the preset, `probe-tmp`):
  - v3 deny list on the generic row → child spawned (replied `READY`), route
    `space-bunny-free @ medium`; the child's request header omitted all 17
    restrictable names and kept only its own `subagent`/`list_subagent_models`;
  - a bogus name (`subagnt_fast`) → the call failed with
    `tool-subagent: row "include:agent-presets:tool-subagent" toolFilter names
    a tool absent from the child catalog: "subagnt_fast" — correct the name or
    remove it from the filter`.
