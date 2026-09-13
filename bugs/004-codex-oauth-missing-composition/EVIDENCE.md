# Evidence - bug 004

No access or refresh token values are recorded here.

## Environment

- DSH bundle: `@deepseek-ai/dsh` 0.1.1-rc.2 at
  `/home/john/.local/lib/node_modules/@deepseek-ai/dsh/`.
- pi-ai: `@earendil-works/pi-ai` 0.85.0.
- OpenCode: local build `3e60524f9b-local`.
- Observation date: 2026-09-13.

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

## DSH root cause probes

- `dsh --profile web --dump-default-config` shows `credentials` and
  `llm-pi-ai`, but no `authorization` row.
- `dsh-llm-pi-ai/lib/index.js:2262-2295` defines
  `registerPiAiFlows()` and registers `openai-codex` OAuth when the service is
  injected.
- `dsh-llm-pi-ai/lib/index.js:2440-2442` calls
  `ctx.inject(["authorization"], ...)`, so the callback is dormant without the
  service.
- `dsh-authorization/lib/index.js` exports the Cordis `AuthorizationService`
  and depends on the already-mounted credential service.

## Host/API/UI implementation

- `dsh-host-apiproxy/lib/index.js` and its contract-layer siblings expose the
  five authorization methods and keep them behind the existing loopback
  privileged-method fence.
- The host keeps only an opaque attempt id, bounded notices, and the current
  neutral prompt in memory. It never serializes a provider credential.
- `dsh-client-connection/lib/client.js` validates and transports the new RPC
  methods, including fixture-safe empty authorization behavior.
- `dsh-client-ui-settings-models/lib/client.js` renders the subscription panel,
  prompt controls, notice links, polling, and cancel action in the existing
  Models settings surface. The follow-up UI patch initializes controlled select
  state from the first option, guards empty select submissions, and adds
  explicit idle/loading/active/error panel state feedback.

## Fix validation

1. `npm pack @deepseek-ai/dsh-base@0.1.1-rc.2` produced a pristine package in
   `/tmp/opencode`.
2. The stored patch is the exact unified diff from that pristine file to the
   fixed file; it adds only the authorization row.
3. Applying a temporary equivalent overlay with `dsh --profile web
   --patch /tmp/dsh-auth-overlay.yml --no-open --port 0` booted successfully
   and printed a loopback web URL.
4. The installed bundle was patched with the stored patch and rechecked with
   `node`-independent YAML/config loading through `dsh --dump-config`.
5. `scripts/check.sh` reports the composition, host API, client transport, UI,
   and schema markers as present.

## Runtime probes

Against `dsh web --no-open --port 34904` after restarting the process:

- `POST /api/authorization.list` returned 200 and included
  `llm-pi-ai/openai-codex` with the OAuth method.
- `POST /api/authorization.begin` returned an opaque UUID attempt id.
- `POST /api/authorization.status` returned the neutral select prompt for the
  pi-ai login-method choice.
- `POST /api/authorization.answer` with `browser` returned `accepted: true`.
- A subsequent status returned the OpenAI authorization URL and manual-code
  prompt, without returning token material.
- `POST /api/authorization.cancel` returned `accepted: true`; a final status
  returned `cancelled`.
- Playwright opened Settings > Models, found `Subscription sign-in` and
  `OpenAI (ChatGPT Plus/Pro)`, rendered the select prompt, and showed the
  cancel button. Browser console errors: none.

## Browser-path regression and verification

Before the UI follow-up patch, Playwright selected the default visible
`Browser login (default)` option and clicked Continue. The browser sent:

```json
{"method":"authorization.answer","payload":{"value":""}}
```

The DSH UI then displayed `Unknown OpenAI Codex login method:`. The native
select showed the first label, but the controlled React value stayed empty.

After restarting `dsh --profile web --no-open --port 34904` with the follow-up
patch:

- The browser select reports `value: "browser"` before interaction.
- `authorization.answer` carries `value: "browser"`.
- The UI reaches the OpenAI notice `A browser window should open. Complete
  login to finish.` and renders the authorization URL plus manual-code input.
- The prompt exposes a labelled provider sign-in step, a live status region,
  associates the label with its control, and disables Continue until a manual
  code is entered.
- The active browser flow reports `Waiting for sign-in...`, labels the manual
  step `Step 1: Open the sign-in page. Step 2: Enter the authorization code or
  redirect URL.`, and connects its helper copy through `aria-describedby`.
- The device-code option still produces the expected verification URL and code.
- Browser console errors: none.
- Captures: `.ui-artifacts/pre-polish-models.png` and
  `.ui-artifacts/browser-auth-prompt.png`.
- Patch dry-run passed by reversing the follow-up patch on a temporary copy and
  applying it again; `node --check` passed for the installed UI bundle.
