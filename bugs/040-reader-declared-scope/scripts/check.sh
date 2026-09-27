#!/bin/bash
# Exit 0 = bug-040 fix present in the installed bundle, 1 = missing.
# The guard holds literal template-literal text in its needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
HERE="$(cd "$(dirname "$0")" && pwd)"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Reader-side cue precedence: an explicit declaration outranks the
# incidental/sentinel filter (drill v27 §6 F2).
marker 'const READ_SCOPE_CUE =' "$SUB"
marker 'function declaredReadScopePaths(text)' "$SUB"
marker 'function declaredPromptScope(prompt)' "$SUB"
marker 'return declaredPromptScope(prompt).trees;' "$SUB"
marker 'const scope = declaredPromptScope(prompt);' "$SUB"
# A filtered declaration is named: durable dropped list + refusal wording.
marker '...scope.dropped.length === 0 ? {} : { droppedIncidental: scope.dropped },' "$SUB"
marker 'ignored as incidental/scratch:' "$SUB"
marker 'const droppedNote =' "$SUB"
# 031's fail-closed semantics and 032's pair-naming refusal stay intact.
marker 'const scopeBasis = declared ? "declared" : "maximal";' "$SUB"
marker 'the writer'"'"'s declared work covers ${writerTree} (scopeBasis: ${first.scopeBasis}, writerBasis: ${first.writerBasis})' "$SUB"

if [ "$ok" -eq 0 ]; then
  node --check "$SUB" >/dev/null 2>&1 || {
    echo "installed dsh-subagent does not parse under node --check"
    ok=1
  }
fi

# Behavioural probe: the five acceptance cases (a-e) plus the v27 F2 prompt
# and the cue forms; offline, no model, no host.
if [ "$ok" -eq 0 ]; then
  if ! node "$HERE/guard-reader-scope-check.mjs" "$SUB" >/dev/null 2>&1; then
    echo "guard-reader-scope-check.mjs FAILED against the installed bundle"
    node "$HERE/guard-reader-scope-check.mjs" "$SUB" 2>&1 | grep '^FAIL' || true
    ok=1
  fi
fi

if [ "$ok" -eq 0 ]; then echo "bug-040 fix PRESENT"; else echo "bug-040 fix MISSING"; fi
exit "$ok"
