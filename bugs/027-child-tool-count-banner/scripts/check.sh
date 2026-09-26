#!/bin/bash
# Exit 0 = bug-027 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The layer banner states the authoritative advertised count from the filter's view.
marker "const advertised = view.visible.size;" "$SUB"
marker "This layer advertises \${advertised} tool" "$SUB"
marker "computed from the same registry view the tool filter uses" "$SUB"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-027 fix PRESENT"; else echo "bug-027 fix MISSING"; fi
exit "$ok"
