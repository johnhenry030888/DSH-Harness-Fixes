#!/bin/bash
# Re-apply the bug-030 patches to the installed bundle. Idempotent: no-ops when present.
# dsh-agent-loop stacks on bug 010; the control description is raw pristine;
# the dsh-subagent banner line stacks on the 026/027/028/029 chain.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
LOOP="$BASE/dsh-agent-loop/lib/index.js"
CTRL="$BASE/dsh-tool-subagent-control/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "cancelInFlightToolCall()" "$LOOP" 2>/dev/null; then
  "$HERE/../../010-control-surface-ergonomics/scripts/reapply.sh" || {
    echo "bug 010 must be applied before bug 030's dsh-agent-loop patch"
    exit 1
  }
  patch -N -s "$LOOP" "$BUG/patches/dsh-agent-loop-steer-cancels-tool-call.patch" || {
    echo "dsh-agent-loop steer patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "interruptToolCall?: boolean" "$BASE/dsh-agent/lib/types/runtime-types.d.ts" 2>/dev/null; then
  patch -N -s "$BASE/dsh-agent/lib/types/runtime-types.d.ts" "$BUG/patches/dsh-agent-steer-interrupt-types.patch" || {
    echo "dsh-agent steer-interrupt types patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "cancel-then-replan" "$CTRL" 2>/dev/null; then
  patch -N -s "$CTRL" "$BUG/patches/dsh-tool-subagent-control-steer-description.patch" || {
    echo "dsh-tool-subagent-control steer-description patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "A send_message steer from the parent cancels" "$SUB" 2>/dev/null; then
  if ! grep -q "const workerPersona" "$SUB" 2>/dev/null; then
    "$HERE/../../029-compact-worker-persona/scripts/reapply.sh" || {
      echo "bug 029 must be applied before bug 030's dsh-subagent patch (stack order)"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-steer-cancellation.patch" || {
    echo "dsh-subagent steer-cancellation patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$LOOP" "$CTRL" "$SUB"; do node --check "$f" || exit 1; done
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
