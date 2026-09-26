# Bug 025 — read-only lanes still emit a pytest cache warning

Severity: **low**. Local fix: **APPLIED** to the `dsh` 0.1.5-rc.2 bundle.
Upstream: **NOT-FILED**.

## Symptoms

After bug 021 gave read-only lanes a writable temp area, the bare pinned test
command works — but every run still prints

```
PytestCacheWarning: could not create cache path …/.pytest_cache/… [Errno 30] Read-only file system
```

because pytest's cache provider probes the (correctly) unwritable workspace.
Drill v11 §2 records the noise, and §10 friction #5 / §11 recommendation 6
record the follow-on: two read-only reviewers *still* carried the
now-unnecessary `-p no:cacheprovider --capture=sys` workaround, i.e. the
warning keeps pushing lanes back toward a non-pinned command.

## Root cause

The read-only lane's shell runs with a read-only file policy (bug 019's
delegation `sandbox/mode`, enforced by the sandbox dialects). Nothing tells
pytest not to use its on-disk cache, and the tool that owns the shell call
(`dsh-tool-bash`) never set `PYTEST_ADDOPTS`.

## Fix design

The shell tool already resolves the per-call sandbox policy before it spawns,
so it is the seam that knows the command will run read-only:

- `readOnlyPytestAddopts(ambient)` returns `-p no:cacheprovider`, preserving
  and appending to any inherited `PYTEST_ADDOPTS` (idempotent if the flag is
  already present).
- `execute` adds `env: { PYTEST_ADDOPTS: … }` to the subprocess request **only
  when `policy.mode === "read-only"`**; the subprocess layer merges it over
  the scrubbed parent environment, so a wider mode (including a one-shot
  escalation) leaves the environment byte-for-byte untouched.
- the tool description documents the behavior whenever a confining executor
  is mounted, so the pinned command stays `python3 -m pytest --import-mode=importlib`.

Scope note: the same condition exists for `pwsh` on Windows; this host is
Linux and the pinned lane command is bash, so only `dsh-tool-bash` is patched
(disclosed rather than half-done).

## Rejected alternatives

- **Point pytest's cache dir at the lane temp area (`--cache-clear` + config).**
  Needs an env/config write into the workspace the lane cannot write, or a
  `-o cache_dir=` value that still varies per lane; the flag is the documented
  supported switch and costs nothing.
- **Inject `PYTEST_ADDOPTS` in the sandbox provider.** The provider returns
  argv only; it does not own the spawn environment (and its windows-acl rung
  has no env channel). The tool that builds the request owns the env.
- **Filter the warning out of the result rendering.** Hides the symptom,
  leaves the workaround pressure.
- **Set the variable for every mode.** A write-capable lane would silently
  lose pytest's cache (and the drill explicitly requires it unchanged).

## Files patched

- `@deepseek-ai/dsh-tool-bash/lib/index.js`
  (`patches/dsh-tool-bash-read-only-pytest-addopts.patch`; no earlier local
  patch, applies to pristine 0.1.5-rc.2 directly)

## Writing a discriminating assertion for this fix (drill v15 friction #2)

The obvious test — `assert not os.path.exists(".pytest_cache")` — is
**self-invalidating**: the falsification run (the same suite deliberately
executed *without* the injected flag) creates that very directory, after which
the test fails forever in that directory and looks exactly like a harness
regression. Assert the **plugin state** instead:

```python
def test_cacheprovider_is_disabled(request):
    assert request.config.pluginmanager.has_plugin("cacheprovider") is False
```

Drill v15 used this form and falsified both ways: without the injected flag it
fails (`cacheprovider is still registered`), with `-p no:cacheprovider` it
passes. The directory form would have passed the *falsification* run and failed
the real one on every later run.

## Acceptance evidence

See `EVIDENCE.md`. Live on a temporary headless overlay adding a `readOnly:
true` row (the Orchestrator `tool-subagent-review` row shape; the user's
presets untouched), same suite in the session workspace:

- read-only lane, bare pinned
  `python3 -m pytest --import-mode=importlib`: `3 passed`, exit 0, **no
  cache warning**; `PYTEST_ADDOPTS=-p no:cacheprovider`; the workspace write
  probe still fails (`Read-only file system`);
- write-capable lane, same command: `3 passed`, `PYTEST_ADDOPTS` empty, and
  its write probe succeeds — unchanged.
