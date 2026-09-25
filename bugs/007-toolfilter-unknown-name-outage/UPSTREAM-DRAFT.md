# UPSTREAM DRAFT — one unknown `toolFilter` name kills every spawn, with no earlier signal

Status: NOT-FILED.

---

**Packages:** `@deepseek-ai/dsh-tools` 0.1.5-rc.2,
`@deepseek-ai/dsh-subagent` 0.1.5-rc.2,
`@deepseek-ai/dsh-tool-subagent` 0.1.5-rc.2

## Summary

`tools.restrict()` rejects every name that is not restrictable in the scope,
and the delegation seam calls it during child creation with no guard. A single
unknown name in a delegation row's `toolFilter` therefore aborts **every**
spawn on that row:

```
tools.restrict() names unknown global tools "list_subagent_models", "subagent";
known global tools: ask_user_question, bash, create_goal, edit, … workflow, write
```

Route/effort validation runs before filter construction, so the negative-test
suite stays green while 100 % of delegation is dead (drill v3 measured all 11
rows failing with byte-identical errors). The two names in that drill are
non-restrictable by design: a model-selection delegation row registers its own
`subagent` tool and `list_subagent_models` in each agent's own layer, and
`view()` deliberately excludes a scope's own layer from `restrictableNames` so
a child cannot strip its own answer machinery. There is also no mount-time
validation, so a typo is a runtime outage rather than a boot error.

## Suggested fix

1. In `applyChildComposition` (`dsh-subagent`): on an unknown-name failure,
   drop only the unknown names, warn with the child label and every dropped
   name, and apply the remaining filter. Never leave the child silently
   unrestricted: an all-unknown `allow` list must still restrict to nothing;
   an all-unknown `deny` list still calls `restrict({ deny: [] })` and warns.
2. In `dsh-tool-subagent`: validate `config.toolFilter` before a child starts
   and on `agent/created`, against the calling agent's visible catalog
   (including its own layer, so per-agent registrations are tolerated as
   known-but-non-restrictable), and fail with the loader **row id** and the
   absent names. A row's own registrations are not restrictable in its
   children; document that in the preset guidance.

**Rejected:** making `restrict()` itself tolerant — that weakens the typo
guard for every caller. The tolerant behavior belongs to the delegation seam,
which knows the child context and can name what it dropped.

## Local patch

`bugs/007-toolfilter-unknown-name-outage/` carries both patches, a
`tolerance-check.mjs` (installed-module check for the warning and the
sanitized filters) and live evidence: the v3 list now spawns and drops all 17
restrictable names, and a bogus name fails with the row id.
