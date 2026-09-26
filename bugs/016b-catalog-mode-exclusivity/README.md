# Bug 016b — `catalog: true` is not mutually exclusive with `provider`/`model`

Severity: **medium** (a silent trap: the mixed call returns a plausible answer
and drops the route arguments). Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2
bundle. Upstream: **NOT-FILED**.

## Symptoms

Drill v14 §1 called the 016 self-query three ways. The standalone paths were
fine, but the mixed calls were **silently accepted**:

```
list_subagent_models({catalog: true, provider: "opencode-go"})
  -> {"count":178,"names":[…178…]}            # no rejection
list_subagent_models({catalog: true, provider: "opencode-go", model: "longcat-2.0"})
  -> {"count":178,"names":[…178…]}            # `model` silently ignored
```

An agent that passes both gets a well-formed answer to a question it did not
ask, and never learns that its route arguments were discarded. Bug 016's README
and tool description both call `catalog` a separate mode; nothing enforced it.

## Root cause

`@deepseek-ai/dsh-tool-subagent` `execute()` returned on the catalog branch
before any route handling ran, and the tool had no mutual-exclusion check
anywhere (`lib/index.js:297` before this patch):

```js
execute(args, exec) {
  if (args.catalog === true) return listAgentCatalog(ctx, exec);
  return listSubagentModels(ctx, policy, args, exec.signal);
}
```

## Fix design

The catalog branch now refuses route arguments by name, in the same voice as the
tool's existing argument errors (`"`model` requires `provider`"`):

```js
if (args.catalog === true) {
  const conflicting = [args.provider === void 0 ? void 0 : "`provider`", args.model === void 0 ? void 0 : "`model`"].filter((name) => name !== void 0);
  if (conflicting.length > 0) throw new Error(`\`catalog\` is mutually exclusive with ${conflicting.join(" and ")} — omit the route query to read this layer's own catalog, or drop \`catalog\` to query routes`);
  return listAgentCatalog(ctx, exec);
}
```

The tool description gains the same rule in prose ("`catalog` is a standalone
mode: it cannot be combined with `provider` or `model`"), so a model can avoid
the call rather than only recover from it. Only names the caller actually passed
appear in the message (`provider` alone, or `provider and model`).

## Rejected alternatives

- **Keep ignoring the route arguments.** That is the shipped behaviour the drill
  caught: the caller cannot distinguish "the catalog answered" from "your route
  query was dropped", which is exactly the class of silent wrongness 016 exists
  to remove.
- **Let `catalog` win and document the precedence.** Cheaper, but it still
  answers a different question than the caller composed; with two modes in one
  parameter set, an explicit error is the only outcome that cannot be misread.
- **Split the catalog query into its own tool.** Cleaner surface, but it changes
  the tool catalog (and therefore every 178/161 count in the drills) for a
  validation detail. The mode already exists and is documented; only its guard
  was missing.

## Files patched

- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-catalog-exclusivity.patch`; stacks on bug 016's
  own patch at the same seam, and therefore on 007/008/009/011/012/019/024)

## Acceptance evidence

See `EVIDENCE.md`. `scripts/check.sh` is marker-based (the guard plus the base
016 query), `scripts/reapply.sh` chains 016 first and is idempotent, the patch
round-trips cleanly (reverse to the 016 state, re-apply, `node --check`), and the
guard was verified **live** on a freshly booted process: both mixed calls return
the named error while the standalone `{catalog: true}` and `{provider}` calls
still answer normally.
