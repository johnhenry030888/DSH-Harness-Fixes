#!/bin/bash
# "Re-apply" bug 039: there is no harness patch (repo-side deliverable, bug-020
# precedent). This restores the executable bits and re-runs the check;
# idempotent by construction.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/dsh-records.mjs"
SELFTEST="$HERE/records-selftest.sh"

chmod +x "$SCRIPT" "$SELFTEST" 2>/dev/null || true
if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

"$HERE/check.sh"
echo "bug-039 reader present, but check.sh failed -- re-read the reader against the store or README"
exit 1
