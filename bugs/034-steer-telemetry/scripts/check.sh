#!/bin/bash
# Exit 0 = bug-034 fix present in the installed bundle, 1 = missing.
# The sources hold literal template-literal text in their needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
LOOP="$BASE/dsh-agent-loop/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
SUB_TYPES="$BASE/dsh-subagent/lib/types/types.d.ts"
CTRL="$BASE/dsh-tool-subagent-control/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The child records the delivery and stamps the step boundary it adopted.
marker 'function steerDeliveryRecord(messageId, target, senderSessionId, deliveredAt)' "$SUB"
marker 'activation.handle.agent.session.append("subagent/steer", steerDeliveryRecord(messageId, activation.childId, parent.id, deliveredAt));' "$SUB"
marker 'steer: true,' "$SUB"
marker 'function steerBoundaryRecord(message, boundaryAt, boundarySeq)' "$LOOP"
marker 'this.session.append("subagent/steer-boundary", steerBoundaryRecord(message, new Date().toISOString(), this.session.seq));' "$LOOP"
marker 'readonly deliveredAt?: string;' "$SUB_TYPES"
# The tool returns the same stamp in its result text.
marker 'deliveredAt: {' "$CTRL"
marker 'message delivered to agent ${args.agent_id} — deliveredAt ${value.deliveredAt}' "$CTRL"
marker 'const deliveredAt = new Date().toISOString();' "$CTRL"
marker 'deliveredAt' "$CTRL"

if [ "$ok" -eq 0 ]; then
  for f in "$LOOP" "$SUB" "$CTRL"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-034 fix PRESENT"; else echo "bug-034 fix MISSING"; fi
exit "$ok"
