#!/bin/bash
# Exit 0 = bug-022 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
PRESETS="$BASE/dsh-agent-presets/lib/index.js"
TYPES="$BASE/dsh-agent-presets/lib/types/session.d.ts"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$2"))"
    ok=1
  }
}

# One write path records the mount provenance on both paths.
marker "function setSessionAgentPreset(session, agentPreset, mountPath, rowMount)" "$PRESETS"
marker 'setSessionAgentPreset(session, preset.id, "direct", "mounted");' "$PRESETS"
marker 'setSessionAgentPreset(agent.session, preset.id, "switch", "mounted");' "$PRESETS"
# The pre-022 bare append is gone.
if grep -q 'agent.session.append("agent-preset/selected", { agentPreset: preset.id });' "$PRESETS" 2>/dev/null; then
  echo "missing: the switch path still writes a bare agent-preset/selected event"
  ok=1
fi
# Seam type parity.
marker "mountPath: 'direct' | 'switch';" "$TYPES"

if [ "$ok" -eq 0 ]; then
  node --check "$PRESETS" >/dev/null 2>&1 || {
    echo "installed dsh-agent-presets/lib/index.js does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-022 fix PRESENT"; else echo "bug-022 fix MISSING"; fi
exit "$ok"
