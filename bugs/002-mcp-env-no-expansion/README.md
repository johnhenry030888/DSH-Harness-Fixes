# Bug 002: MCP `env` `${VAR}` references are never expanded

## Symptoms
Any MCP server whose config passes a credential via `${VAR}` (the documented
opencode-parity convention, e.g. `GITHUB_PERSONAL_ACCESS_TOKEN:
'${GITHUB_PERSONAL_ACCESS_TOKEN}'` in `dsh.mcp.json` / `cordis.patch.yml`)
receives the **literal 31-char placeholder string** in its environment.
GitHub answers `Bad credentials`; the failure survives DSH restarts, full
PC reboots, and credential rotation, because no state is involved — the
value is never resolved at all.

Proven by boolean probes (no hash ambiguity): DSH holds the real 40-char
token (`dsh-equals-file: True`), the spawned child holds the literal
(`equals-literal: True`, `len: 31`). Direct API call with the configured
value returns the account login, so the credential itself is valid.

## Root cause
`@deepseek-ai/dsh-mcp-client/lib/index.js` `buildChildEnv(extra)` merges
the spec's explicit `env` **verbatim** over `scrubbedParentEnv()`:

- `scrubbedParentEnv()` (`@deepseek-ai/dsh-subprocess/lib/index.js:46`)
drops every credential-shaped name (`/KEY|PASSWORD|SECRET|TOKEN/i`), so
`GITHUB_PERSONAL_ACCESS_TOKEN` can never arrive via inheritance.
- Nothing on the config path evaluates `${...}` in explicit env values
(the `!!js` expression support covers other config positions; plain
quoted `'${...}'` strings stay literal).

Net: the only channel that can deliver a credential is broken by
construction. Every credential-bearing MCP server using the `${}`
convention fails auth, deterministically, on every version carrying this
code.

## Fix design
Expand `${NAME}` / `$NAME` in explicit env values against the harness
process environment inside `buildChildEnv` (new `expandEnvValue`), before
merging over the scrubbed base. Unset names resolve to `""` (shell
semantics); non-string values pass through. This is the component that
owns the spawn seam, and its own docstring already promises that "a
deliberately supplied entry survives because explicit env layers merge
after the scrub" — the patch makes that promise true for references.
Patch: `patches/dsh-mcp-client-env-expansion.patch` (one function +
three-line loop change; `node --check` clean; expansion semantics
unit-tested: bare, embedded, unset, non-string, plain).

## Rejected alternatives
- Expand in each server's `run.sh`: per-server toil, N wrappers, and it
leaves the harness bug in place for every future server.
- Remove/relax the scrub: leaks harness secrets (`DEEPSEEK_API_KEY`,
`DSH_*` facts) into all children; violates the documented security
posture. Rejected outright.
- Document "paste literal values": puts live secrets in config files
(usually committed or backed up); strictly worse than env references.
- Resolve against the frozen launch snapshot instead of `process.env`:
heavier, and the snapshot is built from the same process env at boot;
`process.env` at spawn is the freshest source and matches opencode
behaviour.
