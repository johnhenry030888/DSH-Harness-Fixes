#!/bin/bash
# Exit 0 = bug-001 fix present in the installed bundle, 1 = missing.
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
DRIVER="$BASE/dsh-goal-round-driver/lib/index.js"
TOOLS="$BASE/dsh-tools/lib/index.js"
ok=0
grep -q "GOAL_ROUND_ASK_DENIAL" "$DRIVER" 2>/dev/null || {
  echo "missing: driver denial constant"
  ok=1
}
grep -q "installAskGuard" "$DRIVER" 2>/dev/null || {
  echo "missing: driver guard hooks"
  ok=1
}
grep -q "awaiting a binding and returning a constant" "$TOOLS" 2>/dev/null || {
  echo "missing: SDK instruction line"
  ok=1
}
if [ "$ok" -eq 0 ]; then echo "bug-001 fix PRESENT"; else echo "bug-001 fix MISSING"; fi
exit "$ok"
