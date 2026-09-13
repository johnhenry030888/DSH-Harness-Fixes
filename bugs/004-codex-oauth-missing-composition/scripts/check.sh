#!/bin/bash
# Exit 0 = bug-004 fix present in the installed bundle, 1 = missing.
set -u
FILE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-base/cordis.patch.yml"
HOST="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/index.js"
CLIENT="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-connection/lib/client.js"
UI="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js"
SCHEMA="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api/authorization.schema.js"
if grep -q "id: authorization" "$FILE" 2>/dev/null && grep -q "name: '@deepseek-ai/dsh-authorization'" "$FILE" 2>/dev/null && grep -q '"authorization.list"' "$HOST" 2>/dev/null && grep -q '"authorization.answer"' "$HOST" 2>/dev/null && grep -q 'authorization = {' "$CLIENT" 2>/dev/null && grep -q 'Subscription sign-in' "$UI" 2>/dev/null && grep -q 'authorization-panel' "$UI" 2>/dev/null && grep -q 'firstOption' "$UI" 2>/dev/null && grep -q 'authorization-state' "$UI" 2>/dev/null && grep -q 'Step 1:' "$UI" 2>/dev/null && grep -q 'Waiting for sign-in.' "$UI" 2>/dev/null && test -f "$SCHEMA"; then
  echo "bug-004 fix PRESENT"
  exit 0
fi
echo "bug-004 fix MISSING"
exit 1
