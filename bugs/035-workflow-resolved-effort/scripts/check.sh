#!/bin/bash
# Exit 0 = bug-035 fix present in the installed bundle, 1 = missing.
# The sources hold literal template-literal text in their needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-workflow/lib/index.js"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
LLM="$BASE/dsh-llm/lib/index.js"
LLMT="$BASE/dsh-llm/lib/types/call-config.d.ts"
PIAI="$BASE/dsh-llm-pi-ai/lib/index.js"
DEEPSEEK="$BASE/dsh-llm-deepseek/lib/index.js"
WFT="$BASE/dsh-workflow/lib/types/types.d.ts"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Run records carry the resolved effort and provenance, never omitted.
marker 'const effortFields = (agent) => {' "$TOOL"
marker 'resolvedEffort: headerEffort ?? agent.resolvedEffort ?? null' "$TOOL"
marker '...effortFields(agent)' "$TOOL"
marker 'async resolveChildEffort(request, run)' "$WT"
marker 'this.childEfforts.set(run.id, await this.resolveChildEffort(request, run));' "$WT"
marker 'effortSource: "default"' "$WT"
marker 'resolvedEffort: null' "$WT"
marker 'resolvedEffort?: string | null;' "$WFT"
marker "effortSource?: 'pinned' | 'inherited' | 'default' | 'unknown';" "$WFT"
# Adapter honesty: an explicit reasoningEffort (or the default marker) always.
marker 'defaulted.reasoningEffort === "default" ? void 0 : defaulted.reasoningEffort' "$LLM"
marker 'else if (defaulted.reasoningEffort !== "default") resolvedConfig = {' "$LLM"
marker 'reasoningEffort: "default"' "$LLM"
marker 'options.reasoningEffort === "default" ? void 0 : options.reasoningEffort' "$PIAI"
marker 'options.reasoningEffort === "default" ? void 0 : options.reasoningEffort' "$DEEPSEEK"
marker 'reasoningEffort?: ReasoningEffortId;' "$LLMT"

if [ "$ok" -eq 0 ]; then
  for f in "$TOOL" "$WT" "$LLM" "$PIAI" "$DEEPSEEK"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-035 fix PRESENT"; else echo "bug-035 fix MISSING"; fi
exit "$ok"
