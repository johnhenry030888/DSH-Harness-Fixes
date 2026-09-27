#!/bin/bash
# Re-apply the bug-033 patches to the installed bundle. Idempotent: no-ops when present.
# dsh-subagent stacks on 031/032/036 (same file); dsh-tool-subagent stacks on
# 019 (its readOnly row config is the patch's context anchor).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
SUB_TYPES="$BASE/dsh-subagent/lib/types/types.d.ts"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q 'declaredWorkOf(agent) {' "$SUB" 2>/dev/null; then
  "$HERE/../../036-list-agents-declared-tree/scripts/reapply.sh" || {
    echo "bug 036 must be applied before bug 033's dsh-subagent patch"
    exit 1
  }
fi

if ! grep -q 'readOnly: z.boolean().default(false)' "$TOOL" 2>/dev/null; then
  "$HERE/../../019-child-write-scope/scripts/reapply.sh" || {
    echo "bug 019 must be applied before bug 033's dsh-tool-subagent patch"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-box-deadline.patch" || {
  echo "dsh-subagent box-deadline patch FAILED (code moved?)"
  exit 1
}

patch -N -s "$SUB_TYPES" "$BUG/patches/dsh-subagent-box-types.patch" || {
  echo "dsh-subagent box-types patch FAILED (code moved?)"
  exit 1
}

patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-box-option.patch" || {
  echo "dsh-tool-subagent box-option patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
node --check "$TOOL" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
