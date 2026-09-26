#!/bin/bash
# Exit 0 = bug-011 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The boot arm contains its own failure and names the row/agent.
marker "boot toolFilter validation deferred for agent" "$TOOL"
marker "the row's pre-spawn check re-validates" "$TOOL"
# The destructive pre-fix arm is gone: no bare call left in the listener.
grep -q 'ctx.on("agent/created", ({ agent }) => {$' "$TOOL" 2>/dev/null || {
  echo "missing: boot arm listener shape"
  ok=1
}
if grep -A 1 'ctx.on("agent/created", ({ agent }) => {$' "$TOOL" 2>/dev/null | grep -q "assertKnownToolFilterNames(ctx.tools"; then
  echo "missing: boot arm still throws out of agent/created"
  ok=1
fi

if [ "$ok" -eq 0 ]; then
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-011 fix PRESENT"; else echo "bug-011 fix MISSING"; fi
exit "$ok"
