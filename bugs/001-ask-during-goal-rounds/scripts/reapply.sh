#!/bin/bash
# Re-apply bug-001 patches to the installed bundle. Idempotent: no-ops when present.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
DRIVER="$BASE/dsh-goal-round-driver/lib/index.js"
TOOLS="$BASE/dsh-tools/lib/index.js"
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi
echo "fix missing -- applying patches..."
patch -N -s "$DRIVER" "$BUG/patches/goal-round-driver.patch" || {
  echo "DRIVER patch FAILED (code moved?)"
  exit 1
}
patch -N -s "$TOOLS" "$BUG/patches/dsh-tools-sdk.patch" || {
  echo "TOOLS patch FAILED (code moved?)"
  exit 1
}
node --check "$DRIVER" || exit 1
node --check "$TOOLS" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
