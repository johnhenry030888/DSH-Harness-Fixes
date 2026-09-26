# Bug 021 — read-only lanes have no writable temporary directory

Severity: **medium-high**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2
bundle. Upstream: **NOT-FILED**.

## Symptoms

A `readOnly: true` delegation lane (bug 019's guard) running the pinned
command `python3 -m pytest --import-mode=importlib` dies before any test
collects:

```
FileNotFoundError: [Errno 2] No usable temporary directory found in
['/tmp', '/var/tmp', '/usr/tmp', '/…/.p21-live/suite']
```

The v10 review lane worked around it with
`-p no:cacheprovider --capture=sys` — a *different test command*, exactly the
silent drift the pinned-command doctrine exists to prevent (drill v10 §2,
friction #3). From the lead's `danger-full-access` shell the same call
succeeds, so the failure is a sandbox artifact, and nothing in the output said
so.

## Root cause

`readOnly: true` composes the child's session with a `sandbox/mode`
`read-only` override (bug 019). Every local enforcement profile treated
`read-only` as "the whole filesystem, including `/tmp`, may not be written":

- `dsh-sandbox-local` `bwrapProfileArgs`: `--ro-bind / /` with the
  `--tmpfs /tmp` mounted **only** under `workspace-write`.
- `landlockProfileArgs`: read-write grants were `["/dev/null"]` under
  `read-only` (`"/tmp"` appended only under `workspace-write`).
- `seatbeltProfileArgs`: the writable-root list came from `writableRoots`,
  which is deliberately empty under `read-only`.

A process cannot start without a writable scratch dir: CPython's `tempfile`
constructs one during import of any capture/temp user (pytest's capture
machinery is the first caller), and `mkstemp`-family tools probe the same
candidates. Denying the temp area fails *before* the command under test ever
runs, producing a code-shaped traceback for a policy artifact.

## Fix design

The seam gains one meaning — "the temp areas every **confined** mode may
write" — and the three enforcement dialects express it in their own spellings:

1. `@deepseek-ai/dsh-sandbox` (the roots seam) exports
   `tempWriteRoots()`: canonical, deduplicated `["/tmp", os.tmpdir()]`.
   `writableRoots(policy)` is `[workspaceRoot, ...tempWriteRoots()]` under
   `workspace-write` (behavior unchanged) and still `[]` under `read-only` —
   the fs fence's contract is untouched.
2. `@deepseek-ai/dsh-sandbox-local`:
   - **bwrap**: `--tmpfs /tmp` moves out of the `workspace-write` branch into
     the base profile, so *every* confined mode gets a fresh, private,
     mount-namespace-local tmpfs. Nothing is written to the host `/tmp`;
     the tmpfs dies with the sandbox.
   - **Landlock**: `readWrite` is `["/dev/null", ...tempWriteRoots()]` in both
     confined modes (workspace root still appended only under
     `workspace-write`).
   - **Seatbelt** (macOS, parity — untested on this Linux host): under
     `read-only` the profile allows `file-write*` under `tempWriteRoots()`
     instead of nothing.

The workspace stays provably read-only: the kernel fence still denies every
workspace path (verified live, below), and the in-process fs fence
(`dsh-fs-sandbox`) still throws `FS_SANDBOX_DENIED` for `edit`/`write`/
`present` under `read-only` before consulting any root.

## Rejected alternatives

- **Surface a distinct `SANDBOX_NO_TEMP_DIR` error class instead.** The
  `FileNotFoundError` is raised by the *child's own process*, not by the
  sandbox wrap: the sandbox cannot attribute it, and the tool layer would have
  to scrape stderr to classify it. Even classified, the acceptance still
  forces a different test command — the drift is not removed, only explained.
  Fixed the cause instead.
- **Bind a per-session private directory with a lifecycle (the windows-acl
  `materializeAclGrant` shape).** Correct for the Windows dialect, which has
  no mount namespaces; on Linux the per-invocation tmpfs is already private,
  costs no allocation, needs no revocation, and cannot leak on crash.
- **Change `writableRoots()` to include temp roots under `read-only`.** Its
  documented contract is "empty exactly under `read-only`" and it is the
  fs-fence's shared allow-list; overloading it would silently widen Seatbelt
  and blur the mode meaning. A separate `tempWriteRoots()` keeps the seam
  honest.
- **Set `TMPDIR` only (e.g. `--setenv TMPDIR /tmp`).** Covers env-reading
  tools but not hardcoded `/tmp` probes (`tempfile`'s fallback list,
  `/var/tmp` writers). The tmpfs mount covers both without changing the
  child's environment.

## Files patched

- `@deepseek-ai/dsh-sandbox/lib/index.js`
  (`patches/sandbox-temp-roots.patch`)
- `@deepseek-ai/dsh-sandbox-local/lib/index.js`
  (`patches/sandbox-local-temp-mount.patch`)

Neither package carries an earlier local patch, so both patches apply to
pristine 0.1.5-rc.2 sources directly.

## Acceptance evidence

See `EVIDENCE.md`. Live on a temporary `readOnly: true` delegation row
(`--patch` overlay on the headless profile; the user's presets untouched):

- **pre-fix**, the lane's bare pinned command died with the exact
  `No usable temporary directory found` traceback (exit code 1), and a shell
  append was refused with `Read-only file system`;
- **post-fix**, the same lane ran the bare
  `python3 -m pytest --import-mode=importlib` to completion — `3 passed`,
  exit code 0, no `-p no:cacheprovider --capture=sys` workaround — while the
  shell append was still refused and the workspace probe file does not exist;
- an **unconstrained lane** (fork child) still runs the same command and
  writes its scratch file (`FREE`);
- module-level, `scripts/sandbox-temp-check.mjs` pins all three dialects'
  argv/profile shapes and `check.sh` exits 1 pre-fix / 0 post-fix.
