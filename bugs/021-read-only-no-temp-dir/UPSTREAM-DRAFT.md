# Upstream draft — bug 021

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `read-only` sandbox mode denies the temp directory a process needs:
pytest dies with "No usable temporary directory found"

**Body:**

A `readOnly: true` delegation row (the per-row write scope) runs its child's
shell under `sandbox/mode: read-only`. Every local profile currently treats
that as "the entire filesystem is unwritable", including `/tmp`:

- bwrap mounts `--tmpfs /tmp` only under `workspace-write`;
- the Landlock grants add `/tmp` only under `workspace-write`;
- Seatbelt derives its writable roots from `writableRoots`, empty under
  `read-only`.

That breaks before any user code runs. CPython's `tempfile` constructs a
scratch file during pytest startup (capture machinery), so the pinned test
command

```
python3 -m pytest --import-mode=importlib
```

dies with

```
FileNotFoundError: [Errno 2] No usable temporary directory found in
['/tmp', '/var/tmp', '/usr/tmp', …]
```

and the lane's only way to run tests becomes `-p no:cacheprovider
--capture=sys` — a silent change of the test command that the pinned-command
doctrine exists to prevent (drill v10, friction #3).

Proposal: a confined mode means "no persistent file may be modified", not
"the process loses its scratch space". Add one shared helper —
`tempWriteRoots()` (canonical `["/tmp", os.tmpdir()]`) — and let each dialect
express it:

- bwrap mounts the private ephemeral `--tmpfs /tmp` in every confined mode;
- Landlock adds the temp roots to its read-write grants in every confined
  mode;
- Seatbelt allows `file-write*` under the temp roots under `read-only`.

The workspace stays read-only (bwrap still `--ro-bind / /`, the workspace
bind only under `workspace-write`; the in-process fs fence still refuses
`read-only` mutations outright), and an unconstrained lane is byte-for-byte
unchanged.

Chosen over a distinct `SANDBOX_NO_TEMP_DIR` error class: the failure is
raised in the child's own process, so the sandbox cannot classify it without
stderr scraping, and the class still leaves the lane unable to run its pinned
command.
