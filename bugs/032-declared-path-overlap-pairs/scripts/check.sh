#!/bin/bash
# Exit 0 = bug-032 fix present in the installed bundle, 1 = missing.
# The guard holds literal template-literal text in its needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Incidental/sentinel mentions are not declared work; the most specific path wins.
marker 'const DECLARED_PATH_INCIDENTAL =' "$SUB"
marker 'function mostSpecificPaths(paths)' "$SUB"
marker 'if (DECLARED_PATH_INCIDENTAL.test(context)) continue;' "$SUB"
marker 'return mostSpecificPaths([...found]);' "$SUB"
# One shared harvester reads a session's declared work and its basis.
marker 'function declaredWorkOfSession(session)' "$SUB"
marker 'function declaredWorkOf(agent)' "$SUB"
marker 'const writerWork = declaredWorkOf(candidate);' "$SUB"
# The refusal names the actual overlapping pair and the decision basis.
marker 'the writer'"'"'s declared work covers ${writerTree} (scopeBasis: ${first.scopeBasis}, writerBasis: ${first.writerBasis})' "$SUB"
marker 'writerBasis' "$SUB"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-032 fix PRESENT"; else echo "bug-032 fix MISSING"; fi
exit "$ok"
