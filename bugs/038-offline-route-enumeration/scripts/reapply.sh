#!/bin/bash
# "Re-apply" bug 038: there is no harness patch (like bug 020). This restores
# the helper's executable bit via the bug-020 reapply and re-runs the marker
# checks; idempotent by construction.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG020="$HERE/../../020-scriptable-session-creation"

chmod +x "$BUG020/scripts/dsh-local-session.mjs" 2>/dev/null || true
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

"$BUG020/scripts/reapply.sh" || true
if "$HERE/check.sh"; then
  echo "re-applied OK -- the bug-020 helper/README carried the bug-038 additions"
  exit 0
fi

echo "bug-038 markers missing -- re-read the bug-020 helper/README against the installed bundle sources"
exit 1
