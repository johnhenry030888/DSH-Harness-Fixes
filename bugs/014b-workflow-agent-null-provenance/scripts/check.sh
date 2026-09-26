#!/bin/bash
# Exit 0 = bug-014b fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
REC="$BASE/dsh-tool-workflow/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The tool description documents the run-record lookup beside the null contract.
marker "read the run record, never the return value" "$REC"
marker "a rejected route and a child that produced nothing are both" "$REC"
marker "when the child failed before producing output" "$REC"

if [ "$ok" -eq 0 ]; then
  node --check "$REC" >/dev/null 2>&1 || {
    echo "installed dsh-tool-workflow/lib/index.js does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-014b fix PRESENT"; else echo "bug-014b fix MISSING"; fi
exit "$ok"
