#!/bin/bash
# Exit 0 = bug-019 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The delegation row opts in with readOnly: true.
marker "readOnly: z.boolean().default(false)" "$TOOL"
marker "...config.readOnly === true ? { readOnly: true } : {}" "$TOOL"
# Composition refuses the file-mutating tools with a named, path-aware error
# and pins the child's file policy to read-only.
marker "read-only child" "$SUB"
marker "allowed write paths: none" "$SUB"
marker "childCtx.tools.guard((exec) => {" "$SUB"
marker "mode: \"read-only\"" "$SUB"
# The flag survives a cold resume through the descriptor.
marker "readOnly: descriptor.readOnly" "$SUB"
marker "readOnly: request.readOnly" "$SUB"
marker "readOnly: request.readOnly" "$DRIVER"

if [ "$ok" -eq 0 ]; then
  for f in "$TOOL" "$SUB" "$DRIVER"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-019 fix PRESENT"; else echo "bug-019 fix MISSING"; fi
exit "$ok"
