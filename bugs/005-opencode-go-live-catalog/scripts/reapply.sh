#!/bin/bash
# Re-apply bug-005 to the installed bundle and refresh the live catalog cache.
# Idempotent: no-ops when the patch is present and the cache is current.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
FILE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js"
CACHE="${DSH_HOME:-$HOME/.dsh}/storages/llm-pi-ai/catalog/opencode-go.json"

markers_present() {
  grep -q "function startLiveCatalogRefresh(" "$FILE" 2>/dev/null &&
    grep -q "zen/go/v1/models" "$FILE" 2>/dev/null
}

if ! markers_present; then
  echo "fix missing -- applying patch..."
  patch -N -s "$FILE" "$BUG/patches/dsh-llm-pi-ai-live-opencode-go-catalog.patch" || {
    echo "patch FAILED (code moved?)"
    exit 1
  }
  node --check "$FILE" || exit 1
fi

if ! node "$HERE/refresh-opencode-go-catalog.mjs"; then
  if [ -s "$CACHE" ]; then
    echo "WARN: refresh failed (offline?); keeping the existing cache"
  else
    echo "refresh FAILED and no catalog cache exists"
    exit 1
  fi
fi

"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
