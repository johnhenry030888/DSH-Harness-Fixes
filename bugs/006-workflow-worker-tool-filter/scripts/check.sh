#!/bin/bash
# Exit 0 = bug-006 fix present in the installed bundle, 1 = missing.
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
FILE="$BASE/dsh-workflow-worker-thread/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$FILE" 2>/dev/null || {
    echo "missing: $1"
    ok=1
  }
}

marker "workflow-worker-thread: \`toolFilter\` is configured but names neither"
marker "toolFilter: z.object({"
marker "this.toolFilter !== void 0 ? { toolFilter: this.toolFilter } : {}"
marker "this.toolFilter = toolFilter;"

if [ "$ok" -eq 0 ]; then
  node --check "$FILE" >/dev/null 2>&1 || {
    echo "installed workflow-worker-thread does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-006 fix PRESENT"; else echo "bug-006 fix MISSING"; fi
exit "$ok"
