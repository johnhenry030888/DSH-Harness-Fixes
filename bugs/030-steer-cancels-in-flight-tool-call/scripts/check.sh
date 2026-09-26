#!/bin/bash
# Exit 0 = bug-030 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
LOOP="$BASE/dsh-agent-loop/lib/index.js"
CTRL="$BASE/dsh-tool-subagent-control/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The loop cancels an in-flight tool call on steer and replays the message.
marker "inFlightToolCalls = 0;" "$LOOP"
marker "cancelInFlightToolCall()" "$LOOP"
marker "this.phase.abort.abort({ kind: \"steered\" });" "$LOOP"
marker "this.inFlightToolCalls += 1;" "$LOOP"
# The model-facing contract and the child banner state the behaviour.
marker "cancel-then-replan; a tool that ignores its cancellation signal may still run to completion" "$CTRL"
marker "A send_message steer from the parent cancels this layer's in-flight tool call" "$SUB"
marker "interruptToolCall?: boolean" "$BASE/dsh-agent/lib/types/runtime-types.d.ts"

if [ "$ok" -eq 0 ]; then
  for f in "$LOOP" "$CTRL" "$SUB"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-030 fix PRESENT"; else echo "bug-030 fix MISSING"; fi
exit "$ok"
