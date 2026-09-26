#!/bin/bash
# Re-apply the bug-028 patches to the installed bundle. Idempotent: no-ops when present.
# Stacks: driver on 013/014/019 (via 014's reapply); worker-thread on 006/014;
# tool-workflow on 014/014b/024; workflow types on 014; subagent on the 026/027 chain.
#
# The `grep -F` needles below are literal patterns copied from the bundle's
# source text, where template literals escape their own backticks; no shell
# expansion is intended.
# shellcheck disable=SC2016
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
SUBT="$BASE/dsh-subagent/lib/types/types.d.ts"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
WORKER="$BASE/dsh-workflow-worker-thread/lib/worker.cjs"
TOOL="$BASE/dsh-tool-workflow/lib/index.js"
TOOLT="$BASE/dsh-tool-workflow/lib/types/types.d.ts"
TYP="$BASE/dsh-workflow/lib/types/types.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function turnFailureCode(" "$DRIVER" 2>/dev/null; then
  if ! grep -q "function turnDiagnostic(" "$DRIVER" 2>/dev/null; then
    "$HERE/../../014-workflow-run-record-error/scripts/reapply.sh" || {
      echo "bug 014 (driver diagnostic) must be applied before bug 028"
      exit 1
    }
  fi
  patch -N -s "$DRIVER" "$BUG/patches/dsh-subagent-in-process-driver-error-code.patch" || {
    echo "dsh-subagent-in-process-driver error-code patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "const errorCode = toError(error).code;" "$SUB" 2>/dev/null; then
  if ! grep -q "This layer advertises" "$SUB" 2>/dev/null; then
    "$HERE/../../027-child-tool-count-banner/scripts/reapply.sh" || {
      echo "bug 027 must be applied before bug 028's dsh-subagent patch (stack order)"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-failure-code.patch" || {
    echo "dsh-subagent failure-code patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "readonly errorCode?: string;" "$SUBT" 2>/dev/null; then
  patch -N -s "$SUBT" "$BUG/patches/dsh-subagent-result-error-code-types.patch" || {
    echo "dsh-subagent result error-code types patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "result.errorCode !== void 0" "$WT" 2>/dev/null; then
  if ! grep -q "...result.diagnostic !== void 0" "$WT" 2>/dev/null; then
    "$HERE/../../014-workflow-run-record-error/scripts/reapply.sh" || {
      echo "bug 014 (worker diagnostic) must be applied before bug 028"
      exit 1
    }
  fi
  patch -N -s "$WT" "$BUG/patches/dsh-workflow-worker-thread-forward-error-code.patch" || {
    echo "dsh-workflow-worker-thread forward-error-code patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "errorCode : \"AGENT_RESULT\"" "$WORKER" 2>/dev/null; then
  patch -N -s "$WORKER" "$BUG/patches/dsh-workflow-worker-thread-typed-agent-failure.patch" || {
    echo "dsh-workflow-worker-thread typed-agent-failure patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "A failed child REJECTS" "$TOOL" 2>/dev/null; then
  if ! grep -qF 'Resolves \`null\` when the child fails' "$TOOL" 2>/dev/null; then
    if ! grep -q "modelResolutionDiagnostic" "$TOOL" 2>/dev/null; then
      "$HERE/../../024-workflow-diagnostics/scripts/reapply.sh" || {
        echo "bug 024 must be applied before bug 028's tool-workflow patch"
        exit 1
      }
    fi
    if ! grep -q "read the run record, never the return value" "$TOOL" 2>/dev/null; then
      "$HERE/../../014b-workflow-agent-null-provenance/scripts/reapply.sh" || {
        echo "bug 014b must be applied before bug 028's tool-workflow patch"
        exit 1
      }
    fi
  fi
  patch -N -s "$TOOL" "$BUG/patches/dsh-tool-workflow-agent-failure-contract.patch" || {
    echo "dsh-tool-workflow agent-failure-contract patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "Machine-readable failure code for a failed member" "$TOOLT" 2>/dev/null; then
  patch -N -s "$TOOLT" "$BUG/patches/dsh-tool-workflow-record-error-code-types.patch" || {
    echo "dsh-tool-workflow record error-code types patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "errorCode?: string;" "$TYP" 2>/dev/null; then
  patch -N -s "$TYP" "$BUG/patches/dsh-workflow-agent-end-error-code-types.patch" || {
    echo "dsh-workflow agent-end error-code types patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$DRIVER" "$SUB" "$WT" "$WORKER" "$TOOL"; do node --check "$f" || exit 1; done
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
