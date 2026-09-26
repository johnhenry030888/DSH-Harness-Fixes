#!/bin/bash
# Re-apply the bug-011 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-tool-subagent patch stacks on bug 007/008/009, so those are re-applied
# first when their markers are missing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

if ! grep -q "does not serve a model with id" "$TOOL" 2>/dev/null; then
  "$HERE/../009-route-effort-diagnostics/scripts/reapply.sh" || {
    echo "bug 009 must be applied before bug 011's patch"
    exit 1
  }
fi

echo "fix missing -- applying patch..."
patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-boot-arm-non-destructive.patch" || {
  echo "dsh-tool-subagent boot-arm patch FAILED (code moved?)"
  exit 1
}
node --check "$TOOL" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
