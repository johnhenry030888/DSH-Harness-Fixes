# Evidence — bug 003

## Failing session (pasted DSH log, 2026-09-07)

- Session id: `session-4c4f5634-386e-4c20-9f34-1e9e399ded18`
  (`createdAt: 1788766305788`, `cwd: /home/john/Documents/mcp-servers`,
  `delegationDepth: 0`, `agentPreset: code`).
- Request header (seq 11): `config.provider: "opencode-go"`,
  `config.model: "muse-spark-1.3-contributor"`,
  `reasoningEffort: "medium"`.
- Failure (seq 14-17, turn 1 step 1): `OpenAI API error (400):
  {"type":"MissingSessionID","message":"Error from provider (Console
  Go): Request is missing x-opencode-session and cannot be routed
  efficiently. ..."}`. Turn ends `reason: error`. No model output.

## Code references (installed bundle `@deepseek-ai/dsh` 0.1.1-rc.2)

- `node_modules/@deepseek-ai/dsh-agent-loop/lib/index.js:757`:
  `sessionId: this.session.id` — session id IS passed to the LLM seam.
- `node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js:1742` (pristine):
  `...options.sessionId === void 0 ? {} : { sessionId:
  String(options.sessionId) }` + `headers:
  requestHeaders(profile.headers)` — no `x-opencode-session`.
- `node_modules/@earendil-works/pi-ai/dist/api/openai-responses.js:164-188`
  (`createClient`): `sessionId` -> `x-session-id` (openrouter) else
  `x-client-request-id` (+ `session_id` only for `openai`); the
  `openai-nosession` branch sends only `x-client-request-id`.
- `node_modules/@earendil-works/pi-ai/dist/providers/data/opencode-go.json`:
  `muse-spark-1.3-contributor` (and siblings) carry
  `"compat":{"sessionAffinityFormat":"openai-nosession"}`,
  `baseUrl: "https://opencode.ai/zen/go/v1"`.
- `rg x-opencode-session pi-ai/dist` → no hits pre-fix (0.85.0).

## Versions

- `@deepseek-ai/dsh` 0.1.1-rc.2 (installed
  `/home/john/.local/lib/node_modules/@deepseek-ai/dsh/`).
- `@earendil-works/pi-ai` 0.85.0 (nested under the dsh install).
- Pristine: `npm pack @deepseek-ai/dsh-llm-pi-ai@0.1.1-rc.2`
  (sha `43911587…`, 19 files); `diff` pristine-vs-installed pre-fix
  empty (sha256 `e183a9cd…` both sides).

## Re-verify without the original conversation

1. `scripts/check.sh` → exit 1 pre-fix (markers absent), exit 0 post-fix.
2. `rg -n "x-opencode-session" .../dsh-llm-pi-ai/lib/index.js` → 3 hits
   post-fix (comment + helper + call site).
3. `node --check .../dsh-llm-pi-ai/lib/index.js` → clean.
4. Helper truth table (run under `node -e`, see README): go+session →
   header, go-without-session → `{}`, other provider → `{}`, numeric id
   → stringified.
5. Live: retry any `opencode-go` model — `MissingSessionID` gone (any
   remaining error should be auth/quota, proving the header is sent).
