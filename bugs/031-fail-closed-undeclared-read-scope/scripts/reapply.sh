#!/bin/bash
# Re-apply the bug-031 patches to the installed bundle. Idempotent: no-ops when present.
# The dsh-session patch is raw pristine; the dsh-subagent guard patch stacks on
# the 023/026 inspection-guard chain (same file).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
SESSION="$BASE/dsh-session/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function declaredPromptTrees(prompt)" "$SUB" 2>/dev/null; then
  "$HERE/../../026-target-path-ordering-guard/scripts/reapply.sh" || {
    echo "bug 026 must be applied before bug 031's dsh-subagent patch"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-fail-closed-scope.patch" || {
  echo "dsh-subagent fail-closed-scope patch FAILED (code moved?)"
  exit 1
}

patch -N -s "$SESSION" "$BUG/patches/dsh-session-known-subagent-events.patch" || {
  echo "dsh-session known-subagent-events patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
node --check "$SESSION" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
