#!/bin/bash
# Exit 0 = bug-016b fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The guard itself, plus the base query it guards (bug 016 must still be applied).
marker "is mutually exclusive with" "$TOOL"
marker "omit the route query to read this layer's own catalog" "$TOOL"
marker "const conflicting = [args.provider === void 0 ? void 0 :" "$TOOL"
marker "function listAgentCatalog(ctx, exec)" "$TOOL"
marker "if (args.catalog === true) {" "$TOOL"

if [ "$ok" -eq 0 ]; then
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-016b fix PRESENT"; else echo "bug-016b fix MISSING"; fi
exit "$ok"
