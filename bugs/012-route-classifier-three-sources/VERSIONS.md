# Versions — bug 012

- First analyzed broken: `@deepseek-ai/dsh-tool-subagent` /
  `@deepseek-ai/dsh-llm` / `@deepseek-ai/dsh-llm-pi-ai` 0.1.5-rc.2 (installed
  bundle with fixes 003/005/009 applied), from drill v6 (2026-09-25) and
  reconfirmed in v7/v8.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-26):
  - all three patches apply to pristine published sources with their stacks
    (003/005/007–009/011) applied, no fuzz;
  - `node --check` clean on all three files;
  - `scripts/check.sh` exit 1 pre-fix (verified against a pristine+existing
    tree), 0 post-fix; `scripts/reapply.sh` idempotent;
  - live: `glm-5.3-flash` and `gpt-5.6-luna` report *served-but-not-configured*;
    `totally-invented-model-xyz` reports *not served*; `mimo-v2.5` @ medium
    spawns and completes.
- Pristine sources: `npm pack @deepseek-ai/dsh-llm@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-llm-pi-ai@0.1.5-rc.2`,
  `npm pack @deepseek-ai/dsh-tool-subagent@0.1.5-rc.2`.
- Fix markers (checked by `scripts/check.sh`, never the version):
  `modelRouteRejection`, `is not configured for this deployment`,
  `listCatalogModels`/`detachCatalog` in `dsh-llm`,
  `catalogModels(provider).values()` in `dsh-llm-pi-ai`.
- Note: this patch **supersedes bug 009's class-1 wording**; 009's check.sh was
  updated to assert the class rather than the exact old sentence (its fix is
  still present and distinct).
- After a `dsh` update: run `scripts/check-all.sh`. If bug 012 is MISSING, run
  `scripts/reapply.sh`; if a patch no longer applies, re-investigate or check
  whether upstream added catalog-aware classification (then mark UPSTREAMED).
