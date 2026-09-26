#!/bin/bash
# Exit 0 = bug-014 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
WORKER="$BASE/dsh-workflow-worker-thread/lib/worker.cjs"
REC="$BASE/dsh-tool-workflow/lib/index.js"
TYPES="$BASE/dsh-workflow/lib/types/types.d.ts"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The in-process backend now publishes its turn failure as the seam diagnostic.
marker "function turnDiagnostic(" "$DRIVER"
marker "...diagnostic === void 0 ? {} : { diagnostic }," "$DRIVER"
# The host forwards the diagnostic across the worker boundary.
marker "...result.diagnostic !== void 0 ? { diagnostic: result.diagnostic } : {}," "$WT"
# The worker attaches the failure text and the requested route to both events.
marker "requestedProvider: opts.provider" "$WORKER"
marker "requestedModel: opts.model" "$WORKER"
marker "error: result.diagnostic ??" "$WORKER"
# The run record carries them.
marker "agent.error === void 0 ? {} : { error: agent.error }" "$REC"
marker "agent.requestedProvider === void 0 ? {} : { requestedProvider: agent.requestedProvider }" "$REC"
# Seam type parity.
marker "requestedProvider?: string;" "$TYPES"
marker "on host-synthesized cancellations" "$TYPES"

if [ "$ok" -eq 0 ]; then
  for f in "$DRIVER" "$WT" "$WORKER" "$REC"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-014 fix PRESENT"; else echo "bug-014 fix MISSING"; fi
exit "$ok"
