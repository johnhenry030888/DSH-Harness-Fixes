# Bug 038 — no documented, offline way to enumerate the served routes

Severity: **low** (a drill preflight cannot obtain the route list, so a whole
measurement table goes unmeasured). Local fix: **APPLIED** to the repository
(helper `--routes` mode + documented path; no harness code change). Upstream:
**NOT-FILED**.

## Symptoms

- **v25 §0**: the preflight could not obtain a route list — `/v1/models` →
  **404**, `/api/routes` → **401**, `/api/providers` → **401** — so "the pins
  were taken from the preset map and verified afterwards from each child's own
  `request/header`".
- **v26 §0 + §7 F-route**: the same, and the run's whole header/effort table
  went **NOT MEASURED**.
- In-session the answer already exists: `list_subagent_models(provider)`
  returned 8 routes in v22/v23 (and again in this fix's live cross-check,
  `headerToolCount: 178` on the orchestrator preset). The gap is a
  **documented script-side path**, not a new service.

## Root cause

1. `/api/*` is the authenticated Typert channel: every request must pass the
   process-token → cookie exchange (which `bugs/020-…/scripts/
   dsh-local-session.mjs` already performs). Unauthenticated requests are 401
   by design.
2. `/v1/models` is not mounted at all (404).
3. The in-session `list_subagent_models` tool needs a composed LLM session;
   nothing documented let a shell preflight enumerate the same policy-filtered
   set offline from the files the host itself reads.

## Fix design

1. **`--routes` mode** in `bugs/020-…/scripts/dsh-local-session.mjs`:
   - reads the delegation policy's allowed routes from
     `$DSH_HOME/settings.yaml`
     (`subagent-model-selection.allowedModels` — 8 entries on this
     deployment);
   - reads the served catalogue the provider ships from
     `$DSH_HOME/storages/llm-pi-ai/catalog/*.json` (33 models in one document
     here);
   - prints the **intersection** as `provider/model` lines plus a `count` and a
     `basis:` line naming both sources; `--json` emits the same as one object
     for machine use;
   - is honest about its basis: if either source is missing (unreadable file,
     absent section/list, unreadable documents, unexpected YAML shape) it
     prints `routes: UNKNOWN (<reason>)` / `{"routes":null,…,"unknown":…}` and
     exits **non-zero** — it never guesses a list.
2. **`bugs/020-…/README.md`** gains a "How to enumerate routes" section that
   states plainly:
   - the authority is the in-session `list_subagent_models()` tool
     (`list_subagent_models({provider})` for the model detail,
     `{provider, model}` for the effort ladder);
   - `/api/*` requires the process-token cookie (unauthenticated → 401);
   - `/v1/models` is not mounted (404);
   - `--routes` is the offline convenience and its basis is **policy ∩
     catalogue**.
3. No new RPC method, no auth change, no harness bundle patch (see
   `patches/00-no-bundle-change.md`).

## Rejected alternatives

- **Add an unauthenticated `/v1/models` or `/api/routes` route.** Touches the
  auth fence (explicitly out of scope), and duplicates the host's composition
  logic inside a new surface that could drift from it.
- **Scrape the route list from the preset map or a session transcript.** v25/v26
  showed the preset map is a plan, not the served set; the fix must read the
  same two sources the host composes from, not a stale copy.
- **Add a new Typert RPC method for routes.** The in-session tool already
  answers the question; the offline gap is a client-side read of two local
  files, so a new RPC widens the API for no new information.
- **Use a general YAML library.** The helper is standalone (it cannot resolve
  the dsh bundle's dependencies); a targeted parser for exactly the
  `allowedModels` list shape covers the documented format, and anything else
  becomes an honest UNKNOWN instead of a silently wrong parse.
- **Fall back to the catalogue alone when the policy is missing.** That would
  over-report routes the delegation policy forbids; the honest answer is
  UNKNOWN + non-zero.
- **Print a count-only answer.** The drills compare routes per provider/model
  and afterwards check each child's header; the greedy per-route lines are what
  makes the cross-check mechanical.

## Deliverable

- `bugs/020-…/scripts/dsh-local-session.mjs` (`--routes` / `--routes --json`)
- `bugs/020-…/README.md` ("How to enumerate routes")
- `scripts/check.sh` here chains the bug-020 check (its host contracts must
  still hold) and asserts the new markers; `scripts/reapply.sh` restores the
  executable bit via the bug-020 reapply and is idempotent.

## Acceptance evidence

`EVIDENCE.md`: `--routes --json` prints **8** routes on this deployment;
an empty scratch `DSH_HOME` prints `routes: UNKNOWN (cannot read …)` and exits
**1**; the in-session `list_subagent_models({provider:"opencode-go"})` output
is pasted beside it and the sets match; unauthenticated `/api/routes` still
answers **401** (and `/v1/models` **404**) on both a scratch boot and the
running server.
