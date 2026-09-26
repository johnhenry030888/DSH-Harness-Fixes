#!/bin/bash
# Exit 0 = bug-028 fix present in the installed bundle, 1 = missing.
#
# The marker needles are literal `grep -F` patterns copied from the installed
# bundle's source text, where template literals escape their own backticks. The
# backslashes and `${…}` placeholders are part of the needle, so no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"
SUB="$BASE/dsh-subagent/lib/index.js"
SUBT="$BASE/dsh-subagent/lib/types/types.d.ts"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
WORKER="$BASE/dsh-workflow-worker-thread/lib/worker.cjs"
TOOL="$BASE/dsh-tool-workflow/lib/index.js"
TYP="$BASE/dsh-workflow/lib/types/types.d.ts"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The structured code is preserved at the source and forwarded as data.
marker "function turnFailureCode(reason)" "$DRIVER"
marker "const errorCode = toError(error).code;" "$SUB"
marker "readonly errorCode?: string;" "$SUBT"
marker "result.errorCode !== void 0 ? { errorCode: result.errorCode }" "$WT"
# The script receives a typed, branchable failure with the child's own code.
marker "const errorCode = typeof result.errorCode === \"string\" && result.errorCode.length > 0 ? result.errorCode : \"AGENT_RESULT\";" "$WORKER"
marker 'WorkflowError(`child agent failed: ${detail}`, errorCode, { fatal: false })' "$WORKER"
# The model-facing contract and the run record carry the code.
marker 'A failed child REJECTS the awaited call with a \`WorkflowError\`' "$TOOL"
marker "agent.errorCode === void 0 ? {} : { errorCode: agent.errorCode }" "$TOOL"
marker "errorCode?: string;" "$TYP"

if [ "$ok" -eq 0 ]; then
  for f in "$DRIVER" "$SUB" "$WT" "$WORKER" "$TOOL"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-028 fix PRESENT"; else echo "bug-028 fix MISSING"; fi
exit "$ok"
