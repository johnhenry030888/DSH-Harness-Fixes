# Evidence — bug 002

No secrets below: tokens appear only as length/prefix metadata or hashes.
All probes ran on the live machine 2026-09-06 (Africa/Johannesburg).

## Environment
- Bundle: `@deepseek-ai/dsh` 0.1.1-rc.2
  (`/home/john/.local/lib/node_modules/@deepseek-ai/dsh/`).
- Server under test: `@modelcontextprotocol/server-github` via
  `~/Documents/mcp-servers/github/run.sh` (clean `exec node …`, no env
  manipulation), configured in `dsh.mcp.json` + `~/.dsh/profiles/web/cordis.patch.yml`
  (`GITHUB_PERSONAL_ACCESS_TOKEN: '${GITHUB_PERSONAL_ACCESS_TOKEN}'`).
- Configured value: classic PAT, `repo` scope, 40 chars, verified valid by
direct API call (`curl …/api.github.com/user` → `login: johnhenry030888`).
- Shell path (`git`/`gh`, same value): repo `CAPS-App` created + pushed,
verified via `ls-remote` — the credential works; only the MCP path fails.

## Decisive probes (boolean, not hash-based)
- DSH process env equals configured file value: `dsh-equals-file: True`,
`dsh-len: 40`.
- Spawned MCP child value equals the literal placeholder:
`equals-literal: True`, `len: 31` (read via `/proc/<pid>/environ`, full
byte dump `od -c` confirms plain ASCII, single entry).
- Therefore: no `${VAR}` expansion occurs between MCP config and spawn.

## Red herrings documented (do not rechase)
- Hash-comparison forensics produced conflicting readings (`de58…` vs
`69ca…`) because several pasted tokens rotated through the same variable
during the session; booleans + the direct API test are authoritative.
- Suspects ruled out with evidence: `run.sh` (clean exec), `~/.dsh`
state (hash-swept, no match), session logs (transcript copies only),
`~/.config/gh/hosts.yml` (empty), `~/Documents/mcp-servers/github/.env`
(different value), `~/.bashrc` (loader only), `~/.bashenv` (no token),
DSH restarts + full PC reboot (failure persists ⇒ deterministic, not
stale state).

## Code references (bundle 0.1.1-rc.2)
- `node_modules/@deepseek-ai/dsh-mcp-client/lib/index.js:27-32`
(`buildChildEnv`: verbatim merge, no expansion).
- `node_modules/@deepseek-ai/dsh-subprocess/lib/index.js:31-50`
(`SENSITIVE_ENV_PATTERN`, `scrubbedParentEnv`: credential-shaped names
stripped from the inherited base).
- `node_modules/@deepseek-ai/dsh-launch-environment/lib/index.js:55-68`
(snapshot exists, but MCP config env never resolves through it).

## Re-verify without the original conversation
1. `scripts/check.sh` → exit 1 (marker `expandEnvValue` absent).
2. Set any `MCP_ENV_PROBE` var, add `"MCP_ENV_PROBE": "${MCP_ENV_PROBE}"`
to a test server entry, trigger a call, read `/proc/<server-pid>/environ`:
value is the literal placeholder pre-fix, the real value post-fix.
3. GitHub server: pre-fix `Bad credentials`; post-fix calls authenticate.
