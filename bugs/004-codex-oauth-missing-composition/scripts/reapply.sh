#!/bin/bash
# Re-apply bug-004 to the installed bundle. Idempotent: no-ops when present.
#
# 0.1.5-rc.2 replaced the old dsh-host-apiproxy RPC with generated Typert Remote
# namespaces, so the caller surface is now:
#   - dsh-base composition mounts @deepseek-ai/dsh-authorization
#   - dsh-api-settings-controller owns the host `authorization` namespace
#     (a TypertRemoteService whose methods the gateway dispatches via SRC
#     markers, so no generated manifest edit is required)
#   - dsh-api-remotes carries the strict client descriptors
#   - dsh-client-ui-settings-models renders the Models sign-in panel
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi
echo "fix missing -- applying patches..."
apply_if_missing() {
  local target="$1" patch_file="$2" marker="$3"
  if grep -qF "$marker" "$target" 2>/dev/null; then return 0; fi
  patch -N -s "$target" "$patch_file" || {
    echo "patch FAILED for $target"
    exit 1
  }
}
apply_if_missing "$BASE/dsh-base/cordis.patch.yml" \
  "$BUG/patches/dsh-base-codex-oauth-composition.patch" \
  "@deepseek-ai/dsh-authorization"
apply_if_missing "$BASE/dsh-api-settings-controller/lib/index.js" \
  "$BUG/patches/dsh-api-settings-controller-authorization.patch" \
  "authorizationController"
apply_if_missing "$BASE/dsh-api-remotes/lib/client.js" \
  "$BUG/patches/dsh-api-remotes-authorization.patch" \
  "authorization/begin"
apply_if_missing "$BASE/dsh-client-ui-settings-models/lib/client.js" \
  "$BUG/patches/dsh-client-ui-settings-models-authorization.patch" \
  "AuthorizationPanel"
"$HERE/check.sh"
for file in \
  "$BASE/dsh-api-settings-controller/lib/index.js" \
  "$BASE/dsh-api-remotes/lib/client.js" \
  "$BASE/dsh-client-ui-settings-models/lib/client.js"; do
  node --check "$file" || exit 1
done
echo "re-applied OK -- restart DSH to load the authorization service"
