#!/bin/bash
# Re-apply the bug-026 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-subagent patch stacks on bug 023's inspection guard (same file).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function inspectionConflicts(ctx, parent, readOnlyRequested)" "$SUB" 2>/dev/null; then
  "$HERE/../../023-inspection-ordering-guard/scripts/reapply.sh" || {
    echo "bug 023 must be applied before bug 026's dsh-subagent patch"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-target-path-ordering.patch" || {
  echo "dsh-subagent target-path patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
