#!/bin/bash
# Re-apply the bug-029 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-subagent patch stacks on bugs 018/019 (persona/composition region) and
# is applied after 026/027/028 for the documented chain order.
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
    echo "bug 018 must be applied before bug 029's dsh-subagent patch"
    exit 1
  }
fi
if ! grep -q "This layer advertises" "$SUB" 2>/dev/null; then
  "$HERE/../../027-child-tool-count-banner/scripts/reapply.sh" || {
    echo "bug 027 must be applied before bug 029's dsh-subagent patch (stack order)"
    exit 1
  }
fi
if ! grep -q "const errorCode = toError(error).code;" "$SUB" 2>/dev/null; then
  "$HERE/../../028-workflow-agent-failure-code/scripts/reapply.sh" || {
    echo "bug 028 must be applied before bug 029's dsh-subagent patch (stack order)"
    exit 1
  }
fi

patch -N -s "$SUB" "$BUG/patches/dsh-subagent-worker-persona.patch" || {
  echo "dsh-subagent worker-persona patch FAILED (code moved?)"
  exit 1
}

node --check "$SUB" || exit 1
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
