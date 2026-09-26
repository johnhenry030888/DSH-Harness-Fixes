#!/bin/bash
# Re-apply the bug-027 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-subagent patch stacks on bug 018's subagent:layer banner (same file);
# 026's target-path patch is independent but is applied first for determinism.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "subagent:layer" "$SUB" 2>/dev/null; then
  "$HERE/../../018-child-layer-identity/scripts/reapply.sh" || {
    echo "bug 018 must be applied before bug 027's dsh-subagent patch"
    exit 1
  }
fi
if ! grep -q "function declaredTreePaths(text)" "$SUB" 2>/dev/null; then
  "$HERE/../../026-target-path-ordering-guard/scripts/reapply.sh" || {
    echo "bug 026 must be applied before bug 027's dsh-subagent patch (stack order)"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-banner-tool-count.patch" || {
  echo "dsh-subagent banner-count patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
