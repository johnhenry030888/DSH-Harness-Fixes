# UPSTREAM DRAFT — `:bug: Bug: MCP env ${VAR} references never expanded`

Status: NOT-FILED (paste to https://github.com/deepseek-ai/deepseek-harness/discussions).

---

MCP servers configured with credential env vars using `${VAR}` references
(the opencode-parity convention, e.g. `GITHUB_PERSONAL_ACCESS_TOKEN:
'${GITHUB_PERSONAL_ACCESS_TOKEN}'`) receive the **literal placeholder
string** — references are never expanded anywhere on the MCP spawn path.
The server then fails auth (`Bad credentials` from GitHub), deterministically,
across restarts and reboots.

Root cause: `buildChildEnv()` in `@deepseek-ai/dsh-mcp-client` merges
`config.env` verbatim over `scrubbedParentEnv()` (which strips all
credential-shaped names, so inheritance cannot supply the value either).
Nothing evaluates `${...}` in explicit MCP env values. Notably, the
function's own docstring already promises that "a deliberately supplied
entry survives because explicit env layers merge after the scrub" — the
promise is only half-kept.

Proposed fix (tested patch against 0.1.1-rc.2 available on request):
expand `${NAME}`/`$NAME` in explicit env values against the harness
process environment inside `buildChildEnv`, before merging over the
scrubbed base; unset names → `""` (shell semantics), non-strings pass
through. Minimal (one helper + three-line loop), seam-clean (the component
that owns the spawn), scrub untouched.

Verified: placeholder-vs-real proven by in-sandbox boolean probes
(`equals-literal: True`, `len: 31` on the child; DSH holds the real
40-char value); direct API call with the configured credential succeeds,
so only the expansion is missing. Expansion semantics unit-tested (bare,
embedded, unset, non-string, plain); patched file passes `node --check`.
