#!/bin/bash
# Re-apply the bug-010 patches to the installed bundle. Idempotent: no-ops when present.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
JOBS="$BASE/dsh-jobs-local/lib/index.js"
AGENTS="$BASE/dsh-tool-subagent-control/lib/types/list-agents.js"
LOOP="$BASE/dsh-agent-loop/lib/index.js"
PROMPT="$BASE/dsh-system-prompt/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

apply() {
  local file="$1" marker="$2" patchfile="$3"
  grep -q "$marker" "$file" 2>/dev/null && return 0
  patch -N -s "$file" "$patchfile" || {
    echo "$(basename "$file") patch FAILED (code moved?)"
    exit 1
  }
}

apply "$JOBS" "AGENT_ID_LIKE" "$BUG/patches/dsh-jobs-local-agent-id-hint.patch"
apply "$AGENTS" "checkedAt" "$BUG/patches/dsh-tool-subagent-control-status-timestamp.patch"
apply "$LOOP" "function renderAgentRoute(" "$BUG/patches/dsh-agent-loop-route-context.patch"
apply "$PROMPT" "AGENT_ROUTE: 105" "$BUG/patches/dsh-system-prompt-route-order.patch"

node --check "$JOBS" || exit 1
node --check "$AGENTS" || exit 1
node --check "$LOOP" || exit 1
node --check "$PROMPT" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
