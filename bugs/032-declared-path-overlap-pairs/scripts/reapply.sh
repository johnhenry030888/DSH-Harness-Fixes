#!/bin/bash
# Re-apply the bug-032 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-subagent patch stacks directly on bug 031's guard rewrite (same file).
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

if ! grep -q 'refused a read-only delegation that declared no read scope' "$SUB" 2>/dev/null; then
  "$HERE/../../031-fail-closed-undeclared-read-scope/scripts/reapply.sh" || {
    echo "bug 031 must be applied before bug 032's dsh-subagent patch"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-declared-pair-overlap.patch" || {
  echo "dsh-subagent declared-pair-overlap patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
