#!/bin/bash
# Exit 0 = bug-037 fix present in the installed bundle, 1 = missing.
# The sources hold literal template-literal text in their needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
WORKER="$BASE/dsh-workflow-worker-thread/lib/worker.cjs"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
TOOL="$BASE/dsh-tool-workflow/lib/index.js"
WFT="$BASE/dsh-workflow/lib/types/types.d.ts"
TOOLT="$BASE/dsh-tool-workflow/lib/types/types.d.ts"
WTT="$BASE/dsh-workflow-worker-thread/lib/types/types.d.ts"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# worker.cjs: `effort` is a supported option (no longer deferred), validated as
# a non-empty string, forwarded as a pinned child agentOption and recorded as
# the requested value.
marker '...opts.effort !== void 0 ? { agentOptions: { reasoningEffort: opts.effort } } : {}' "$WORKER"
marker '...opts.effort !== void 0 ? { requestedEffort: opts.effort } : {}' "$WORKER"
marker 'agent() option "effort" must be a non-empty string' "$WORKER"
marker '(supported: label, phase, schema, provider, model, effort)' "$WORKER"
marker '...record.effort !== void 0 ? { effort: record.effort } : {},' "$WORKER"
# The host maps the request's pinned effort into the child's creation options.
marker 'request.agentOptions?.reasoningEffort !== void 0 ? { agentOptions: {' "$WT"
marker '...request.agentOptions?.reasoningEffort !== void 0 ? { reasoningEffort: request.agentOptions.reasoningEffort } : {}' "$WT"
# The run record carries the requested effort beside resolvedEffort/effortSource,
# and the tool description documents the option.
marker '...agent.requestedEffort === void 0 ? {} : { requestedEffort: agent.requestedEffort },' "$TOOL"
marker 'An effort the target model does not advertise fails that stage loudly with the platform' "$TOOL"
marker 'requestedEffort?: string;' "$WFT"
marker 'readonly requestedEffort?: string;' "$TOOLT"
marker 'agentOptions?: { reasoningEffort?: string };' "$WTT"

if [ "$ok" -eq 0 ]; then
  for f in "$WORKER" "$WT" "$TOOL"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-037 fix PRESENT"; else echo "bug-037 fix MISSING"; fi
exit "$ok"
