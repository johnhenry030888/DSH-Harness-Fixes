#!/bin/bash
# Re-apply the bug-016 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-tool-subagent patch stacks on bugs 007/008/009/011/012/019/024 (same file),
# and on 003/005 for the route classifier it sits beside.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "modelResolutionDiagnostic" "$TOOL" 2>/dev/null; then
  "$HERE/../../024-workflow-diagnostics/scripts/reapply.sh" || {
    echo "bug 024 must be applied before bug 016's dsh-tool-subagent patch"
    exit 1
  }
fi

patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-catalog-query.patch" || {
  echo "dsh-tool-subagent catalog-query patch FAILED (code moved?)"
  exit 1
}

node --check "$TOOL" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
