# STATE — DSH-Harness-Fixes

> Long-horizon bookmark. Keep this file current: every autonomous turn ends by updating it.

- Objective: Batch project for DeepSeek Harness bug fixes
- Stack: polyglot | Features: none
- Phase: bug 005 added; all five local fixes applied to `dsh` 0.1.5-rc.2.
- What changed this turn (2026-09-25, bug 005 `opencode-go` live catalog):
  - Root cause: dsh served opencode-go models from pi-ai's release-locked
    bundled catalog (27) and a 5-entry `settings.yaml` pin that *replaces* the
    catalog; `discoverModels()` short-circuits on catalog providers,
    `reuseCatalogProvider()` drops `refreshModels`, and dsh never calls
    `Models.refresh()`. Live: gateway 42 ids / models.dev 32 active /
    `opencode models` 32.
  - Fix: patch `dsh-llm-pi-ai` to merge a live catalog overlay
    (`catalogModels()`), refresh it in the background at host start from the
    gateway listing ∩ models.dev non-deprecated (descriptor conversion seeded
    by pi-ai's own entries, family/npm fallbacks), cache it atomically at
    `~/.dsh/storages/llm-pi-ai/catalog/opencode-go.json`, invalidate the
    adapter snapshot and re-announce routes when it changes. Removed the
    `opencode-go` `models:` pin from `~/.dsh/settings.yaml` (backup:
    `settings.yaml.bak-bug005-20260925`).
  - New files: `bugs/005-opencode-go-live-catalog/` (README, EVIDENCE,
    VERSIONS, UPSTREAM-DRAFT, patch, check/reapply/refresh scripts);
    `STATUS.md` updated.
- Verification: pristine->installed patch applies no-fuzz on top of bug 003;
  `node --check` clean; `check.sh` exit 0 with live parity (served ids ==
  `opencode models` opencode-go ids, 32/32); failure paths (settings pin,
  truncated cache) exit 1; conversion unit test with stubbed sources;
  headless host turn on `opencode-go/deepseek-v4.1-flash` (live-only id)
  returned `pong`; truncated cache self-healed 31 -> 32 during boot;
  `reapply.sh` idempotent; `check-all.sh`, `verify.sh`, `audit-secrets.sh`
  all exit 0.
- Autonomy loop (run without asking; stop only when verify passes AND tree committed AND pushed (or push explicitly deferred with reason)):
  - [x] lint (`linter-formatter` `lint`) — shellcheck/shfmt/biome/typos clean
  - [x] `./scripts/check-all.sh` + `./scripts/verify.sh` + `audit-secrets.sh`
  - [x] UI gates — N/A (harness bundle patches; no project UI files)
  - [x] visual baseline — N/A
  - [ ] checkpoint/commit (`git`)
  - [ ] push to origin
  - [x] update this file (every turn ends by updating it)
- Open items: the changed-set announcement (`adapter.invalidate()` +
  `registration.replace()`) is code-verified but its picker reload was not
  observed in a browser this run; re-check on the next `dsh web` restart.
  `UPSTREAM-DRAFT.md` for bug 005 is NOT-FILED.
- Decisions: see `docs/decisions.md`.
