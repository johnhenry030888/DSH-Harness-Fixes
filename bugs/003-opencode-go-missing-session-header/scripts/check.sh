#!/bin/bash
# Exit 0 = bug-003 fix present in the installed bundle, 1 = missing.
FILE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js"
ok=0
grep -q "opencodeSessionHeaders" "$FILE" 2>/dev/null || {
  echo "missing: opencodeSessionHeaders helper"
  ok=1
}
grep -q "x-opencode-session" "$FILE" 2>/dev/null || {
  echo "missing: x-opencode-session header"
  ok=1
}
if [ "$ok" -eq 0 ]; then echo "bug-003 fix PRESENT"; else echo "bug-003 fix MISSING"; fi
exit "$ok"
