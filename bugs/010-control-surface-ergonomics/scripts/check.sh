#!/bin/bash
# Exit 0 = bug-010 fix present in the installed bundle, 1 = missing.
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
JOBS="$BASE/dsh-jobs-local/lib/index.js"
AGENTS="$BASE/dsh-tool-subagent-control/lib/types/list-agents.js"
LOOP="$BASE/dsh-agent-loop/lib/index.js"
PROMPT="$BASE/dsh-system-prompt/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# job_output/job_kill: agent-id hint.
marker "AGENT_ID_LIKE" "$JOBS"
marker "looks like a subagent/agent id, not a job id" "$JOBS"

# list_agents: sampled-at timestamp + honest wording.
marker "checkedAt" "$AGENTS"
grep -q "entry.status} as of \${entry.checkedAt}" "$AGENTS" 2>/dev/null || {
  echo "missing: list_agents render timestamp"
  ok=1
}

# Runtime context: the agent's own resolved route.
marker "function renderAgentRoute(" "$LOOP"
marker "This agent's effective route:" "$LOOP"
marker "AGENT_ROUTE: 105" "$PROMPT"

if [ "$ok" -eq 0 ]; then
  for f in "$JOBS" "$AGENTS" "$LOOP" "$PROMPT"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-010 fix PRESENT"; else echo "bug-010 fix MISSING"; fi
exit "$ok"
