#!/bin/bash
# Exit 0 = bug-007 fix present in the installed bundle, 1 = missing.
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
SUB="$BASE/dsh-subagent/lib/index.js"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# dsh-subagent: the tolerant child composition.
marker "function restrictChildTools(" "$SUB"
marker "cannot be restricted in its scope (dropped from the filter)" "$SUB"
marker "dropped.map((name) => \`\"\${name}\"\`)" "$SUB"

# dsh-tool-subagent: row-identified pre-spawn validation.
marker "function assertKnownToolFilterNames(" "$TOOL"
marker "absent from the child catalog" "$TOOL"
marker "assertKnownToolFilterNames(runtimeCtx.tools, scopeOf(parent.ctx), config, rowLabel)" "$TOOL"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent does not parse under node --check"
    ok=1
  }
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-007 fix PRESENT"; else echo "bug-007 fix MISSING"; fi
exit "$ok"
