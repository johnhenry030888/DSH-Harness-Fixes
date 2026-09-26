#!/bin/bash
# Re-apply the bug-012 patches to the installed bundle. Idempotent: no-ops when present.
# Stacks on bug 009 (tool-subagent + llm) and on bug 005/003 (llm-pi-ai), so those
# are re-applied first when their markers are missing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
LLM="$BASE/dsh-llm/lib/index.js"
PIAI="$BASE/dsh-llm-pi-ai/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "async function modelRouteRejection(llm, provider, model)" "$TOOL" 2>/dev/null; then
  if ! grep -q "does not serve a model with id" "$TOOL" 2>/dev/null; then
    "$HERE/../009-route-effort-diagnostics/scripts/reapply.sh" || {
      echo "bug 009 must be applied before bug 012's tool-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-route-classification.patch" || {
    echo "dsh-tool-subagent route-classification patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "detachCatalog(provider, models) {" "$LLM" 2>/dev/null; then
  if ! grep -q "function describeReasoningEfforts(" "$LLM" 2>/dev/null; then
    "$HERE/../009-route-effort-diagnostics/scripts/reapply.sh" || {
      echo "bug 009 must be applied before bug 012's llm patch"
      exit 1
    }
  fi
  patch -N -s "$LLM" "$BUG/patches/dsh-llm-catalog-classification.patch" || {
    echo "dsh-llm catalog-classification patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "listCatalogModels(provider) {" "$PIAI" 2>/dev/null; then
  if ! grep -q "function liveCatalogPath(" "$PIAI" 2>/dev/null; then
    "$HERE/../005-opencode-go-live-catalog/scripts/reapply.sh" || {
      echo "bug 005 must be applied before bug 012's llm-pi-ai patch"
      exit 1
    }
  fi
  if ! grep -q "function opencodeSessionHeaders(" "$PIAI" 2>/dev/null; then
    "$HERE/../003-opencode-go-missing-session-header/scripts/reapply.sh" || {
      echo "bug 003 must be applied before bug 012's llm-pi-ai patch"
      exit 1
    }
  fi
  patch -N -s "$PIAI" "$BUG/patches/dsh-llm-pi-ai-catalog-classification.patch" || {
    echo "dsh-llm-pi-ai catalog-classification patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$TOOL" "$LLM" "$PIAI"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
