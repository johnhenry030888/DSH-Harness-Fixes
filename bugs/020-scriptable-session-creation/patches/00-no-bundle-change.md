# Bug 020 — no harness patch by design

Bug 020's deliverable is a **client of the documented local API**, not a
bundle change:

- the Web app already announces the per-process launch token on stdout
  (`dsh web: http://127.0.0.1:<port>/?token=…`),
- `BrowserAuth.authorizeIndex()` already exchanges it for the signed session
  cookie,
- `@deepseek-ai/dsh-api-session-controller#session/create` already creates a
  session over the authenticated `/api` channel.

`scripts/dsh-local-session.mjs` wires those three together with no weakened
authentication and no persisted credential (unless the caller passes
`--token-file`, which is written mode 0600 under the caller's control).

The patch is therefore empty; `scripts/check.sh` asserts the helper plus the
three host contracts, and fails loudly if a dsh update moves them.
