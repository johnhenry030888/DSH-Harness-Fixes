# Upstream draft — bug 025

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** Read-only lanes emit `PytestCacheWarning` on every bare pytest run
(and push reviewers back to a non-pinned command)

**Body:**

After `read-only` mode gained a writable temp area, the pinned command

```
python3 -m pytest --import-mode=importlib
```

runs cleanly in a `readOnly: true` delegation lane — except for a warning on
every invocation:

```
PytestCacheWarning: could not create cache path …/.pytest_cache/… [Errno 30]
Read-only file system
```

The warning is harmless, but it is load-bearing in the wrong direction: two
read-only reviewers in the follow-up drill carried the older
`-p no:cacheprovider --capture=sys` workaround *after* it was no longer
needed, i.e. the noise keeps the pinned command from being the command lanes
actually run.

Proposal: the tool that owns the shell call (`dsh-tool-bash`) already resolves
the per-call sandbox policy, so a read-only policy should export the flag the
tool itself would otherwise force reviewers to remember:

```
PYTEST_ADDOPTS="-p no:cacheprovider"   # appended to any inherited value
```

only when `policy.mode === "read-only"`. A write-capable lane keeps the
inherited environment unchanged, a one-shot escalation to a wider mode does
not inject the flag, and the tool description documents the injection. (The
same condition exists for `pwsh` on Windows; a bash-tool-only patch is
sufficient on Linux, where the pinned lane command runs.)

Alternative considered: point pytest's cache at the lane's writable temp
directory via `-o cache_dir=…`. That still needs a per-invocation flag or a
config file, and the read-only lane cannot write a config; the plugin switch
is simpler and is exactly what reviewers were already doing by hand.
