# Evidence — bug 019

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v7.md` §7 overreach note and §9 friction
  #13: the fork child told "Write no files" made 7 `edit` calls on
  `orchestrator-drill-report-v7.md` (29 469 → 35 054 B), a `bash` python rewrite
  of `orchestrator-drill-evidence-v7.json` (16 849 → 20 049 B), then `present`.
- `~/Desktop/orchestrator-drill-report-v8.md` §7: no child wrote lead-owned
  files (prompt discipline held), and §11 records the ownership gap as
  unresolved.
- Source: `applyChildComposition` applied `toolFilter` only; no write guard and
  no path scope existed anywhere in the delegation path.

## Fix markers (checked by `scripts/check.sh`)

- `readOnly: z.boolean().default(false)` and
  `...config.readOnly === true ? { readOnly: true } : {}` in
  `dsh-tool-subagent`;
- `read-only child`, `allowed write paths: none`,
  `childCtx.tools.guard((exec) => {`, `mode: "read-only"`,
  `readOnly: descriptor.readOnly`, `readOnly: request.readOnly` in
  `dsh-subagent`;
- `readOnly: request.readOnly` in `dsh-subagent-in-process-driver`.

## Live re-verification (2026-09-26, installed bundle, `dsh web`)

Temporary preset `~/.dsh/.agent-presets/orchestrator-ro` (a copy of the user's
`orchestrator` with `readOnly: true` on the `tool-subagent-verify` row; the
user's preset untouched). Session
`session-8b1795be-5297-4569-8afb-b61de3830cf0` on `orchestrator-ro`.
Lead-owned fixture: `/tmp/opencode/p11-14/lead-owned/deliverable.txt`,
sha256 `e9fc56827dc8b45988c82280f959b114b1291234205fa38dd6716bbfca99a212`
(hashed before, between, and after every probe — unchanged).

### (1) read-only child, `edit` on the lead-owned file

Child `e4b2d67e-a6ab-4a2b-9a80-213ab17caab5` (continuable `subagent_verify`),
tool result verbatim:

```
Error: subagent: read-only child "e4b2d67e-a6ab-4a2b-9a80-213ab17caab5" refuses tool "edit": this delegation lane is read-only (readOnly: true), so no file may be modified; allowed write paths: none. Read the target and report the finding instead.
```

(An earlier run of the same probe, before the child-id label was wired through
the driver, showed the same refusal with `"(unlabeled)"`.)

### (2) read-only child, `bash` append to the same file

Child `24900c3c-5824-476f-a4d5-82e533134e16`, tool result verbatim:

```
[stderr]
bash: line 1: /tmp/opencode/p11-14/lead-owned/deliverable.txt: Read-only file system
[sandbox: file access denied under read-only mode]
[sandbox: escalation available — retry this exact command once with sandbox_permissions (the narrowest wider mode that suffices) + justification; the approval prompt asks the user]
[exit code: 1]
```

### (3) unconstrained child behaves as today

Child `db62c697-2751-45b6-892e-d943ba1e5b0d` (`subagent_mech`, no `readOnly`)
wrote its own scratch file with the `write` tool:

```
<path>/tmp/opencode/p11-14/scratch/free.txt</path>
<content>
Created file
</content>
```

`/tmp/opencode/p11-14/scratch/free.txt` contains `FREE`.

### Module-level guard check

`scripts/read-only-check.mjs` (installed modules, stub composition context):

```
editRefusal: "subagent: read-only child \"child-ro-1\" refuses tool \"edit\" for path \"/tmp/lead-owned.md\": … allowed write paths: none. …"
writeRefusal / presentRefusal: same class; bashAllowed: undefined; freeEdit: undefined
readOnlyContext: "… This layer is read-only: edit, write and present are refused, and shell commands run under a read-only file policy …"
READ-ONLY-CHECK PASS
```

## Commands

```bash
node bugs/019-child-write-scope/scripts/read-only-check.mjs
zstd -dc ~/.dsh/sessions/--home-john-Documents-Projects-DSH--/e4b2d67e-a6ab-4a2b-9a80-213ab17caab5/session.v3.jsonl.zstd \
  | grep -o 'read-only child[^"]*'
sha256sum /tmp/opencode/p11-14/lead-owned/deliverable.txt
```
