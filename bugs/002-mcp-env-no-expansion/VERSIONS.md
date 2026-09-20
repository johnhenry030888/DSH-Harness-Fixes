# Versions — bug 002

- First seen broken: `@deepseek-ai/dsh` 0.1.1-rc.2 (installed bundle,
2026-09-06).
- Verified fixed-locally on 0.1.1-rc.2: patch applied to the installed bundle
2026-09-06 (`scripts/reapply.sh`: patch applied, `node --check` clean,
`scripts/check.sh` exit 0). End-to-end proof (GitHub MCP auth after DSH
restart) done 2026-09-06: fresh MCP child carries the real 40-char
credential (`child-equals-file: True`), and a live `search_users` call
authenticates (`login: johnhenry030888`). End-to-end proof complete.
- Re-verified and re-applied to `0.1.5-rc.2` (2026-09-20). The patch was
regenerated against pristine `@deepseek-ai/dsh-mcp-client@0.1.5-rc.2`; it
applies with no fuzz, `node --check` is clean, and a pristine->reapply
round-trip reproduces the fixed bytes exactly.
- Fix markers checked by `scripts/check.sh`: `expandEnvValue` +
`buildChildEnv` docstring marker in `dsh-mcp-client/lib/index.js`.
- Pristine sources for diffing: `npm pack <pkg>@<version>` from the registry.
