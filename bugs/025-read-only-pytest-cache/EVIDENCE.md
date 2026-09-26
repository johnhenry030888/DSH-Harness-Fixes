# Evidence — bug 025

## Primary evidence (pre-fix)

- `~/Desktop/orchestrator-drill-report-v11.md` §2 (read-only lane check):
  the bare pinned command exits 0 with
  `PytestCacheWarning: could not create cache path …/.pytest_cache/… [Errno 30]
  Read-only file system` as the only noise, and two reviewers carried the
  now-unnecessary `-p no:cacheprovider --capture=sys` workaround.
- Drill v11 §10 friction #5 and §11 recommendation 6:
  "Auto-inject `-p no:cacheprovider` for read-only lanes (or set `cache_dir`
  elsewhere), and update the lane map to drop the workaround."
- `~/Documents/Projects/DSH/ORCHESTRATOR-OPTIMIZATION-PLAN.md` §22.3
  residual 4 / §22.4 (`025`).

## Fix markers (checked by `scripts/check.sh`)

- `function readOnlyPytestAddopts(ambient)`
- `const flag = "-p no:cacheprovider";`
- `return ambient.includes(flag) ? ambient : \`${ambient} ${flag}\`;`
- `...policy?.mode === "read-only" ? { env: { PYTEST_ADDOPTS: readOnlyPytestAddopts(process.env.PYTEST_ADDOPTS) } } : {},`
- the tool-description sentence naming the injected flag.

## Live verification (2026-09-26, installed bundle, headless profile)

Temporary `--patch` overlay adding one `readOnly: true` one-shot row
(`scripts/fixture/ro-row.patch.yml`); suite
`scripts/fixture/test_p25_green.py` copied into the session workspace
`.p25-live/suite/`; session workspace `.p25-live/` removed after the run.
The user's presets were untouched.

Session root:
`~/.dsh/sessions/--home-john-Documents-DSH-Harness-Fixes-.p25-live--/`

### (1) read-only lane — bare pinned command, clean

Child `2cb4c34d-f457-4067-a396-39918bea8f1a`
(descriptor `readOnly: true`, `sandbox/mode` read-only) ran exactly

```
cd suite && python3 -m pytest --import-mode=importlib -q; echo PYTEST_ADDOPTS=$PYTEST_ADDOPTS; (echo probe > .write-probe && echo WRITE-OK) || echo WRITE-REFUSED
```

Raw output, verbatim:

```
...                                                                      [100%]
3 passed in 0.02s
PYTEST_ADDOPTS=-p no:cacheprovider
WRITE-REFUSED
[stderr]
bash: line 1: .write-probe: Read-only file system
```

No `PytestCacheWarning` anywhere in the result.

### (2) write-capable lane — unchanged

Child `25e58a4e-9612-43d7-bec1-341a51c7b84f` (generic `subagent`, foreground)
ran the same three commands. Raw output, verbatim:

```
...                                                                      [100%]
3 passed in 0.02s
PYTEST_ADDOPTS=
WRITE-OK
```

`PYTEST_ADDOPTS` is empty (the ambient value is not exported), pytest's cache
behavior is untouched, and the write succeeds.

## Commands

```bash
bash bugs/025-read-only-pytest-cache/scripts/check.sh

# live (temp overlay only; presets untouched)
cd <session workspace with the suite under ./suite>
dsh --profile headless --patch ./ro-row.patch.yml "<ro lane probe; write lane probe>"

# transcript slice (read-only)
zstd -dc ~/.dsh/sessions/--home-john-Documents-DSH-Harness-Fixes-.p25-live--/2cb4c34d-f457-4067-a396-39918bea8f1a/session.v3.jsonl.zstd \
  | grep -o 'PYTEST_ADDOPTS=[^\\"]*'
```

Footnote (methodology): the first probe placed the suite under `/tmp` and the
read-only lane could not see it — bug 021's private `--tmpfs /tmp` deliberately
shadows the host `/tmp` inside the sandbox. The suite must live in the session
workspace; that is a sandbox property, not a 025 issue, and it is recorded here
so the next probe does not repeat it.
