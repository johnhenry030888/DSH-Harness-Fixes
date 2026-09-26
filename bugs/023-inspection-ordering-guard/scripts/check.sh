#!/bin/bash
# Exit 0 = bug-023 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
LIST="$BASE/dsh-tool-subagent-control/lib/types/list-agents.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The ordering guard owns one tree-overlap test, one conflict scan, and one
# refusal, and both child-creation paths consult it.
marker "function treesOverlap(left, right)" "$SUB"
marker "function inspectionConflicts(ctx, parent, readOnlyRequested" "$SUB"
marker "function assertInspectionOrdering(ctx, parent, readOnlyRequested" "$SUB"
marker '"INSPECTION_CONFLICT"' "$SUB"
marker "assertInspectionOrdering(this.ctx, spec.request.parent, spec.request.readOnly" "$SUB"
marker "assertInspectionOrdering(this.ctx, request.parent, request.readOnly" "$SUB"
# Write-capability is read from the resolved sandbox policy, not guessed.
marker 'sandboxPolicy?.overrideOf(candidate.session) === "read-only"' "$SUB"

# list_agents samples the per-child inspection state (file policy + tree).
marker "filePolicy: sandboxPolicy.overrideOf(live.session) === 'read-only' ? 'read-only' : 'writes'" "$LIST"
marker "entry.filePolicy" "$LIST"
marker "const sandboxPolicy = ctx.get('sandboxPolicy');" "$LIST"

if [ "$ok" -eq 0 ]; then
  for f in "$SUB" "$LIST"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-023 fix PRESENT"; else echo "bug-023 fix MISSING"; fi
exit "$ok"
