#!/bin/bash
# Exit 0 = bug-017 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
TYPES="$BASE/dsh-subagent/lib/types/types.d.ts"
LIFECYCLE="$BASE/dsh-subagent/lib/types/lifecycle.d.ts"
SOURCE="$BASE/dsh-subagent/lib/types/continuation-messages.d.ts"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$2"))"
    ok=1
  }
}

# The Activation observer captures the stop moment and the child's last write.
marker "const lastActivityTime = own.at(-1)?.time;" "$SUB"
marker "stopTime: Date.now()," "$SUB"
marker "...lastActivityTime === void 0 ? {} : { lastActivityTime }," "$SUB"
# The settlement notice payload and text carry both.
marker '...stopTime === void 0 ? {} : { stopTime },' "$SUB"
# shellcheck disable=SC2016  # the marker is a literal grep pattern, not an expansion
marker 'Stop time: ${new Date(stopTime).toISOString()}' "$SUB"
# Seam type parity.
marker "readonly stopTime?: number;" "$TYPES"
marker "readonly lastActivityTime?: number;" "$TYPES"
marker "readonly stopTime?: number;" "$LIFECYCLE"
marker "readonly lastActivityTime?: number;" "$SOURCE"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent/lib/index.js does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-017 fix PRESENT"; else echo "bug-017 fix MISSING"; fi
exit "$ok"
