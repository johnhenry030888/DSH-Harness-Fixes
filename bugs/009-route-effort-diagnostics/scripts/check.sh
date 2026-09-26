#!/bin/bash
# Exit 0 = bug-009 fix present in the installed bundle, 1 = missing.
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
LLM="$BASE/dsh-llm/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Route rejection classification (delegation + discovery). The
# served-but-unconfigured and unknown-id classes render through the shared
# dsh-llm formatter since bug 024; assert the classes wherever they live,
# never one copy of the wording.
marker "function modelResolutionDiagnostic(provider, model, served)" "$LLM"
marker "does not serve a model with id" "$LLM"
marker "is not allowed for this Session" "$TOOL"
marker "it is outside the Session's allowed routes" "$TOOL"
grep -q "async function assertAllowedModelSelection(llm, policy," "$TOOL" 2>/dev/null || {
  echo "missing: async assertAllowedModelSelection(llm, ...)"
  ok=1
}

# Effort rejection ladder.
marker "function describeReasoningEfforts(" "$LLM"
marker "supported: \${describeReasoningEfforts(reasoning)}" "$LLM"

if [ "$ok" -eq 0 ]; then
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-subagent does not parse under node --check"
    ok=1
  }
  node --check "$LLM" >/dev/null 2>&1 || {
    echo "installed dsh-llm does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-009 fix PRESENT"; else echo "bug-009 fix MISSING"; fi
exit "$ok"
