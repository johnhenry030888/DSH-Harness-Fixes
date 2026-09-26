#!/bin/bash
# "Re-apply" bug 020: there is no harness patch. This restores the executable
# bit and re-runs the check; idempotent by construction.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HELPER="$HERE/dsh-local-session.mjs"

chmod +x "$HELPER" 2>/dev/null || true
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

"$HERE/check.sh"
echo "bug-020 helper present, but a host contract moved in the installed bundle -- re-read the helper against the new @deepseek-ai/dsh-web-app / dsh-client-connection / dsh-api-session-controller sources"
exit 1
