#!/bin/bash
# Exit 0 = bug-029 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Child layers get the row persona or a compact worker statement; the parent's
# persona suffix is shadowed empty so the lead's lane map never composes.
marker "const workerPersona = \`You are a delegated worker lane of agent" "$SUB"
marker "text: composition.persona ?? workerPersona" "$SUB"
marker "name: \"deployment:persona-suffix\"" "$SUB"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-029 fix PRESENT"; else echo "bug-029 fix MISSING"; fi
exit "$ok"
