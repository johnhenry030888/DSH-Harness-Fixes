#!/bin/bash
# Exit 0 = bug-016 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

marker "function listAgentCatalog(ctx, exec)" "$TOOL"
marker "args.catalog === true" "$TOOL"
marker "report this layer's own model-facing tool catalog" "$TOOL"
marker "catalog: {" "$TOOL"

if [ "$ok" -eq 0 ]; then
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-016 fix PRESENT"; else echo "bug-016 fix MISSING"; fi
exit "$ok"
