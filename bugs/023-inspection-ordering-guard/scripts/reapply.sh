#!/bin/bash
# Re-apply the bug-023 patches to the installed bundle. Idempotent: no-ops when present.
# The dsh-subagent patch stacks on bugs 007/013/017/018/019 (same file);
# the list-agents patch stacks on bug 010 (same file).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
LIST="$BASE/dsh-tool-subagent-control/lib/types/list-agents.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function assertInspectionOrdering(" "$SUB" 2>/dev/null; then
  if ! grep -q "read-only child" "$SUB" 2>/dev/null; then
    "$HERE/../019-child-write-scope/scripts/reapply.sh" || {
      echo "bug 019 must be applied before bug 023's dsh-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-inspection-guard.patch" || {
    echo "dsh-subagent inspection-guard patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "filePolicy" "$LIST" 2>/dev/null; then
  if ! grep -q "checkedAt" "$LIST" 2>/dev/null; then
    "$HERE/../010-control-surface-ergonomics/scripts/reapply.sh" || {
      echo "bug 010 must be applied before bug 023's list-agents patch"
      exit 1
    }
  fi
  patch -N -s "$LIST" "$BUG/patches/dsh-tool-subagent-control-inspection-state.patch" || {
    echo "dsh-tool-subagent-control inspection-state patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$SUB" "$LIST"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
