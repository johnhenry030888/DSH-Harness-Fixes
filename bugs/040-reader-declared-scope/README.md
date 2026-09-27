# Bug 040 — a reader's declared read scope must not be erased by the incidental-mention filter

Severity: **medium-high** (the fail-closed ordering guard refuses a delegation
that did declare a read scope — a false refusal in the common `/tmp` scratch
case). Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle. Upstream:
**NOT-FILED**.

## Symptoms

Drill **v27 §6 F2** (verbatim): "a reader that declares `/tmp/` as its read
scope is classified `declared no read scope … (scopeBasis: maximal)`, so it is
refused as maximally scoped while writers are live; only an outside-the-root
tree (e.g. the archive dir) demonstrated admission". The failed delegation's
prompt was:

```
Read only the /tmp scratch area.
Your read scope is declared as: /tmp/
Check whether the file /tmp/dsh-v27-sentinel.txt exists right now …
```

Both path mentions were dropped by the incidental filter (the context contains
`scratch` and `sentinel`), so bug 031's fail-closed guard refused it as
maximal even though the delegation declared a scope.

## Root cause

`dsh-subagent/lib/index.js` (post-031/032):

- `DECLARED_PATH_INCIDENTAL` (~1884) marks a mention incidental when its
  80-char context contains `sentinel|scratch|timestamp|marker|read-only|…`;
- `declaredTreePaths()` (~1897) applies that filter to **every** mention;
- the writer side `declaredWorkOfSession()` (~1924, reading the child's first
  user message) and the reader side `declaredPromptTrees()` (~1963, reading the
  delegation's prompt) share it;
- `assertInspectionOrdering()` (~2051) therefore harvested `[]` for the v27
  reader, computed `scopeBasis: "maximal"` (~2055) and threw the 031 maximal
  refusal.

032's filter exists for the writer case (v26 A3: a writer that only mentions
`/tmp` and `/tmp/v26_tstart` as a sentinel must not be treated as declaring
work there), but applied to the reader side it erases a genuine declaration.

## Fix design

`dsh-subagent/lib/index.js`:

1. **Reader-side cue precedence.** A new `READ_SCOPE_CUE` regex recognises
   explicit declarations (`read scope`, `only read`, `read only`,
   `read/reads from`, `scope:`/`scope is`, `limited to`, `restricted to`); a
   new `declaredReadScopePaths(text)` harvests every path from the earliest cue
   to the end of the text block as declared, whatever incidental words
   surround it. Without a cue the bug-032 incidental rule still applies.
   `declaredPromptScope(prompt)` unions the per-block results;
   `declaredPromptTrees(prompt)` remains a thin wrapper.
2. **The dropped list is named.** Mentions the reader-side harvest dropped as
   incidental are returned as `dropped`; when nothing was declared, the 031
   maximal refusal now reads `… declared no read scope (2 path mentions were
   ignored as incidental/scratch: "/tmp/a", "/tmp/b"): it is treated as …`,
   and the durable `subagent/inspection-scope` record carries
   `droppedIncidental`.
3. **Scratch roots are declarable.** A declaration under `/tmp` is treated
   exactly like one under the workspace: overlapping a live writer's declared
   `/tmp` path refuses naming the pair; disjoint is admitted. (`/tmp` was
   never in `DECLARED_PATH_ROOTS`; the incidental words were the only reason
   it was dropped.)
4. **The writer side is untouched** — `declaredTreePaths()` still drops
   sentinel/scratch/negative mentions, so the v26 A3 case keeps passing; 031's
   maximal default and the retry guidance are unchanged, and 032's pair-naming
   refusal text is unchanged.

## Rejected alternatives

- **Weaken the writer-side filter (e.g. drop the scratch/sentinel words).**
  Re-opens v26 A3: a writer that merely mentions a scratch sentinel becomes a
  declared writer on `/tmp` and blocks unrelated readers.
- **Allow `/tmp` in `DECLARED_PATH_ROOTS`.** Wrong direction: the roots list
  drops *mentions* (system prefixes every prompt names), while the reader's
  problem is that a *declaration* was dropped. It would also keep erasing
  workspace declarations whose path text contains "scratch".
- **Special-case `/tmp` in the incidental regex.** Whack-a-mole: the same
  false refusal occurs for `/home/.../scratch/...` and for any path near the
  word "sentinel"; the cue is the semantically correct signal.
- **Require the cue for every declaration (drop non-cued declarations).**
  Breaks the 023/026 behaviour of declaring by naming paths plainly and would
  refuse readers that name their scope without a keyword.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-reader-declared-scope.patch`; stacks on bugs
  031/032 of the same guard region).

## Acceptance evidence

`EVIDENCE.md`: the module probe `scripts/guard-reader-scope-check.mjs` runs the
five required cases (a–e) plus the exact v27 prompt and the cue forms — 9
failures pre-fix, all green post-fix; the live probe
`scripts/reader-scope-probe.sh` shows a live writer + declared `/tmp` reader
admitted, the overlapping declaration refused naming the pair, and the same
declaration admitted after settlement, with the durable
`subagent/inspection-scope` records quoted through the bug-039 reader; the
batch 6–7 probes (`031` guard-scope, `032` guard-pair) still pass.
