#!/bin/bash
# Exit 0 = bug-031 fix present in the installed bundle, 1 = missing.
# The guard holds literal template-literal text in its needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
SESSION="$BASE/dsh-session/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Undeclared read scope is maximal, not a cwd fallback.
marker 'const declared = readTrees !== void 0 && readTrees.length > 0;' "$SUB"
marker 'const readerTrees = declared ? readTrees : parent.session.header.cwd === void 0 ? [] : [resolve(parent.session.header.cwd)];' "$SUB"
marker 'refused a read-only delegation that declared no read scope: it is treated as covering the whole workspace' "$SUB"
marker 'const scopeBasis = declared ? "declared" : "maximal";' "$SUB"
marker 'parent.session.append("subagent/inspection-scope", {' "$SUB"
# The durable event types the guard and its dependents append.
marker '"subagent/inspection-scope",' "$SESSION"
marker '"subagent/box",' "$SESSION"
marker '"subagent/steer",' "$SESSION"
marker '"subagent/steer-boundary",' "$SESSION"

if [ "$ok" -eq 0 ]; then
  for f in "$SUB" "$SESSION"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-031 fix PRESENT"; else echo "bug-031 fix MISSING"; fi
exit "$ok"
