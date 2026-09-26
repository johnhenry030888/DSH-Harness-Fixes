#!/bin/bash
# Re-apply the bug-019 patches to the installed bundle. Idempotent: no-ops when present.
# Stacks on bug 012 (tool-subagent), bug 018 (dsh-subagent) and bug 014 (driver).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "readOnly: z.boolean().default(false)" "$TOOL" 2>/dev/null; then
  if ! grep -q "async function modelRouteRejection(llm, provider, model)" "$TOOL" 2>/dev/null; then
    "$HERE/../012-route-classifier-three-sources/scripts/reapply.sh" || {
      echo "bug 012 must be applied before bug 019's tool-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-read-only-row.patch" || {
    echo "dsh-tool-subagent read-only-row patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "read-only child" "$SUB" 2>/dev/null; then
  if ! grep -q "subagent:layer" "$SUB" 2>/dev/null; then
    "$HERE/../018-child-layer-identity/scripts/reapply.sh" || {
      echo "bug 018 must be applied before bug 019's dsh-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-read-only-enforcement.patch" || {
    echo "dsh-subagent read-only-enforcement patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "readOnly: request.readOnly" "$DRIVER" 2>/dev/null; then
  if ! grep -q "function turnDiagnostic(" "$DRIVER" 2>/dev/null; then
    "$HERE/../014-workflow-run-record-error/scripts/reapply.sh" || {
      echo "bug 014 must be applied before bug 019's driver patch"
      exit 1
    }
  fi
  patch -N -s "$DRIVER" "$BUG/patches/dsh-subagent-in-process-driver-read-only.patch" || {
    echo "dsh-subagent-in-process-driver read-only patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$TOOL" "$SUB" "$DRIVER"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
