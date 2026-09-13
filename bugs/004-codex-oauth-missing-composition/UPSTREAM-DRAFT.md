# Upstream draft - Bug 004

## Title

Mount the authorization service so the existing Codex OAuth flow can register

## Discussion post

`@deepseek-ai/dsh-llm-pi-ai` already ships a complete OpenAI Codex OAuth bridge
and pi-ai 0.85.0 already ships the PKCE browser/device flow, refresh logic, and
Codex Responses transport. The shared `dsh-base` composition mounts the
credential provider and the pi-ai adapter but omits
`@deepseek-ai/dsh-authorization`.

The adapter registers its flows from `ctx.inject(["authorization"], ...)`, so
the omission leaves `ctx.authorization` unavailable and makes GPT Codex
subscriptions appear unsupported. Adding the authorization plugin row after
the credential provider activates the existing flow and keeps grants in DSH's
credential store. No OAuth code or token format is duplicated.

Local patch and evidence: `bugs/004-codex-oauth-missing-composition/`.

## Submission status

NOT-FILED
