#!/bin/bash
# Exit 0 = bug-002 fix present in the installed bundle, 1 = missing.
FILE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-mcp-client/lib/index.js"
ok=0
grep -q "expandEnvValue" "$FILE" 2>/dev/null || {
  echo "missing: expandEnvValue helper"
  ok=1
}
grep -q "references expanded (see expandEnvValue)" "$FILE" 2>/dev/null || {
  echo "missing: buildChildEnv docstring marker"
  ok=1
}
if [ "$ok" -eq 0 ]; then echo "bug-002 fix PRESENT"; else echo "bug-002 fix MISSING"; fi
exit "$ok"
