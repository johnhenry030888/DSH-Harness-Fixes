# Bug 019 — no per-child write scope: workers can modify files they do not own

Severity: **high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

A fork child told explicitly **"Write no files"** edited two lead-owned
deliverables: 7 `edit` calls on the drill report plus a `bash` python rewrite of
the evidence JSON, then `present` (report 29 469 → 35 054 B; JSON 16 849 →
20 049 B). Its edits mixed verified facts with wrong numbers. The leaf
`toolFilter` removes a child's orchestration tools but nothing constrains its
file writes, so file ownership is prompt-only (drill v7 §7 overreach note,
friction #13).

## Fix design (the sanctioned narrower first step)

A per-row `readOnly: true` on a `tool-subagent` row:

1. **Named, path-aware refusal for the file tools.** Child composition installs
   a child-scoped `tools.guard` that denies `edit`, `write` and `present` with
   the child id, the tool, the target path, and `allowed write paths: none`:
   `subagent: read-only child "<id>" refuses tool "edit" for path "<p>": this
   delegation lane is read-only (readOnly: true), so no file may be modified;
   allowed write paths: none. Read the target and report the finding instead.`
2. **Shell mutations refused by the kernel.** The child's session gets a
   `sandbox/mode` override `read-only` with `source: delegation`, so `bash`
   writes fail under the sandbox's own read-only file policy (bwrap on this
   host): `Read-only file system` + `[sandbox: file access denied under
   read-only mode]`. Read-only commands still run.
3. **Durable across cold resume.** `readOnly` is recorded on the descriptor
   (one-shot and continuable) and re-applied by `coldResume`.
4. Unconstrained rows are untouched: no guard, no sandbox override.

## Rejected alternatives

- **Full `writeScope`/`pathScope` globs.** The sandbox modes are whole-mode
  (`read-only` / `workspace-write` / `danger-full-access`) with a single
  workspace root, so per-path globs need a new enforcement dialect across bash
  and fs; the task explicitly allows shipping `readOnly` first. Recorded as the
  follow-up.
- **`tools.restrict()` deny of `edit`/`write`/`present`.** A restricted name
  produces `unknown tool "edit"` — named but not path-aware, and (per v8) some
  models cannot even emit the unregistered name, so the child cannot report
  what it attempted. The guard keeps the tools callable so the refusal is
  visible and specific.
- **Heuristic bash mutation detection.** Parsing shell for mutating commands is
  unsound; the kernel sandbox is the sound refusal.
- **Warn when a child writes outside declared paths.** That is the scoped
  alternative's fallback; with `readOnly` shipping, the warn-only mode was not
  added.

## Files patched

- `@deepseek-ai/dsh-tool-subagent/lib/index.js`
  (`patches/dsh-tool-subagent-read-only-row.patch`, stacks on 007–012)
- `@deepseek-ai/dsh-subagent/lib/index.js`
  (`patches/dsh-subagent-read-only-enforcement.patch`, stacks on 013/018)
- `@deepseek-ai/dsh-subagent-in-process-driver/lib/index.js`
  (`patches/dsh-subagent-in-process-driver-read-only.patch`, stacks on 013/014)

## Acceptance evidence

See `EVIDENCE.md`. Live on a temporary `orchestrator-ro` preset (the user's
preset untouched), with a lead-owned file hash `e9fc5682…` before and after:

- a read-only child's `edit` failed with the named, path-aware error (verbatim,
  child id included);
- its `bash` append was denied by the read-only sandbox;
- an unconstrained child on the same session wrote its own scratch file
  normally;
- the lead-owned file hash was unchanged.
