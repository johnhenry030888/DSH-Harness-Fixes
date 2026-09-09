# UPSTREAM DRAFT — `:bug: Bug: opencode-go models fail with 400 MissingSessionID (x-opencode-session never sent)`

Status: FILED as deepseek-ai/deepseek-harness discussion #6076.

---

All `opencode-go` models (e.g. `muse-spark-1.3-contributor` via
`https://opencode.ai/zen/go/v1`) fail on the first step with:

`OpenAI API error (400): {"type":"MissingSessionID","message":"Error from
provider (Console Go): Request is missing x-opencode-session ..."}`

Environment: dsh 0.1.1-rc.2, `@earendil-works/pi-ai` 0.85.0.

Root cause: the agent loop passes `sessionId` (`dsh-agent-loop`
`sessionId: this.session.id`) and `dsh-llm-pi-ai` forwards it to pi-ai,
but pi-ai's `createClient` (all three APIs) only maps it to legacy
affinity headers (`x-session-id` / `x-client-request-id` / `session_id`).
The go catalog marks the `openai-responses` models
`sessionAffinityFormat: openai-nosession`, so the wire request carries
only `x-client-request-id` — `x-opencode-session` is never emitted
(`rg` over `pi-ai/dist` confirms zero hits).

Proposed fix (tested patch against 0.1.1-rc.2 available on request):
inject `{ "x-opencode-session": String(sessionId) }` for
`provider === "opencode-go"` in `dsh-llm-pi-ai`'s `streamWithSnapshot`
(one helper + one-line call-site change; other providers untouched;
pi-ai merges request headers last so it reaches the wire; existing
affinity headers preserved). Patched file passes `node --check`; helper
unit-tested (go+session / go-without-session / other-provider / numeric
id 4/4).

Happy to share the full diff here if wanted. Thanks for all the work on
the harness.
