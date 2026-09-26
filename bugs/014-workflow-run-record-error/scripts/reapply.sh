#!/bin/bash
# Re-apply the bug-014 patches to the installed bundle. Idempotent: no-ops when present.
# The driver patch stacks on bug 013; the worker-thread index patch stacks on bug 006.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
WORKER="$BASE/dsh-workflow-worker-thread/lib/worker.cjs"
REC="$BASE/dsh-tool-workflow/lib/index.js"
TYPES="$BASE/dsh-workflow/lib/types/types.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function turnDiagnostic(" "$DRIVER" 2>/dev/null; then
  if ! grep -q "attachDescriptorAppend(childCtx, {" "$DRIVER" 2>/dev/null; then
    "$HERE/../013-fork-seed-announcement/scripts/reapply.sh" || {
      echo "bug 013 must be applied before bug 014's driver patch"
      exit 1
    }
  fi
  patch -N -s "$DRIVER" "$BUG/patches/dsh-subagent-in-process-driver-diagnostic.patch" || {
    echo "dsh-subagent-in-process-driver diagnostic patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "...result.diagnostic !== void 0" "$WT" 2>/dev/null; then
  if ! grep -q "toolFilter !== void 0 ? { toolFilter: this.toolFilter } : {}" "$WT" 2>/dev/null; then
    "$HERE/../006-workflow-worker-tool-filter/scripts/reapply.sh" || {
      echo "bug 006 must be applied before bug 014's worker-thread host patch"
      exit 1
    }
  fi
  patch -N -s "$WT" "$BUG/patches/dsh-workflow-worker-thread-forward-diagnostic.patch" || {
    echo "dsh-workflow-worker-thread forward-diagnostic patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "requestedProvider: opts.provider" "$WORKER" 2>/dev/null; then
  patch -N -s "$WORKER" "$BUG/patches/dsh-workflow-worker-thread-agent-end-error.patch" || {
    echo "dsh-workflow-worker-thread worker patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "agent.error === void 0" "$REC" 2>/dev/null; then
  patch -N -s "$REC" "$BUG/patches/dsh-tool-workflow-run-record-error.patch" || {
    echo "dsh-tool-workflow run-record patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "requestedProvider?: string;" "$TYPES" 2>/dev/null; then
  patch -N -s "$TYPES" "$BUG/patches/dsh-workflow-agent-info-types.patch" || {
    echo "dsh-workflow agent-info types patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$DRIVER" "$WT" "$WORKER" "$REC"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
