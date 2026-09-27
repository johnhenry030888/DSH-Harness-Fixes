# Bug 032 — the guard reports collapsed ancestors and merely-touched paths, and refuses disjoint scopes

Severity: **high** (two drills lost a whole wave to false refusals; the
reciprocal false negative is bug 031). Local fix: **APPLIED** to the
`dsh` 0.1.5-rc.2 bundle. Upstream: **NOT-FILED**.

## Symptoms

- Drill v21 §4.2, v23 §4.2, v26 §5 + Appendix A2: refusals reported the
  writer's "declared work" as a **common ancestor** (the drill root) while the
  genuine declared targets were subpaths.
- Drill v26 §5 + Appendix A3: a **genuinely disjoint** read scope was refused,
  reporting the writer's declared work as `/tmp/v26_tstart` — a path the
  writer merely touched as a timestamp sentinel — and `/tmp` — a scratch
  mention. Two drills lost a whole wave to false refusals.

## Root cause

`dsh-subagent/lib/index.js`:

- `declaredTreePaths()` (~1791 pre-fix) harvested **every** absolute path in
  the text, including prohibition mentions ("do not write /tmp"), sentinel /
  scratch / timestamp mentions, and every ancestor a prompt named as context;
- `declaredTreesOf()` (~1814) fed that unfiltered set straight into the
  conflict loop, so a merely-touched `/tmp/v26_tstart` counted as declared
  work and the drill root counted alongside its own subpaths;
- the conflict loop (~1860–1885) and the message builder therefore reported a
  path that was never the writer's declared target.

## Fix design

`dsh-subagent/lib/index.js`:

1. **Declared work, not every path.** `DECLARED_PATH_INCIDENTAL` drops a path
   mention whose 80-char context carries a prohibition verb ("do not write",
   "never modify", "avoid …"), a read-only framing, or a
   sentinel/scratch/timestamp/marker purpose.
2. **Most specific path per mention chain.** `mostSpecificPaths()` drops a
   declared ancestor when the same text also declares a strict descendant —
   the descendant is the actual target.
3. **Declared reader × declared writer only.** The conflict loop consumes the
   shared `declaredWorkOf(candidate)` harvester on the writer side; the reader
   side is the delegation prompt's declared paths. A path the writer never
   declared cannot cause a refusal. A writer that declares none keeps the
   023/026 conservative workspace fallback (documented, not silent).
4. **The message names the actual pair.** The refusal carries the writer id,
   the writer's declared path, the reader's declared path, and
   `scopeBasis`/`writerBasis` so the caller can see how the decision was made.
   The existing retry guidance sentence is preserved verbatim.

Documented v26 examples:

| input | pre-fix | post-fix |
|---|---|---|
| writer "Do not write outside /tmp. Sentinel: /tmp/v26_tstart …" | declared work `["/tmp","/tmp/v26_tstart"]` | filtered → workspace fallback |
| writer "The drill root /drill is context; the target is /drill/sub-a/file.txt" | declared work includes `/drill` | `["/drill/sub-a/file.txt"]` |
| reader `/drill/sub-b` vs the above writer | refused (root overlap) | admitted |

## Rejected alternatives

- **Whitelist only "write …" mentions.** Misses prompts that declare work
  without the verb ("your files are under X") and misreads negations
  ("do not write X" contains "write X").
- **Drop every ancestor and keep only leaves.** Would silently narrow a writer
  that legitimately owns a tree and mentions one file in it; the
  most-specific rule only collapses a set the same prompt declared.
- **Parse shell variables / relative paths on the writer side.** The 026 probe
  pins relative paths as ignored; interpreting them would re-open the false
  positives this bug is about.
- **Report every conflict pair in the message.** The refusal already names
  every conflicting child; the message names the first actual pair (the same
  one the caller must resolve first) to stay bounded.

## Files patched

- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-declared-pair-overlap.patch`; stacks on bug 031 of
  the same file)

## Acceptance evidence

`EVIDENCE.md`: `scripts/guard-pair-check.mjs` runs the three required cases
plus the two v26 reconstructions — pre-fix it refuses the sentinel/disjoint
cases and collapses the root; post-fix all pass. `scripts/check.sh` exit 1
pre-fix, 0 post-fix; patches round-trip.
