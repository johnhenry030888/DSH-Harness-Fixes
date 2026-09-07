# DSH Harness Fixes

Local batch of bug investigations and fixes against the DeepSeek Harness (`dsh`)
open-source project (deepseek-ai/deepseek-harness on GitHub).

## Why this exists

- Fixes are developed and tested here against the locally installed `dsh` bundle.
- A `dsh` update overwrites the installed bundle, which can silently drop local
  fixes. Each bug folder has a `scripts/check.sh` that detects whether the fix
  is still present, and a `scripts/reapply.sh` that re-applies it from the
  stored unified diff in `patches/`.
- When the upstream repo is ready to receive the work, the whole batch (report
  + evidence + patches + tests) is submitted together. See `UPSTREAM.md` and
  each bug's `UPSTREAM-DRAFT.md`.

## Layout

    DSH-Harness-Fixes/
      README.md            this file
      AGENTS.md            agent guidance (conventions for adding/verifying bugs)
      STATUS.md            tracking table: every bug, local state, upstream state
      UPSTREAM.md          how to submit work to deepseek-harness
      scripts/check-all.sh runs every bug check.sh
      bugs/<NNN>-<slug>/
        README.md          bug report: symptoms, root cause, fix design
        EVIDENCE.md        where the evidence lives (sessions, seq numbers, logs)
        VERSIONS.md        affected versions, fixed-locally versions
        UPSTREAM-DRAFT.md  ready-to-paste Discussion post + submission status
        patches/*.patch    unified diffs vs the pristine published package
        scripts/check.sh   exit 0 = fix present, 1 = bug present / fix lost
        scripts/reapply.sh re-apply patches to the installed bundle, then verify

## Routine: after every `dsh` update

Run `./scripts/check-all.sh` from this folder.

For each bug reported MISSING, either run its `scripts/reapply.sh`, or -- if the
patch no longer applies cleanly -- treat it as a re-investigation task (the
upstream fix may have landed, or the code may have moved). Record the outcome
in `STATUS.md`.
