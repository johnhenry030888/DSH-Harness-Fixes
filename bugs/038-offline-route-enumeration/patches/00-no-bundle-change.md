# Bug 038 — no harness patch by design

Bug 038's deliverable is a **documentation + helper** fix on top of the bug-020
deliverable, not a bundle change:

- the in-session authority already exists (`list_subagent_models` on the
  delegation tool, policy-filtered by the host at composition);
- the `/api` channel already exists and requires the process-token cookie that
  `bugs/020-.../scripts/dsh-local-session.mjs` performs;
- `/v1/models` is not mounted at all.

What was missing is a documented, offline script-side path: the helper gains a
`--routes` mode that reads the same two local sources the host composes the
answer from (`settings.yaml#subagent-model-selection.allowedModels` and
`storages/llm-pi-ai/catalog/*.json`), prints their intersection with a `basis:`
line, and refuses to guess (`routes: UNKNOWN (<reason>)`, non-zero) when a
source is missing.

No new RPC method was added and the auth fence is untouched (unauthenticated
`/api/routes` still answers 401 — re-measured on a scratch boot and on the
running server).

The patch is therefore empty; `scripts/check.sh` asserts the `--routes` markers
plus the README's "How to enumerate routes" section, and chains the bug-020
check so its host contracts must still hold.
