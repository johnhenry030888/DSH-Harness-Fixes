#!/bin/bash
# Re-apply bug-004 to the installed bundle. Idempotent: no-ops when present.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
FILE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-base/cordis.patch.yml"
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi
echo "fix missing -- applying patch..."
apply_if_missing() {
  local target="$1" patch_file="$2" marker="$3"
  if grep -q "$marker" "$target" 2>/dev/null; then return 0; fi
  patch -N -s "$target" "$patch_file" || {
    echo "patch FAILED for $target"
    exit 1
  }
}
apply_if_missing "$FILE" "$BUG/patches/dsh-base-codex-oauth-composition.patch" "name: '@deepseek-ai/dsh-authorization'"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/index.js" "$BUG/patches/dsh-host-apiproxy-main.patch" "this.authorization = api.authorization"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/index.js" "$BUG/patches/dsh-host-apiproxy-index-runtime.patch" "this.authorization = api.authorization"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api-proxy.js" "$BUG/patches/dsh-host-apiproxy-types.patch" "authorizationAttempts"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/fetch/handler.js" "$BUG/patches/dsh-host-apiproxy-handler.patch" "authorization.list"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/fetch/client.js" "$BUG/patches/dsh-host-apiproxy-client.patch" "authorization ="
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api/index.d.ts" "$BUG/patches/dsh-host-apiproxy-api-index.patch" "AuthorizationApi"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api/rpc-map.d.ts" "$BUG/patches/dsh-host-apiproxy-rpc-map.patch" "authorization.list"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/fetch/client.d.ts" "$BUG/patches/dsh-host-apiproxy-fetch-dts.patch" "authorization:"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-connection/lib/client.js" "$BUG/patches/dsh-client-connection.patch" "authorization ="
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-connection/lib/types/client/api.d.ts" "$BUG/patches/dsh-client-connection-dts.patch" "AuthorizationApi"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js" "$BUG/patches/dsh-client-ui-settings-models.patch" "Subscription sign-in"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js" "$BUG/patches/dsh-client-ui-settings-models-polish.patch" "authorization-panel"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js" "$BUG/patches/dsh-client-ui-settings-models-accessibility.patch" "authorization-state"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js" "$BUG/patches/dsh-client-ui-settings-models-state.patch" "Step 1:"
apply_if_missing "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js" "$BUG/patches/dsh-client-ui-settings-models-flow-labels.patch" "Waiting for sign-in."
SCHEMA="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api/authorization.schema.js"
HOST_PACKAGE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy"
if test ! -f "$SCHEMA"; then patch -d "$HOST_PACKAGE" -p0 -N -s <"$BUG/patches/dsh-host-apiproxy-authorization-files.patch" || exit 1; fi
"$HERE/check.sh"
for file in \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/index.js" \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api-proxy.js" \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/api/authorization.schema.js" \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/fetch/handler.js" \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/types/fetch/client.js" \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-connection/lib/client.js" \
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-ui-settings-models/lib/client.js"; do
  node --check "$file" || exit 1
done
echo "re-applied OK -- restart DSH to load the authorization service"
