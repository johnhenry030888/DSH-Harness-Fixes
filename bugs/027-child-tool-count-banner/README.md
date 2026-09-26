# Bug 027 — child layers cannot count their own catalog (banner carries no authoritative count)

Severity: **low** (incorrect self-state: a child asserting a wrong catalog
misleads the lead and the drill's structural probes). Local fix: **APPLIED**
to the `dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

Two consecutive drills produced a wrong child self-count:

- drill v9: a child claimed **137** tools where its own `request/header`
  recorded **161**;
- drill v12 §5.1 / §10 friction #3: a child claimed **157** and asserted that
  `write` was absent, while its header recorded **161** with `write` present.
  Another child conceded its 161 was an unverifiable hand count.

The fix-018 `subagent:layer` banner names the parent and the removed tools but
never states the layer's authoritative advertised count, so every child falls
back to guessing.

## Root cause

The advertised catalog is composed at request time from the tool registry view
(`ToolRuntime.schemas()` / `SystemPrompt.tools()`), and nothing in the child's
model-facing context exposes that count. `restrictChildTools()` reads the same
registry view for the filter (which names it cannot apply), but the banner it
feeds is built from static strings only.

## Fix design

The `subagent:layer` banner gains a lazily composed sentence:

```
This layer advertises <N> tools to its model — the authoritative count its own
request header carries, computed from the same registry view the tool filter
uses. Report this injected number, never a hand-count of an inherited catalog.
```

The count is computed inside the banner's `text(context)` provider, i.e. at
prompt-assembly time for the child's own scope:
`childCtx.tools.view(context.scope ?? scopeOf(childCtx)).visible.size` — the
same `ToolRuntime.view()` the restriction filter reads, so the number tracks
the catalog the request actually advertises (native presentation; the shipped
profiles are native). A child now *reports* the count instead of eliciting it,
which is also what removes the impersonation-adjacent "I think my catalog
is…" guessing the drills kept catching.

## Rejected alternatives

- **Compute the count once at composition time and cache it.** The child's
  catalog is complete at composition, but any later tool registration (a
  plugin mounted during the child's first turn) would silently stale the
  number; the lazy provider costs one registry walk per assembly and can never
  disagree with the request header.
- **Inject the count as a prompt variable (`{{toolCount}}`).** The persona
  prefix is composed before the child's scope exists and the variable registry
  is shared by sections; a per-child variable name would have to be dynamic
  and none of the existing consumers want one. The context provider already
  receives the assembly scope.
- **Answer via the 016 self-query only.** The query serves callers who ask;
  the banner serves every child that never asks (the actual failure mode).
  Both are implemented; they serve different callers.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-banner-tool-count.patch`; stacks on bugs
  007/013/017/018/019/023/026 of the same file)

## Acceptance evidence

See `EVIDENCE.md`. Live: a direct child, a workflow worker and a fork child
each report a count identical to their own `request/header` tool array and
cite the banner as the source; one of them states it unprompted.
