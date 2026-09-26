#!/bin/bash
# Exit 0 = bug-026 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The guard reads declared target paths, not the session cwd.
marker "function declaredTreePaths(text)" "$SUB"
marker "function declaredTreesOf(agent)" "$SUB"
marker "function declaredPromptTrees(prompt)" "$SUB"
marker "function inspectionConflicts(ctx, parent, readOnlyRequested, readTrees)" "$SUB"
marker "against the same target path" "$SUB"
# Both creation paths pass the request prompt into the guard.
marker "assertInspectionOrdering(this.ctx, spec.request.parent, spec.request.readOnly, spec.request.prompt)" "$SUB"
marker "assertInspectionOrdering(this.ctx, request.parent, request.readOnly, request.prompt)" "$SUB"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-026 fix PRESENT"; else echo "bug-026 fix MISSING"; fi
exit "$ok"
