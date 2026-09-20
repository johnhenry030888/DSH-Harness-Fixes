# Upstream draft - Bug 004

## Title

Mount the authorization service so the existing Codex OAuth flow can register

## Discussion post

`@deepseek-ai/dsh-llm-pi-ai` already ships a complete OpenAI Codex OAuth bridge
and pi-ai already ships the PKCE browser/device flow, refresh logic, and Codex
Responses transport. The shared `dsh-base` composition mounts the credential
provider and the pi-ai adapter but omits `@deepseek-ai/dsh-authorization`.

The adapter registers its flows from `ctx.inject(["authorization"], ...)`, so
the omission leaves `ctx.authorization` unavailable and makes GPT Codex
subscriptions appear unsupported. Adding the authorization plugin row after
the credential provider activates the existing flow and keeps grants in DSH's
credential store. No OAuth code or token format is duplicated.

The installed bundle also has no caller for the seam. The local fix adds an
`authorization` Typert Remote namespace (host `AuthorizationController` in
`dsh-api-settings-controller`, strict client descriptors in `dsh-api-remotes`)
and a "Subscription sign-in" panel in the Models settings page. Upstream may
prefer to own that surface differently; the essential upstream change is the
composition row, without which no surface can work.

Local patches and evidence: `bugs/004-codex-oauth-missing-composition/`.

## Submission status

NOT-FILED
