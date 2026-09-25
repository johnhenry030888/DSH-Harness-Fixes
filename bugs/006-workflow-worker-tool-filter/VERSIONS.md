# Versions — bug 006

- First analyzed broken: `@deepseek-ai/dsh-workflow-worker-thread` 0.1.5-rc.2
  (installed bundle, 2026-09-25), with drill evidence from
  `orchestrator-drill-report-v3.md` (2026-09-25) and `-v4.md`. The mechanism
  (no `toolFilter` passthrough in the engine) has been present since the
  worker-thread engine shipped; upstream 0.1.6-alpha.2 still has no
  `toolFilter` reference in this package.
- Verified fixed-locally on 0.1.5-rc.2 (2026-09-25):
  - patch applies to the pristine published source with no fuzz;
  - `node --check` clean;
  - `scripts/check.sh` exit 0 with the fix, exit 1 on a pristine copy;
  - `scripts/reapply.sh` idempotent (second run: "already present");
  - live worker-catalog probe with a temporary `--patch` overlay: denied tools
    absent, nested `workflow` absent; with the option unset the v4 catalog is
    reproduced.
- Pristine sources for diffing: `npm pack
  @deepseek-ai/dsh-workflow-worker-thread@0.1.5-rc.2` from the registry.
- Fix markers checked by `scripts/check.sh` (never the version):
  - `workflow-worker-thread: \`toolFilter\` is configured but names neither`
  - `toolFilter: z.object({`
  - `this.toolFilter !== void 0 ? { toolFilter: this.toolFilter } : {}`
  - `this.toolFilter = toolFilter;`
- After a `dsh` update: run `scripts/check-all.sh`. If bug 006 is MISSING, run
  `scripts/reapply.sh`; if the patch no longer applies, re-investigate (code
  moved?) or check whether upstream added a worker `toolFilter` (then mark
  UPSTREAMED in root `STATUS.md`).
