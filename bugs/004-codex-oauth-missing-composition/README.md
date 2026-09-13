# Bug 004: GPT Codex subscription OAuth is not mounted in DSH

## Symptoms

DSH ships the pi-ai OpenAI Codex provider and its OAuth implementation, but a
default DSH profile cannot start or present the sign-in flow. A Codex
subscription route therefore has no usable credential path even though the
provider code is installed.

## Root cause

The installed `@deepseek-ai/dsh-llm-pi-ai` bundle already contains the complete
OAuth bridge:

- `registerPiAiFlows()` registers one flow per pi-ai provider with OAuth,
  including `openai-codex`.
- The flow delegates to pi-ai's `openaiCodexOAuth` implementation.
- `credentialStoreFrom()` stores the opaque pi-ai grant under the DSH key
  `llm-pi-ai/openai-codex` and supports refresh-time replacement.
- `authContextFrom()` supplies the ambient auth context used by pi-ai.

The bridge is registered from an `ctx.inject(["authorization"], ...)` callback,
but the shared `@deepseek-ai/dsh-base` composition mounts
`@deepseek-ai/dsh-credentials-local` and `@deepseek-ai/dsh-llm-pi-ai` without
mounting `@deepseek-ai/dsh-authorization`. The dependency is present in the
bundle, yet `ctx.authorization` never becomes available, so the registration
callback never runs.

## OpenCode comparison

OpenCode uses the same pi-ai Codex OAuth protocol at its provider seam:

- PKCE browser login against `https://auth.openai.com/oauth/authorize`.
- Local callback at port 1455 with state verification.
- Authorization-code exchange at `https://auth.openai.com/oauth/token`.
- Account id extraction from the JWT claim
  `https://api.openai.com/auth.chatgpt_account_id`.
- Stored access and refresh tokens with expiry, refreshed before requests.
- A ChatGPT backend request using the OAuth access token.

DSH's installed pi-ai 0.85.0 implementation already owns these details. The
correct DSH fix is to activate its existing authorization seam, not to create a
second token file or duplicate OpenAI endpoints.

## Fix design

Insert this row in the shared DSH base composition, immediately after the
credential provider and before the pi-ai adapter:

```yaml
- id: authorization
  name: '@deepseek-ai/dsh-authorization'
```

This lets Cordis satisfy the adapter's authorization injection, causing the
OpenAI Codex OAuth flow to register while preserving DSH credential storage and
pi-ai refresh behavior. Existing providers and API-key flows are unchanged.

The installed bundle also lacked a caller for the authorization seam. The fix
adds a loopback-only, privileged RPC surface:

- `authorization.list` lists registered flows and methods without secrets.
- `authorization.begin` starts a background attempt and returns an opaque
  attempt id.
- `authorization.status` returns bounded notices and the current prompt.
- `authorization.answer` supplies one prompt answer to the running attempt.
- `authorization.cancel` aborts the attempt by id.

The request/response job shape is deliberate. OAuth browser login waits on a
local callback while the UI remains responsive, and the neutral DSH prompt and
notice types work for device-code or manual-code flows as well. All five
methods remain loopback privileged alongside settings and credentials.

The Models settings page now renders a subscription sign-in panel from
`authorization.list`, polls the attempt status, opens notices' URLs in a new
tab, renders text/secret/select prompts, sends answers, and offers cancellation.
The select prompt initializes to the provider's first option so the browser
path cannot submit an empty login method, and the panel exposes idle, loading,
active, and error feedback in the existing settings language.
The UI never receives an access token, refresh token, authorization code, or
credential record. pi-ai remains the OAuth protocol owner and writes the grant
through DSH's credential service.

Patches: `patches/dsh-base-codex-oauth-composition.patch`, the
`dsh-host-apiproxy-*`, `dsh-client-connection*`, and
`dsh-client-ui-settings-models*.patch` files.

## Rejected alternatives

- Copy OpenCode's OAuth implementation into DSH: pi-ai already owns the exact
  protocol and DSH already adapts its credential lifecycle; duplication would
  split refresh and storage behavior.
- Store tokens in OpenCode's `~/.local/share/opencode/auth.json`: this bypasses
  DSH's credential provider and would expose provider-owned grants to a second
  application.
- Add an `OPENAI_API_KEY` workaround: a ChatGPT subscription OAuth grant is not
  an API key and cannot authenticate the Codex backend through the API-key path.
- Patch `dsh-llm-pi-ai` to instantiate authorization itself: service lifecycle
  ownership belongs to the composition, and bypassing Cordis injection would
  make teardown and duplicate-service handling incorrect.
- Require the user to manually choose the default browser option: native
  selects can display their first option while controlled React state remains
  empty, so the safe fix is to initialize state from the option id and retain a
  defensive empty-answer guard.
