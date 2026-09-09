# Bug 003: `opencode-go` models fail with 400 `MissingSessionID` (missing `x-opencode-session`)

## Symptoms

Any request with `provider: "opencode-go"` (e.g. model
`muse-spark-1.3-contributor`) fails on the first step, before any model
output:

> `OpenAI API error (400): {"type":"MissingSessionID","message":"Error from
> provider (Console Go): Request is missing x-opencode-session ..."}`

Observed in a session with `cwd: /home/john/Documents/mcp-servers`,
`config.provider: "opencode-go"`, `config.model:
"muse-spark-1.3-contributor"`: turn 1, step 1 errors; no retry can
succeed because the required header is never sent.

## Root cause

The DSH agent loop *does* pass a session id, but nothing maps it to the
header the Console Go gateway (`https://opencode.ai/zen/go/v1`) requires:

- `node_modules/@deepseek-ai/dsh-agent-loop/lib/index.js:757` builds the
  LLM request with `sessionId: this.session.id`.
- `node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js:1742` (pristine)
  forwards it to pi-ai as `{ sessionId: String(options.sessionId) }`,
  with `headers: requestHeaders(profile.headers)` — static profile
  headers only, no per-request session header.
- `@earendil-works/pi-ai@0.85.0` `dist/api/openai-responses.js:createClient`
  maps `sessionId` to legacy affinity headers only: `x-session-id` for
  `openrouter`, else `x-client-request-id` (+ `session_id` only for
  `openai`). The `opencode-go` catalog
  (`dist/providers/data/opencode-go.json`) marks all `openai-responses`
  go models (including `muse-spark-1.3-contributor`) as
  `"sessionAffinityFormat": "openai-nosession"`, so the wire request
  carries only `x-client-request-id` — never `x-opencode-session`.
- The same gap exists in the `openai-completions` and
  `anthropic-messages` paths: `x-opencode-session` appears nowhere in
  `pi-ai/dist`.

Net: every `opencode-go` call 400s with `MissingSessionID`,
deterministically, on any version carrying this combination.

## Fix design

Inject the header at the DSH-owned seam `dsh-llm-pi-ai` (the component
that already owns the DSH -> pi-ai bridge, as in bug 001's seam rule),
not inside third-party `pi-ai`:

- New `opencodeSessionHeaders(options)` in
  `node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js`: returns
  `{ "x-opencode-session": String(options.sessionId) }` iff
  `options.provider === "opencode-go"` and `sessionId` is defined,
  else `{}`.
- Call site (`streamWithSnapshot`, ~L1752): `headers: {
  ...requestHeaders(profile.headers), ...opencodeSessionHeaders(options)
  }`.
- Safe because pi-ai merges `optionsHeaders` last
  (`Object.assign(headers, optionsHeaders)` in both `openai-completions`
  and `openai-responses` `createClient`), so the header reaches the wire;
  and `requestHeaders()` only reserves attribution headers
  (`attributionHeaders()`), which do not collide with
  `x-opencode-session`. Existing affinity headers are untouched.
- Scoped to `opencode-go`; all other providers get `{}` (no behaviour
  change). Covers all three pi-ai APIs at once since the injection is
  above them.

Patch: `patches/dsh-llm-pi-ai-opencode-session.patch` (one helper +
one-line call-site change; `node --check` clean; helper unit-tested:
go+session, go-without-session, other-provider, numeric id).

## Rejected alternatives

- Patch `pi-ai/dist` `createClient` directly: smallest conceptual diff,
  but wrong owner — third-party dep, wiped on every `pi-ai` bump, and
  would need triplicating across three API files.
- Flip the catalog `sessionAffinityFormat` to `openai`: sends `session_id`
  / `x-session-affinity`, still not the required header; also edits a
  generated catalog (`opencode-go.models.js` says do-not-edit).
- Static profile header / user config: the session id is per-session and
  only exists at request time; static config cannot supply it.
- Document-only / upstream-only: leaves every local `opencode-go` call
  broken until upstream ships; the bridge fix is minimal and forward-
  compatible (if upstream later sends the header itself, ours merges
  harmlessly — same value).
