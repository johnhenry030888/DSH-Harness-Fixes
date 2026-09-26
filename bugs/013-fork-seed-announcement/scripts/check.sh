#!/bin/bash
# Exit 0 = bug-013 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
FORK="$BASE/dsh-subagent-fork-in-process/lib/index.js"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Numeric seed count on the descriptor (schema + snapshot + both creation paths).
marker "function optionalCount(" "$SUB"
marker "inheritedEventCount" "$SUB"
marker "This layer inherited \${inheritedEventCount} completed event" "$SUB"
# One-shot in-process descriptor enrichment (covers spawn and fork).
marker "attachDescriptorAppend(childCtx, {" "$DRIVER"
# The host warning now fires in both directions.
marker "fork child of session" "$FORK"
marker "inherits \${inheritedEventCount} completed events" "$FORK"

if [ "$ok" -eq 0 ]; then
  for f in "$SUB" "$FORK" "$DRIVER"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-013 fix PRESENT"; else echo "bug-013 fix MISSING"; fi
exit "$ok"
