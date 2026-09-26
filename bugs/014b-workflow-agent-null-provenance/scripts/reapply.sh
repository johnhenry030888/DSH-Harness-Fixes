#!/bin/bash
# Re-apply the bug-014b patch to the installed bundle. Idempotent: no-ops when present.
# The description hunk applies to pristine sources with or without bug 014's
# recorder patch; the check is marker-based, never version-based.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
REC="$BASE/dsh-tool-workflow/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "read the run record, never the return value" "$REC" 2>/dev/null; then
  patch -N -s "$REC" "$BUG/patches/tool-workflow-agent-null-provenance.patch" || {
    echo "dsh-tool-workflow description patch FAILED (code moved?)"
    exit 1
  }
fi

node --check "$REC" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
