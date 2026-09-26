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

### Turn-aware runs (2026-09-26, drill v14 friction #2)

`session/prompt` **queues** (`mode: "queue"`), so `prompted: true` means the
message was accepted, not answered — and the pre-update helper SIGTERMed the
server immediately after queueing, leaving the session at `turn/start` with no
`request/header` for a caller to corroborate. A prompted run now waits for the
session's first `turn/end` and reports the composition alongside the ids:

```json
{"sessionId":"session-…","agentPreset":"orchestrator","prompted":true,
 "turnCompleted":true,"headerToolCount":178,
 "assistantText":"…","turnEndReason":{"kind":"completed"},"waitedMs":16958}
```

- the result also carries `webPid` (the server this call booted, and `kept: true`
  with `--keep`), so a caller asserting "no stray server" compares against its
  pre-call baseline instead of guessing which of several `dsh web` processes is
  new (drill v15 friction #3);
- the wait is bounded by `--turn-timeout` (default `max(--timeout, 120000)`); a
  timed-out wait still exits 0 with whatever it observed, so "queued" and
  "answered" are distinguishable;
- `--no-wait` restores the old return-immediately behaviour;
- the transcript is read from `<home>/sessions/<cwd-bucket>/<sessionId>/`
  `session.v3.jsonl.zstd` with the `zstd` CLI, because the store appends **one
  frame per flush** and Node's single-shot `zstdDecompressSync` stops at the
  first frame (observed: 198 bytes of a 47 KB transcript, no `turn/end`). The
  CLI is required for a reliable wait; without it the read is truncated and the
  wait simply times out.

Omitting `--home` uses the caller's `DSH_HOME` (or `~/.dsh`), i.e. the **real**
harness home — pass `--home` for an isolated run.

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

Live (2026-09-26, real harness home, `--preset orchestrator`): one call returned
`turnCompleted: true`, `headerToolCount: 178`, `assistantText` from the prompted
turn, in `waitedMs: 16958` (34.8 s wall, including server start), with no stray
server left behind — i.e. the drill no longer needs a second `--keep` run to see
the header it asserts on.
