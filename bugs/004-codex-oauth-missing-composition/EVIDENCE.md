# Evidence - bug 004

No access or refresh token values are recorded here.

## Environment

- Current bundle: `@deepseek-ai/dsh` 0.1.5-rc.2 at
  `/home/john/.local/lib/node_modules/@deepseek-ai/dsh/`.
- pi-ai: `@earendil-works/pi-ai` 0.85.1.
- Re-port date: 2026-09-20.
- Earlier bundle: `@deepseek-ai/dsh` 0.1.1-rc.2 (pi-ai 0.85.0), observed
  2026-09-12/13. Its evidence is kept below as historical context.

## Root cause probes (unchanged across versions)

- `dsh-base/cordis.patch.yml` mounts `credentials` and `llm-pi-ai` but no
  `authorization` row (verified by grep on both 0.1.1-rc.2 and 0.1.5-rc.2).
- `dsh-llm-pi-ai/lib/index.js` defines `registerPiAiFlows()` and calls
  `ctx.inject(["authorization"], ...)`, so the registration callback is dormant
  without the service.
- `dsh-authorization/lib/index.js` exports the Cordis `AuthorizationService`
  (`static inject = ["credentials"]`), which the already-mounted credential
  service satisfies.
- 0.1.5-rc.2 removed `dsh-host-apiproxy` and its hand-written RPC; the caller
  surface now has to be a generated Typert Remote namespace.

## 0.1.5-rc.2 re-port validation

Pristine sources were obtained with `npm pack` for `dsh-base`,
`dsh-api-settings-controller`, `dsh-api-remotes`, and
`dsh-client-ui-settings-models` at `0.1.5-rc.2`; each installed target was
confirmed byte-identical to pristine before patching (fix lost by the update).

Patch set:

- `dsh-base-codex-oauth-composition.patch` - mounts `@deepseek-ai/dsh-authorization`.
- `dsh-api-settings-controller-authorization.patch` - host
  `AuthorizationController` (`authorizationController` service, `authorization`
  namespace) plus its SRC `@Remote` markers.
- `dsh-api-remotes-authorization.patch` - client `TYPERT_REMOTE$15`
  contribution and mount-list entry.
- `dsh-client-ui-settings-models-authorization.patch` - Models sign-in panel,
  copy, and `remote.authorization` injection.

Checks run locally:

1. `patch --dry-run` on every target: all hunks succeed with no fuzz.
2. `node --check` on all three JS targets: clean.
3. Pristine->reapply round-trip: `scripts/reapply.sh` from pristine files
   reproduces the pre-round-trip fixed bytes exactly for all four targets.
4. Host controller runtime test (real class, fake `ctx` and
   `ctx.authorization`): five `@Remote` markers present; binding is
   `authorizationController`/`authorization`; `list` returns flows; `begin`
   returns an id; `status` shows the notice (with URL) and select prompt;
   a stale prompt id is refused; the correct answer is accepted; the attempt
   settles `authorized`; `cancel` forwards to the seam; unknown attempt id and
   absent seam raise `gateway/bad-request` / `gateway/internal`.
5. Client bundle test (shimmed `window.__ModuleLoader__`, no real browser):
   `apply` mounts 16 contributions including the authorization one; all five
   descriptors pass the gateway's segment/id/wire/strict-codec rules; the
   `list` and `status` result schemas round-trip sample values and accept the
   optional prompt/error fields. Every contribution's `package` also passes the
   Remote registry's name rule (nonempty, no `#`); an initial re-port used a
   `#`-bearing package name and `dsh web` failed to apply the loader entry
   (`typert: invalid Remote package name`), which this check now catches.
6. UI bundle test (shimmed loader): bundle loads; `inject` includes
   `remote.authorization`; `apply` and `refreshIfLoaded` are exported.
7. `scripts/check.sh` exit 0; `scripts/reapply.sh` is idempotent.

Not yet exercised on this machine: a live browser OAuth round-trip against the
real Console/OpenAI endpoints and a screenshot of the rendered panel. The
transport and panel logic are covered by (4)-(6); a live run should be done
after the next `dsh web` restart.

## 0.1.1-rc.2 evidence (historical)

- `dsh --profile web --dump-default-config` showed `credentials` and
  `llm-pi-ai`, but no `authorization` row.
- `dsh-host-apiproxy/lib/index.js` and its contract-layer siblings exposed the
  five authorization methods behind the existing loopback privileged-method
  fence; the host kept only an opaque attempt id, bounded notices, and the
  current neutral prompt in memory.
- `dsh-client-connection/lib/client.js` validated and transported the RPC
  methods; `dsh-client-ui-settings-models/lib/client.js` rendered the
  subscription panel.
- Runtime probes against `dsh web --no-open --port 34904` after restart:
  `authorization.list` returned `llm-pi-ai/openai-codex` with the OAuth method;
  `begin` returned a UUID; `status` returned the login-method select prompt;
  `answer` with `browser` returned `accepted: true`; a later status returned the
  OpenAI authorization URL and manual-code prompt without token material;
  `cancel` returned `accepted: true` and a final status returned `cancelled`.
- Playwright opened Settings > Models, found `Subscription sign-in` and
  `OpenAI (ChatGPT Plus/Pro)`, rendered the select prompt, and showed cancel.
  After the select-state follow-up, the browser select reported
  `value: "browser"` before interaction and `authorization.answer` carried
  `value: "browser"`. Browser console errors: none. Captures:
  `.ui-artifacts/pre-polish-models.png`, `.ui-artifacts/browser-auth-prompt.png`.

## OpenCode implementation observed

The installed OpenCode binary contains an account auth service with a durable
auth store at `$XDG_DATA_HOME/opencode/auth.json` or
`~/.local/share/opencode/auth.json`. Its Codex provider uses client id
`app_EMoamEEZ73f0CkXaXp7hrann`, OpenAI authorization/token endpoints, PKCE,
state verification, localhost callback port 1455, JWT account-id extraction,
and access-token refresh.

The installed DSH pi-ai dependency contains the same provider implementation at:

- `node_modules/@earendil-works/pi-ai/dist/auth/oauth/openai-codex.js`
- `node_modules/@earendil-works/pi-ai/dist/providers/openai-codex.js`
- `node_modules/@earendil-works/pi-ai/dist/api/openai-codex-responses.js`
