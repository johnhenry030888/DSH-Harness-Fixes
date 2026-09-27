# Evidence — bug 036

## Primary evidence (pre-fix)

- Drill **v16 F2 / v17 §5**: live rows rendered the child's session cwd while
  the delegation's declared target was a drill subpath.
- Drill **v20 F2 / v21 §5 item 4 / v22 §5 item 4**: the same misread recurred
  across waves.
- Drill **v26 §5 item 4**: "at 19:09:42 all 11 direct children were `ready`,
  and **every row carried only id + status + label — no file-policy field and
  no working-tree field at all**"; §6 item 4: "`list_agents` row tree = session
  cwd — RUN this time … changed / not observable."
- The preset's own doctrine (v15 friction #1): "A row's `[writes in …]` tree is
  the child's **session cwd**, not the target its prompt declared … the
  harness's own ordering guard uses the declared paths, the display does not."

## Fix markers (checked by `scripts/check.sh`)

- `dsh-subagent`: `declaredWorkOf(agent) {`, `return declaredWorkOf(agent);`.
- `dsh-subagent/lib/types/index.d.ts`: `declaredWorkOf(agent: Agent): {`.
- `dsh-tool-subagent-control/lib/types/list-agents.js`:
  `subagents.declaredWorkOf({ session })`, `treeBasis: declared.basis`,
  `const session = live === undefined ? sessions?.get(entry.id) : live.session;`,
  `const sessions = ctx.get('sessions');`, plus the preserved 023 markers
  `filePolicy: sandboxPolicy.overrideOf(live.session) === 'read-only' ? 'read-only' : 'writes'`
  and `entry.filePolicy`.

## Before/after check output

```
$ (pre-036: 031/032 applied) DSH_AGENT_BASE=/tmp/opencode/shadow036 bash bugs/036-.../scripts/check.sh
missing: return declaredWorkOf(agent); (in lib)
missing: declaredWorkOf(agent: Agent): { (in types)
missing: subagents.declaredWorkOf({ session }) (in types)
missing: treeBasis: declared.basis (in types)
missing: const session = live === undefined ? sessions?.get(entry.id) : live.session; (in types)
missing: const sessions = ctx.get('sessions'); (in types)
bug-036 fix MISSING
exit=1

$ (installed) bash bugs/036-.../scripts/check.sh
bug-036 fix PRESENT
exit=0
```

## Live probe (scratch `DSH_HOME`, real `~/.dsh` untouched)

`scripts/list-agents-probe.sh` starts one continuable child told to write an
absolute drill subpath and reads the lead's `list_agents` tool result.

```
bug 036 live probe — scratch home /tmp/orch-drill-036/home

    | 80c2dbb8-0102-44c9-8683-2d226784694c [running as of 2026-09-27T20:54:48.435Z] — tree probe [writes in /tmp/orch-drill-036/declared/sub/file.txt (declared)]
    | ```
    | 
    | TREE-PROBE-DONE

  list_agents row: '80c2dbb8-0102-44c9-8683-2d226784694c [running as of 2026-09-27T20:54:48.435Z] — tree probe [writes in /tmp/orch-drill-036/declared/sub/file.txt (declared)]'
  PASS  the row renders the declared target path
  PASS  the row labels the declared basis
  PASS  the row keeps the file policy
  PASS  the row keeps checkedAt

bug-036 live probe: PASS
scratch home kept for inspection: /tmp/orch-drill-036
```

The row shows the declared path, the `(declared)` basis, the `writes` policy,
and `checkedAt`; the pre-fix row would have shown
`[writes in /home/john/Documents/DSH-Harness-Fixes]` (the session cwd).

## Patch round-trip

```
forward apply (031->032->036->033->034->035) == installed bundle: OK
reverse apply (035->034->033->036->032->031) == pre-batch baseline: OK
ROUNDTRIP PASS
```

`scripts/reapply.sh` chains 032 (and thus 031) and 023, and is idempotent
(verified twice on a shadow bundle).

## Verification limits (disclosed)

- The settled-row declared tree depends on the durable Session being loaded
  (`ctx.get('sessions')`); when it is not, the row omits `tree`/`treeBasis`,
  which the tool description now states. The live probe covers the live row.
- The guard's own read/write semantics are unchanged: `list_agents` renders
  the same `declaredWorkOf` the ordering guard consumes.
