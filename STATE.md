# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: post-`dsh` 0.1.5-rc.2 re-apply. All four bugs re-applied and verified.
- What changed this turn (2026-09-20, `dsh` 0.1.1-rc.2 -> 0.1.5-rc.2):
  - 001/002/003: patches regenerated against pristine 0.1.5-rc.2 sources and
    re-applied. 003's second hunk had moved (`streamSimple` gained arguments);
    the others needed only a clean regeneration.
  - 004: re-ported. 0.1.5-rc.2 replaced `dsh-host-apiproxy` and its
    hand-written RPC with generated Typert Remote namespaces. The composition
    mount is unchanged; the caller is now a `TypertRemoteService`
    `AuthorizationController` in `dsh-api-settings-controller` (SRC-dispatched,
    so no generated-manifest edit), a strict client contribution in
    `dsh-api-remotes` mounted as `ctx.remote.authorization`, and a Models
    sign-in panel. Obsolete `dsh-host-apiproxy-*` / `dsh-client-connection*`
    patches were removed.
- Verification: `patch --dry-run` no-fuzz on every target; `node --check` clean;
  pristine->reapply round-trip byte-identical; host controller and client
  bundle runtime tests pass; `./scripts/check-all.sh` exit 0.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] scaffold baseline materialized and audit refreshed to engine v1.15.0
  - [x] lint (`linter-formatter` `lint`/`format`) + `run_tests` (+ `perf_gate`/`api_call` where applicable) + `audit-secrets.sh` clean
  - [x] `./scripts/verify.sh` passes
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [x] checkpoint/commit (`git`) — `b8119d7` (all four fixes re-applied)
  - [x] push to origin — `https://github.com/johnhenry030888/DSH-Harness-Fixes` accepted `c9da9f8..b8119d7` on `main`; pre-push hooks passed (secrets audit OK)
  - [x] update this file (every turn ends by updating it)
- Open items: live browser OAuth round-trip against the real endpoints (see
  `bugs/004-codex-oauth-missing-composition/EVIDENCE.md`) should be run after
  the next `dsh web` restart.
- Decisions: see `docs/decisions.md`.
