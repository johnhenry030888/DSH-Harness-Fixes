#!/bin/bash
# Re-apply the bug-034 patches to the installed bundle. Idempotent: no-ops when present.
# dsh-subagent stacks on 033 (and thus 031/032/036); dsh-agent-loop and the
# control tool stack on 010/030.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
LOOP="$BASE/dsh-agent-loop/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
SUB_TYPES="$BASE/dsh-subagent/lib/types/types.d.ts"
CTRL="$BASE/dsh-tool-subagent-control/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q 'function steerDeliveryRecord(' "$SUB" 2>/dev/null; then
  if ! grep -q 'function assertBoxSeconds(boxSeconds)' "$SUB" 2>/dev/null; then
    "$HERE/../../033-runtime-box-deadline/scripts/reapply.sh" || {
      echo "bug 033 must be applied before bug 034's dsh-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-steer-delivery-record.patch" || {
    echo "dsh-subagent steer-delivery-record patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'readonly deliveredAt?: string;' "$SUB_TYPES" 2>/dev/null; then
  if ! grep -q 'readonly boxSeconds?: number;' "$SUB_TYPES" 2>/dev/null; then
    "$HERE/../../033-runtime-box-deadline/scripts/reapply.sh" || {
      echo "bug 033 must be applied before bug 034's types patch"
      exit 1
    }
  fi
  patch -N -s "$SUB_TYPES" "$BUG/patches/dsh-subagent-steer-options-type.patch" || {
    echo "dsh-subagent steer-options-type patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'function steerBoundaryRecord(' "$LOOP" 2>/dev/null; then
  if ! grep -q 'cancelInFlightToolCall()' "$LOOP" 2>/dev/null; then
    "$HERE/../../030-steer-cancels-in-flight-tool-call/scripts/reapply.sh" || {
      echo "bug 030 must be applied before bug 034's dsh-agent-loop patch"
      exit 1
    }
  fi
  patch -N -s "$LOOP" "$BUG/patches/dsh-agent-loop-steer-boundary-stamp.patch" || {
    echo "dsh-agent-loop steer-boundary-stamp patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'deliveredAt: {' "$CTRL" 2>/dev/null; then
  if ! grep -q 'cancel-then-replan' "$CTRL" 2>/dev/null; then
    "$HERE/../../030-steer-cancels-in-flight-tool-call/scripts/reapply.sh" || {
      echo "bug 030 must be applied before bug 034's control-tool patch"
      exit 1
    }
  fi
  patch -N -s "$CTRL" "$BUG/patches/dsh-tool-subagent-control-delivered-at.patch" || {
    echo "dsh-tool-subagent-control delivered-at patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$LOOP" "$SUB" "$CTRL"; do node --check "$f" || exit 1; done
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
