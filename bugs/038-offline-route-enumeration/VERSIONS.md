# Versions — bug 038

- First analyzed broken: the bug-020 helper `dsh-local-session.mjs` as stored
  after drill v14 (documented in `bugs/020-…/README.md`), from drill v25 §0
  and v26 §0/§7 F-route — no offline route list, so `/v1/models` (404),
  `/api/routes` (401) and `/api/providers` (401) left the preflight without
  the served set.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-27):
  - `scripts/check.sh` exit 1 with the helper/README at HEAD, 0 after the
    `--routes` mode and the README section landed; the check chains the
    bug-020 check (its host-contract markers still present);
  - `--routes` / `--routes --json` print **8** routes with a two-source
    `basis:` line on the real home; an empty scratch home prints
    `routes: UNKNOWN (cannot read …)` and exits 1 (both modes, and the
    partial-source case);
  - the in-session `list_subagent_models({provider:"opencode-go"})` returned
    the same 8 routes on a scratch orchestrator session
    (`headerToolCount: 178`);
  - unauthenticated `/api/routes` → 401, `/api/providers` → 401,
    `/v1/models` → 404, token exchange → 303 (scratch boot and the running
    server).
- No bundle patch: this is a helper + documentation fix on the bug-020
  deliverable (see `patches/00-no-bundle-change.md`). No `npm pack` is
  involved.
- Fix markers (checked by `scripts/check.sh`, never the version): the
  `--routes` flag case, the two source readers, the policy-key needle, the
  `routes: UNKNOWN (` string, and the two README markers.
- After a `dsh` update: run `scripts/check-all.sh`. If bug 038 is MISSING, run
  `scripts/reapply.sh`; if the 020 host contracts moved, re-read the helper
  against the new `dsh-web-app` / `dsh-client-connection` /
  `dsh-api-session-controller` sources (bug 020's failure path).
