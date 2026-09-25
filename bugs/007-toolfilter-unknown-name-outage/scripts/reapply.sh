#!/bin/bash
# Re-apply the bug-007 patches to the installed bundle. Idempotent: no-ops when present.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
SUB="$BASE/dsh-subagent/lib/index.js"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."
grep -q "function restrictChildTools(" "$SUB" 2>/dev/null || patch -N -s "$SUB" "$BUG/patches/dsh-subagent-tolerant-child-filter.patch" || {
  echo "dsh-subagent patch FAILED (code moved?)"
  exit 1
}
grep -q "function assertKnownToolFilterNames(" "$TOOL" 2>/dev/null || patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-filter-validation.patch" || {
  echo "dsh-tool-subagent patch FAILED (code moved?)"
  exit 1
}
node --check "$SUB" || exit 1
node --check "$TOOL" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
