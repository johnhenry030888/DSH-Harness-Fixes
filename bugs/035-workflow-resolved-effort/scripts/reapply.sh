#!/bin/bash
# Re-apply the bug-035 patches to the installed bundle. Idempotent: no-ops when present.
# dsh-llm and dsh-llm-pi-ai stack on 024 (and thus 012); dsh-tool-workflow and
# dsh-workflow-worker-thread stack on 028 (and thus 014/014b/024); the workflow
# type patch stacks on 028; dsh-llm-deepseek is raw pristine.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-workflow/lib/index.js"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
LLM="$BASE/dsh-llm/lib/index.js"
LLMT="$BASE/dsh-llm/lib/types/call-config.d.ts"
PIAI="$BASE/dsh-llm-pi-ai/lib/index.js"
DEEPSEEK="$BASE/dsh-llm-deepseek/lib/index.js"
WFT="$BASE/dsh-workflow/lib/types/types.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q 'defaulted.reasoningEffort === "default"' "$LLM" 2>/dev/null; then
  if ! grep -q "function modelResolutionDiagnostic(" "$LLM" 2>/dev/null; then
    "$HERE/../../024-workflow-diagnostics/scripts/reapply.sh" || {
      echo "bug 024 must be applied before bug 035's dsh-llm patch"
      exit 1
    }
  fi
  patch -N -s "$LLM" "$BUG/patches/dsh-llm-default-effort-sentinel.patch" || {
    echo "dsh-llm default-effort-sentinel patch FAILED (code moved?)"
    exit 1
  }
  patch -N -s "$LLMT" "$BUG/patches/dsh-llm-call-config-type.patch" || {
    echo "dsh-llm call-config-type patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'options.reasoningEffort === "default"' "$PIAI" 2>/dev/null; then
  if ! grep -q "modelResolutionDiagnostic(provider, model, catalogModels" "$PIAI" 2>/dev/null; then
    "$HERE/../../024-workflow-diagnostics/scripts/reapply.sh" || {
      echo "bug 024 must be applied before bug 035's llm-pi-ai patch"
      exit 1
    }
  fi
  patch -N -s "$PIAI" "$BUG/patches/dsh-llm-pi-ai-default-sentinel.patch" || {
    echo "dsh-llm-pi-ai default-sentinel patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'options.reasoningEffort === "default"' "$DEEPSEEK" 2>/dev/null; then
  patch -N -s "$DEEPSEEK" "$BUG/patches/dsh-llm-deepseek-default-sentinel.patch" || {
    echo "dsh-llm-deepseek default-sentinel patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'const effortFields = (agent) => {' "$TOOL" 2>/dev/null; then
  if ! grep -q "A failed child REJECTS" "$TOOL" 2>/dev/null; then
    "$HERE/../../028-workflow-agent-failure-code/scripts/reapply.sh" || {
      echo "bug 028 must be applied before bug 035's tool-workflow patch"
      exit 1
    }
  fi
  patch -N -s "$TOOL" "$BUG/patches/dsh-tool-workflow-effort-record.patch" || {
    echo "dsh-tool-workflow effort-record patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'async resolveChildEffort(request, run)' "$WT" 2>/dev/null; then
  if ! grep -q "result.errorCode !== void 0" "$WT" 2>/dev/null; then
    "$HERE/../../028-workflow-agent-failure-code/scripts/reapply.sh" || {
      echo "bug 028 must be applied before bug 035's worker-thread patch"
      exit 1
    }
  fi
  patch -N -s "$WT" "$BUG/patches/dsh-workflow-worker-thread-effort-resolution.patch" || {
    echo "dsh-workflow-worker-thread effort-resolution patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q 'resolvedEffort?: string | null;' "$WFT" 2>/dev/null; then
  if ! grep -q "errorCode?: string;" "$WFT" 2>/dev/null; then
    "$HERE/../../028-workflow-agent-failure-code/scripts/reapply.sh" || {
      echo "bug 028 must be applied before bug 035's workflow types patch"
      exit 1
    }
  fi
  patch -N -s "$WFT" "$BUG/patches/dsh-workflow-agent-info-type.patch" || {
    echo "dsh-workflow agent-info-type patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$TOOL" "$WT" "$LLM" "$PIAI" "$DEEPSEEK"; do node --check "$f" || exit 1; done
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
