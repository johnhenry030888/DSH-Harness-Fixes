# Versions — bug 002

- First seen broken: `@deepseek-ai/dsh` 0.1.1-rc.2 (installed bundle,
2026-09-06).
- Verified fixed-locally: patch applied to the installed bundle
2026-09-06 (`scripts/reapply.sh`: patch applied, `node --check` clean,
`scripts/check.sh` exit 0). End-to-end proof (GitHub MCP auth after DSH
restart) done 2026-09-06: fresh MCP child carries the real 40-char
credential (`child-equals-file: True`), and a live `search_users` call
authenticates (`login: johnhenry030888`). End-to-end proof complete.
