#!/bin/bash
# "Re-apply" bug 041: there is no harness patch (repo tooling, scripts/check-all.sh).
# This re-runs the check so a regenerated or stale tool fails loudly; idempotent.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

"$HERE/check.sh"
echo "bug-041 check-all.sh is missing the authoritative TOTAL line or its temp-copy probe -- restore scripts/check-all.sh from the bug folder's README"
exit 1
