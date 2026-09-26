#!/bin/bash
# Re-apply the bug-016b patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-tool-subagent patch stacks on bug 016 (same seam) and therefore on every
# patch 016 stacks on: 007/008/009/011/012/019/024.
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

if ! grep -q "args.catalog === true" "$TOOL" 2>/dev/null; then
  "$HERE/../../016-catalog-self-query/scripts/reapply.sh" || {
    echo "bug 016 must be applied before bug 016b's exclusivity guard"
    exit 1
  }
fi

patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-catalog-exclusivity.patch" || {
  echo "dsh-tool-subagent catalog-exclusivity patch FAILED (code moved?)"
  exit 1
}

node --check "$TOOL" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
