# Bug 020 — scriptable local session creation

Severity: **low** (operator friction: ~30 s of manual GUI work per
switch-path/preset probe; one acceptance test was never exercised and one
sample count is short because of it). Local fix: **APPLIED** to the repository
(helper + documented path; no harness code change). Upstream: **NOT-FILED**.

## Symptoms

The drills could not open a session programmatically:

- the Web GUI answers **401** to every unauthenticated request (host/origin
  fence + signed browser-session cookie);
- the per-process launch token was only announced on the operator's terminal,
  so a headless probe could not authenticate;
- no CLI flag creates a session. Every switch-path or preset-probe
  verification therefore cost the operator ~30 s of manual work — which is why
  bug 007's live acceptance had never been exercised and bug 011's sample
  count was (and is) short.

## Investigation (what exists)

Reading the installed 0.1.5-rc.2 bundle (all of it public code):

1. `dsh-web-app` prints the authenticated root URL to **stdout** when
   `printUrl` is set (default `true`):
   `dsh web: http://127.0.0.1:<port>/?token=<process launch token>`. A
   script can capture that line; the token itself is minted per process.
2. `BrowserAuth.authorizeIndex()` (in `@deepseek-ai/dsh-client-connection`)
   exchanges the token for a signed, authority-scoped session cookie on
   `GET /?token=…` (303 + `set-cookie`), exactly like opening the browser.
3. Every session operation is a Typert Remote method on the authenticated
   `/api` channel: `@deepseek-ai/dsh-api-session-controller#session/create`
   (`{request:{cwd?, agentPreset?, sessionId?, workspaceId?}}`),
   `session/prompt`, `session/fork`, … (`lib/typert.host.js`).
4. There is no supported CLI flag for creation, no local socket, and no token
   file under `~/.dsh` (the signing *secret* is persisted as a credential
   record, but the per-process launch token is not — by design).

So a documented, auth-respecting path **does** exist: start the Web app, read
the printed token URL, exchange it for the cookie, and drive `session/create`
over loopback. Nothing weakened: the token is minted by the same process, used
over loopback, and is never persisted unless the caller asks for a 0600 file.

## Deliverable

`scripts/dsh-local-session.mjs` implements that path:

```
node scripts/dsh-local-session.mjs --home <DSH_HOME> --cwd <dir> \
  --preset orchestrator --prompt "..." --json
```

- spawns `dsh web --no-open --port <0|port>` (honours `DSH_HOME`),
- parses the `dsh web: <url>` line (bounded wait), exchanges the token for
  the cookie, and POSTs the documented RPC envelopes,
- creates the session (`--preset`, `--cwd`), optionally sends one prompt, and
  prints the session id; `--keep` leaves the server up and prints the cookie
  for follow-ups; `--token-file <p>` writes the authenticated URL at mode
  `0600` for other loopback tooling.

Authentication is untouched: the helper is a client of the existing fence, not
a bypass. The only optional file it writes is caller-chosen.

## Rejected alternatives

- **`--local-token-file` in the harness.** The token is already announced on
  stdout; adding a flag whose only job is to persist a credential widens the
  credential's surface (a file other processes can read) for no capability
  gain. The smallest safe helper is a client of what is already there.
- **A local unix socket / token file under `~/.dsh`.** No such surface exists;
  adding one is a product/API decision, and the documented `/api` channel
  already provides the operation.
- **Scraping the cookie out of `~/.dsh/.credentials.yaml`.** That record is
  the *signing secret* (it can mint cookies for the whole home, not just
  this process); using it would widen what a helper must be trusted with.
  Reading the process-token URL line is strictly narrower.
- **Editing the user's `~/.dsh` settings to disable auth.** Explicitly
  forbidden and wrong.

## Acceptance evidence

See `EVIDENCE.md`: the helper created an Orchestrator session on a scratch
`DSH_HOME` with the preset copy; the unauthenticated control probe returned
401; the created session appears in the scratch home's session store with
`agentPreset: orchestrator` in its header.
