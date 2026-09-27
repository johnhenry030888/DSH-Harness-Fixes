# Bug 039 — no harness patch by design

Bug 039's deliverable is a **repo-side offline reader** (`scripts/dsh-records.mjs`)
for the store the installed bundle already writes, not a bundle change:

- the host already persists every session as
  `$DSH_HOME/sessions/--<cwd-slug>--/<sessionId>/session.v3.jsonl.zstd`
  (multi-frame zstd, append-per-write);
- the drill's problem was that no supported reader existed and the brief never
  named the store (v27 §6 F3), not that the store was missing.

The patch is therefore empty. `scripts/check.sh` asserts the reader (present,
executable, `node --check`), the README store/schema documentation, and the
two-frame behavioural self-test (`scripts/records-selftest.sh`), so a store
shape change fails loudly here instead of silently truncating evidence.

No model-facing tool is registered: the 178/161 tool arithmetic is
load-bearing for drills and the reader needs no model.
