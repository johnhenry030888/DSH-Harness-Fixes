#!/bin/bash
# Re-apply the bug-036 patches to the installed bundle. Idempotent: no-ops when present.
# The service patch stacks on 031+032 (shared harvester); the list-agents patch
# stacks on 023's inspection-state projection of the same file.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
TYPES="$BASE/dsh-subagent/lib/types/index.d.ts"
LIST="$BASE/dsh-tool-subagent-control/lib/types/list-agents.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function declaredWorkOfSession(session)" "$SUB" 2>/dev/null; then
  "$HERE/../../032-declared-path-overlap-pairs/scripts/reapply.sh" || {
    echo "bug 032 must be applied before bug 036's dsh-subagent patch"
    exit 1
  }
fi

if ! grep -q "entry.filePolicy" "$LIST" 2>/dev/null; then
  "$HERE/../../023-inspection-ordering-guard/scripts/reapply.sh" || {
    echo "bug 023 must be applied before bug 036's list-agents patch"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-declared-work-service.patch" || {
  echo "dsh-subagent declared-work-service patch FAILED (code moved?)"
  exit 1
}

patch -N -s "$TYPES" "$BUG/patches/dsh-subagent-declared-work-types.patch" || {
  echo "dsh-subagent declared-work-types patch FAILED (code moved?)"
  exit 1
}

patch -N -s "$LIST" "$BUG/patches/dsh-tool-subagent-control-declared-tree.patch" || {
  echo "dsh-tool-subagent-control declared-tree patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
node --check "$LIST" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
