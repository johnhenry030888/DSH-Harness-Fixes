#!/bin/bash
# Re-apply the bug-021 patches to the installed bundle. Idempotent: no-ops when present.
# The two packages carry no earlier local patches, so both patches apply to
# pristine 0.1.5-rc.2 sources directly.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SANDBOX="$BASE/dsh-sandbox/lib/index.js"
LOCAL="$BASE/dsh-sandbox-local/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function tempWriteRoots()" "$SANDBOX" 2>/dev/null; then
  patch -N -s "$SANDBOX" "$BUG/patches/sandbox-temp-roots.patch" || {
    echo "dsh-sandbox temp-roots patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "CONFINED_TEMP_DIR" "$LOCAL" 2>/dev/null; then
  patch -N -s "$LOCAL" "$BUG/patches/sandbox-local-temp-mount.patch" || {
    echo "dsh-sandbox-local temp-mount patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$SANDBOX" "$LOCAL"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
