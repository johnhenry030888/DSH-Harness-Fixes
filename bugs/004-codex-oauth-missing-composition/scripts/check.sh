#!/bin/bash
# Exit 0 = bug-004 fix present in the installed bundle, 1 = missing.
set -u
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
BASE_YML="$BASE/dsh-base/cordis.patch.yml"
SETTINGS="$BASE/dsh-api-settings-controller/lib/index.js"
REMOTES="$BASE/dsh-api-remotes/lib/client.js"
UI="$BASE/dsh-client-ui-settings-models/lib/client.js"
ok=0
grep -qF "id: authorization" "$BASE_YML" 2>/dev/null || {
  echo "missing: dsh-base authorization mount"
  ok=1
}
grep -qF "@deepseek-ai/dsh-authorization" "$BASE_YML" 2>/dev/null || {
  echo "missing: dsh-authorization plugin name"
  ok=1
}
grep -qF "authorizationController" "$SETTINGS" 2>/dev/null || {
  echo "missing: host AuthorizationController"
  ok=1
}
grep -qF 'namespace: "authorization"' "$SETTINGS" 2>/dev/null || {
  echo "missing: host authorization namespace"
  ok=1
}
grep -qF "authorization/begin" "$REMOTES" 2>/dev/null || {
  echo "missing: client authorization descriptors"
  ok=1
}
grep -qF "TYPERT_REMOTE\$15" "$REMOTES" 2>/dev/null || {
  echo "missing: client authorization contribution"
  ok=1
}
grep -qF "AuthorizationPanel" "$UI" 2>/dev/null || {
  echo "missing: subscription sign-in panel"
  ok=1
}
grep -qF "authorizationTitle" "$UI" 2>/dev/null || {
  echo "missing: sign-in copy"
  ok=1
}
grep -qF '"remote.authorization"' "$UI" 2>/dev/null || {
  echo "missing: remote.authorization injection"
  ok=1
}
if [ "$ok" -eq 0 ]; then echo "bug-004 fix PRESENT"; else echo "bug-004 fix MISSING"; fi
exit "$ok"
