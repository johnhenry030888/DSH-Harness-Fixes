#!/bin/bash
# Exit 0 = bug-036 fix present in the installed bundle, 1 = missing.
# The tool source holds template-literal text in its needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
TYPES="$BASE/dsh-subagent/lib/types/index.d.ts"
LIST="$BASE/dsh-tool-subagent-control/lib/types/list-agents.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The service exposes the guard's own declared-work harvester.
marker 'declaredWorkOf(agent) {' "$SUB"
marker 'return declaredWorkOf(agent);' "$SUB"
marker 'declaredWorkOf(agent: Agent): {' "$TYPES"
# list_agents renders the declared tree with its basis instead of the cwd.
marker 'subagents.declaredWorkOf({ session })' "$LIST"
marker 'treeBasis: declared.basis' "$LIST"
marker 'const session = live === undefined ? sessions?.get(entry.id) : live.session;' "$LIST"
marker 'const sessions = ctx.get('"'"'sessions'"'"');' "$LIST"
# The 023 policy sample is preserved for live rows.
marker "filePolicy: sandboxPolicy.overrideOf(live.session) === 'read-only' ? 'read-only' : 'writes'" "$LIST"
marker "entry.filePolicy" "$LIST"

if [ "$ok" -eq 0 ]; then
  for f in "$SUB" "$LIST"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-036 fix PRESENT"; else echo "bug-036 fix MISSING"; fi
exit "$ok"
