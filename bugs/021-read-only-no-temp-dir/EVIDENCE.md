# Evidence — bug 021

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v10.md` §2 (read-only lane check) and
  §10 friction #3: the review lane's pytest run died with
  `FileNotFoundError: [Errno 2] No usable temporary directory found in
  ['/tmp', '/var/tmp', '/usr/tmp']`; the workaround changed the pinned test
  command to `python3 -m pytest --import-mode=importlib -p no:cacheprovider
  --capture=sys`. From the lead's `danger-full-access` shell the same call
  succeeded, so the failure is a sandbox artifact.
- Source: `bwrapProfileArgs` mounted `--tmpfs /tmp` only under
  `workspace-write`; `landlockProfileArgs` granted `/tmp` only under
  `workspace-write`; `seatbeltProfileArgs` derived roots from `writableRoots`,
  empty under `read-only`.

## Fix markers (checked by `scripts/check.sh`)

- `dsh-sandbox`: `function tempWriteRoots()`, `...tempWriteRoots()` in
  `writableRoots`, and the export `tempWriteRoots, validateEscalationArgs`.
- `dsh-sandbox-local`: `const CONFINED_TEMP_DIR = "/tmp"`,
  `CONFINED_TEMP_DIR,` in the bwrap base profile (and the old
  `args.push("--tmpfs", "/tmp")` gone), `"/dev/null", ...tempWriteRoots()`,
  `policy.mode === "read-only" ? tempWriteRoots() : writableRoots(policy)`.

## Module-level check

`node bugs/021-read-only-no-temp-dir/scripts/sandbox-temp-check.mjs` (installed
modules, real `LocalSandboxProvider.confine()` per runner):

```
ok: tempWriteRoots() is non-empty
ok: tempWriteRoots() contains /tmp
ok: writableRoots(read-only) stays empty
ok: bwrap read-only mounts --tmpfs /tmp
ok: bwrap workspace-write still mounts --tmpfs /tmp
ok: bwrap read-only still ro-binds /
ok: bwrap read-only has no workspace bind
ok: bwrap workspace-write binds the workspace
ok: landlock read-only grants --rw /tmp
ok: landlock read-only does not grant the workspace
ok: landlock workspace-write grants the workspace
ok: seatbelt read-only allows file-write under /tmp
ok: seatbelt read-only denies the workspace
SANDBOX-TEMP-CHECK PASS
```

## Live verification (2026-09-26, installed bundle, headless profile)

The headless profile mounts no agent presets, so the Orchestrator preset
cannot be opened there. The read-only row was materialized as a **temporary
`--patch` overlay** (`scripts/fixture/ro-row.patch.yml`, live copy in
`/tmp/opencode/p21-live/`) adding one `@deepseek-ai/dsh-tool-subagent` row
with `readOnly: true` — the same `config.readOnly` → composition →
`sandbox/mode` read-only path the Orchestrator `tool-subagent-review` row
uses. The user's presets were untouched. Fixture:
`scripts/fixture/test_green.py` (3 tests: `TemporaryFile` round-trip,
`mkstemp`+`mkdtemp`, `/tmp` present), copied into the session workspace
(`.p21-live/suite/`) and launched from that directory so the bare command
discovers exactly that suite.

### (1) pre-fix — bare pinned command fails on the read-only lane

Lead `session-9ee21503-c620-4702-9edc-5058939dbd74`, child
`5ec99c10-66e2-41f9-bf0d-43fb7de5b451` (descriptor `readOnly: true`,
`sandbox/mode` read-only). Child tool result verbatim (tail):

```
FileNotFoundError: [Errno 2] No usable temporary directory found in
['/tmp', '/var/tmp', '/usr/tmp',
 '/home/john/Documents/DSH-Harness-Fixes/.p21-live/suite']
[exit code: 1]
```

and the same child's shell append:

```
bash: line 1: .p21-live-write-probe.txt: Read-only file system
[sandbox: file access denied under read-only mode]
[exit code: 1]
```

### (2) post-fix — bare pinned command completes; workspace still read-only

Lead `session-36491edd-349f-4cb6-96b6-6b3e7bcc15ea`, child
`006a5364-3db5-4fa7-80d2-7ecc00a93dd9`. Child `subagent/descriptor`:

```json
{"version":3,"mode":"one-shot","provider":"spawn","label":"Run pytest and write probe","readOnly":true,"inheritedEventCount":0}
```

its `sandbox/mode` events end at `{"mode":"read-only","source":"delegation"}`,
and its tool results are:

```
1. python3 -m pytest --import-mode=importlib        → exit 0
   ============ 3 passed, 1 warning in 0.02s ============
   (the only warning is pytest's own PytestCacheWarning: the workspace
    .pytest_cache is read-only — expected and non-fatal)
2. echo probe >> .p21-live-write-probe.txt          → exit 1
   bash: line 1: .p21-live-write-probe.txt: Read-only file system
   [sandbox: file access denied under read-only mode]
```

`.p21-live/suite/.p21-live-write-probe.txt` does not exist after the run
(confirmed with `ls`), so the workspace mutation never landed.

### (3) unconstrained lane is unchanged

Lead `session-fb0190ac-297a-4dd2-91c0-75615fa1aa53`, fork child
`5a0fce9b-77f9-4dbf-b8d1-79322ef8aebc`: the bare pinned command `3 passed`
(exit 0), `echo FREE > .p21-live-free-probe.txt` exit 0, `cat` returned
`FREE`; the file is on disk (`5 bytes`).

## Commands

```bash
node bugs/021-read-only-no-temp-dir/scripts/sandbox-temp-check.mjs
bash bugs/021-read-only-no-temp-dir/scripts/check.sh

# raw profile reproduction (shared host; no bundle involved)
cd .p21-live/suite
bwrap --ro-bind / / --dev /dev --unshare-pid --proc /proc --die-with-parent \
  -- bash -c "python3 -m pytest --import-mode=importlib"        # pre-fix: exit 1
bwrap --ro-bind / / --dev /dev --unshare-pid --proc /proc --die-with-parent \
  --tmpfs /tmp -- bash -c "python3 -m pytest --import-mode=importlib"  # post-fix: exit 0

# transcripts (read-only)
zstd -dc ~/.dsh/sessions/--home-john-Documents-DSH-Harness-Fixes-.p21-live-suite--/006a5364-3db5-4fa7-80d2-7ecc00a93dd9/session.v3.jsonl.zstd \
  | grep -o '"command":"python3 -m pytest[^"]*"'
```

Live rows/presets used for verification only; the temporary headless row
overlay lives in `/tmp/opencode/p21-live/` and is not part of the fix.
