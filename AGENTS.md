# Agent guidance -- DSH-Harness-Fixes

This folder is a batch project for DeepSeek Harness bug fixes. Conventions:

## Adding a new bug (bugs/<NNN>-<slug>/)

1. Pick the next number (`ls bugs`). Copy the file set of bug 001 as a template.
2. `README.md`: symptoms, root cause (with file/package references), fix design,
   rejected alternatives and why.
3. `EVIDENCE.md`: session ids, sequence numbers, logs -- everything needed to
   re-verify without the original conversation.
4. `VERSIONS.md`: first version seen broken, versions verified fixed-locally.
   Regenerate with `npm pack <pkg>@<version>` from the registry for pristine
   sources; never reconstruct pristine files by hand.
5. `patches/*.patch`: unified diffs (`diff -u pristine installed`). Verify with
   `patch --dry-run` against a pristine copy before storing.
6. `scripts/check.sh`: must exit 0 when the fix is present, 1 when the bug is
   present. Check by grepping for unique fix markers, never by version alone.
7. `scripts/reapply.sh`: runs check.sh; applies missing patches with
   `patch -N -s <target> <patch>`; re-runs check.sh; syntax-checks touched JS
   with `node --check`. Must be idempotent.
8. `UPSTREAM-DRAFT.md`: Discussion post ready to paste + submission status.
9. Update root `STATUS.md`. Never edit the installed bundle without storing the
   matching patch here first (bundle edits are lost on update).

## After a dsh update

1. Run `scripts/check-all.sh`.
2. For each MISSING bug: try `scripts/reapply.sh`. If the patch fails, check
   whether upstream fixed it (then mark UPSTREAMED) or the code moved (then
   re-investigate and cut a new patch).
3. Update `STATUS.md` and the bug VERSIONS.md.

## Rules

- This project documents and patches the harness install only. Never touch the
  CAPS/working project from here.
- Keep patches minimal and seams-clean: prefer enforcement in the component
  that already owns the lifecycle (as in bug 001: the goal-round driver).
- Record rejected alternatives; upstream reviewers will ask.
