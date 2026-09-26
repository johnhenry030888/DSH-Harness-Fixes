#!/bin/bash
# Exit 0 = bug-018 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
SP="$BASE/dsh-system-prompt/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Leading child-layer banner: identity + removed tools.
marker "subagent:layer" "$SUB"
marker "NOT the orchestrator lead" "$SUB"
marker "This layer's toolFilter removed" "$SUB"
marker "const restriction = composition.toolFilter === void 0 ? void 0 : restrictChildTools(" "$SUB"
# One-shot descriptors now declare the filter too (covers the workflow worker).
if ! grep -A 2 "const ONE_SHOT_DESCRIPTOR_KEYS = new Set(\[" "$SUB" 2>/dev/null | grep -q '"toolFilter"'; then
  echo "missing: one-shot descriptor schema declares toolFilter"
  ok=1
fi
# The layer context has a registered order.
marker "SUBAGENT_LAYER: 118" "$SP"

if [ "$ok" -eq 0 ]; then
  for f in "$SUB" "$SP"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-018 fix PRESENT"; else echo "bug-018 fix MISSING"; fi
exit "$ok"
