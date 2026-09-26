#!/bin/bash
# Exit 0 = bug-014b fix present in the installed bundle, 1 = missing.
#
# The marker needles are literal `grep -F` patterns copied from the installed
# bundle's source text, where template literals escape their own backticks. The
# backslashes are part of the needle, so no shell expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
REC="$BASE/dsh-tool-workflow/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The tool description documents the run-record lookup beside the failure
# contract. Bug 028 replaced the bare-null wording with a rejection carrying the
# child's code, so these markers assert the class (provenance stays on the run
# record; the agent() bullet names the failure contract) rather than the
# superseded sentence (the bug-009/012 check-class update precedent).
marker 'Every stage also emits \`workflow/agent-start\`/\`agent-end\` records' "$REC"
marker 'carries the \`error\` diagnostic' "$REC"
marker "when the child failed before producing output" "$REC"

if [ "$ok" -eq 0 ]; then
  node --check "$REC" >/dev/null 2>&1 || {
    echo "installed dsh-tool-workflow/lib/index.js does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-014b fix PRESENT"; else echo "bug-014b fix MISSING"; fi
exit "$ok"
