#!/bin/bash
# Exit 0 = bug-012 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
LLM="$BASE/dsh-llm/lib/index.js"
PIAI="$BASE/dsh-llm-pi-ai/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Three-source classifier + the distinct served-but-not-configured class.
marker "async function modelRouteRejection(llm, provider, model)" "$TOOL"
marker "is not configured for this deployment" "$TOOL"
marker "the model is configured for this deployment but it is outside the Session's allowed routes" "$TOOL"
# Both rejection sites route through the classifier.
if [ "$(grep -c "modelRouteRejection(llm," "$TOOL" 2>/dev/null)" -lt 2 ]; then
  echo "missing: both rejection sites must call modelRouteRejection"
  ok=1
fi

# Catalog surface on the LLM service and the pi-ai adapter.
marker "async listCatalogModels(provider) {" "$LLM"
marker "detachCatalog(provider, models) {" "$LLM"
marker "listCatalogModels(provider) {" "$PIAI"
marker "catalogModels(provider).values()" "$PIAI"

if [ "$ok" -eq 0 ]; then
  for f in "$TOOL" "$LLM" "$PIAI"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-012 fix PRESENT"; else echo "bug-012 fix MISSING"; fi
exit "$ok"
