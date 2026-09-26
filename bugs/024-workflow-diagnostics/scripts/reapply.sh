#!/bin/bash
# Re-apply the bug-024 patches to the installed bundle. Idempotent: no-ops when present.
# Stacks on bug 012 (dsh-llm + dsh-llm-pi-ai), bug 019 (dsh-tool-subagent),
# and bug 014/014b (dsh-tool-workflow).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
LLM="$BASE/dsh-llm/lib/index.js"
PIAI="$BASE/dsh-llm-pi-ai/lib/index.js"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
REC="$BASE/dsh-tool-workflow/lib/index.js"
TYPES="$BASE/dsh-tool-workflow/lib/types/types.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

apply() {
  local file="$1" marker="$2" patchfile="$3"
  grep -q "$marker" "$file" 2>/dev/null && return 0
  patch -N -s "$file" "$patchfile" || {
    echo "$(basename "$file") patch FAILED (code moved?)"
    exit 1
  }
}

if ! grep -q "function modelResolutionDiagnostic(" "$LLM" 2>/dev/null; then
  if ! grep -q "async listCatalogModels(provider) {" "$LLM" 2>/dev/null; then
    "$HERE/../../012-route-classifier-three-sources/scripts/reapply.sh" || {
      echo "bug 012 must be applied before bug 024's dsh-llm patch"
      exit 1
    }
  fi
  apply "$LLM" "modelResolutionDiagnostic" "$BUG/patches/dsh-llm-model-resolution-diagnostic.patch"
fi

if ! grep -q "modelResolutionDiagnostic(provider, model, catalogModels(provider).has(model))" "$PIAI" 2>/dev/null; then
  if ! grep -q "listCatalogModels(provider) {" "$PIAI" 2>/dev/null; then
    "$HERE/../../012-route-classifier-three-sources/scripts/reapply.sh" || {
      echo "bug 012 must be applied before bug 024's llm-pi-ai patch"
      exit 1
    }
  fi
  apply "$PIAI" "modelResolutionDiagnostic(provider, model, catalogModels" "$BUG/patches/dsh-llm-pi-ai-model-resolution-diagnostic.patch"
fi

if ! grep -q "const diagnostic = modelResolutionDiagnostic(provider, model, catalog);" "$TOOL" 2>/dev/null; then
  if ! grep -q "readOnly: z.boolean().default(false)" "$TOOL" 2>/dev/null; then
    "$HERE/../../019-child-write-scope/scripts/reapply.sh" || {
      echo "bug 019 must be applied before bug 024's tool-subagent patch"
      exit 1
    }
  fi
  apply "$TOOL" "modelResolutionDiagnostic(provider, model, catalog)" "$BUG/patches/dsh-tool-subagent-model-resolution-diagnostic.patch"
fi

if ! grep -q "failedAgents: failure.count" "$REC" 2>/dev/null; then
  if ! grep -q "agent.requestedProvider === void 0" "$REC" 2>/dev/null; then
    "$HERE/../../014-workflow-run-record-error/scripts/reapply.sh" || {
      echo "bug 014 must be applied before bug 024's run-end patch"
      exit 1
    }
  fi
  if ! grep -q "read the run record, never the return value" "$REC" 2>/dev/null; then
    "$HERE/../../014b-workflow-agent-null-provenance/scripts/reapply.sh" || {
      echo "bug 014b must be applied before bug 024's run-end patch"
      exit 1
    }
  fi
  apply "$REC" "failedAgents: failure.count" "$BUG/patches/dsh-tool-workflow-run-end-failure.patch"
fi

if ! grep -q "readonly failedAgents?: number;" "$TYPES" 2>/dev/null; then
  patch -N -s "$TYPES" "$BUG/patches/dsh-tool-workflow-run-end-types.patch" || {
    echo "dsh-tool-workflow types patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$LLM" "$PIAI" "$TOOL" "$REC"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
