#!/bin/bash
# Exit 0 = bug-024 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
LLM="$BASE/dsh-llm/lib/index.js"
PIAI="$BASE/dsh-llm-pi-ai/lib/index.js"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
REC="$BASE/dsh-tool-workflow/lib/index.js"
TYPES="$BASE/dsh-tool-workflow/lib/types/types.d.ts"
ok=0

marker() {
  grep -F -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")")/$(basename "$2"))"
    ok=1
  }
}

# One shared formatter and one machine-code pair own the model-resolution diagnostic.
marker "function modelResolutionDiagnostic(provider, model, served)" "$LLM"
marker "const MODEL_NOT_CONFIGURED_CODE = \"MODEL_NOT_CONFIGURED\"" "$LLM"
marker "const UNKNOWN_MODEL_CODE = \"UNKNOWN_MODEL\"" "$LLM"
marker "modelResolutionDiagnostic," "$LLM"
# Both call paths render through it.
marker "modelResolutionDiagnostic(provider, model, catalogModels(provider).has(model))" "$PIAI"
marker "const diagnostic = modelResolutionDiagnostic(provider, model, catalog);" "$TOOL"
if [ "$(grep -c "throw await modelRouteRejection(llm," "$TOOL" 2>/dev/null)" -lt 2 ]; then
  echo "missing: both rejection sites must throw the classified error"
  ok=1
fi
marker '"ROUTE_NOT_ALLOWED"' "$TOOL"

# run-end carries the contained failure summary.
marker "const failures = /* @__PURE__ */ new Map();" "$REC"
marker "failedAgents: failure.count" "$REC"
marker "failures.delete(runId);" "$REC"
marker "readonly failedAgents?: number;" "$TYPES"

if [ "$ok" -eq 0 ]; then
  for f in "$LLM" "$PIAI" "$TOOL" "$REC"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")")/$(basename "$f") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-024 fix PRESENT"; else echo "bug-024 fix MISSING"; fi
exit "$ok"
