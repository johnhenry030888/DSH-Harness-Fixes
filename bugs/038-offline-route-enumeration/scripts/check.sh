#!/bin/bash
# Exit 0 = the bug-038 deliverable is present: the bug-020 helper's offline
# `--routes` mode and the bug-020 README's "How to enumerate routes" section.
# There is no harness patch: the fix is a documented, offline client-side
# enumeration over the same two local sources the host composes routes from.
#
# The marker needles are literal text copied from the helper and README; no
# shell expansion is intended.
# shellcheck disable=SC2016
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG020="$HERE/../../020-scriptable-session-creation"
HELPER="$BUG020/scripts/dsh-local-session.mjs"
README="$BUG020/README.md"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$2"))"
    ok=1
  }
}

# The bug-020 deliverable and the host contracts it drives must still hold;
# its output is surfaced only when it fails, so the suite's PRESENT count stays
# one line per fix.
if [ -x "$BUG020/scripts/check.sh" ]; then
  if ! bug020_output="$("$BUG020/scripts/check.sh" 2>&1)"; then
    printf '%s\n' "$bug020_output"
    ok=1
  fi
else
  echo "missing: executable $BUG020/scripts/check.sh"
  ok=1
fi

# Bug 038: the offline --routes mode (policy ∩ catalogue, basis line, honest
# UNKNOWN failure) and its documented authority/basis.
marker 'args.routes = true;' "$HELPER"
marker 'function readPolicyRoutes(settingsPath)' "$HELPER"
marker 'function readCatalogRoutes(catalogDir)' "$HELPER"
marker '#subagent-model-selection.allowedModels' "$HELPER"
marker 'routes: UNKNOWN (' "$HELPER"
marker '## How to enumerate routes' "$README"
marker 'The authority is the **in-session `list_subagent_models` tool**' "$README"

if [ "$ok" -eq 0 ]; then echo "bug-038 fix PRESENT"; else echo "bug-038 fix MISSING"; fi
exit "$ok"
