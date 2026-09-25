#!/bin/bash
# Re-apply the bug-006 patch to the installed bundle. Idempotent: no-ops when present.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
FILE="$BASE/dsh-workflow-worker-thread/lib/index.js"
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi
echo "fix missing -- applying patch..."
patch -N -s "$FILE" "$BUG/patches/dsh-workflow-worker-thread-tool-filter.patch" || {
  echo "workflow-worker-thread patch FAILED (code moved?)"
  exit 1
}
node --check "$FILE" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
