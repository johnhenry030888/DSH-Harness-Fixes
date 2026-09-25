#!/bin/bash
# Re-apply the bug-008 patches to the installed bundle. Idempotent: no-ops when present.
# The dsh-tool-subagent wording patch stacks on bug 007's patch of the same file,
# so bug 007 is re-applied first when its marker is missing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
FORK="$BASE/dsh-subagent-fork-in-process/lib/index.js"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

if ! grep -q "function assertKnownToolFilterNames(" "$TOOL" 2>/dev/null; then
  "$HERE/../007-toolfilter-unknown-name-outage/scripts/reapply.sh" || {
    echo "bug 007 must be applied before bug 008's wording patch"
    exit 1
  }
fi

echo "fix missing -- applying patches..."
grep -q "reportSeed(parent, inheritedEventCount)" "$FORK" 2>/dev/null || patch -N -s "$FORK" "$BUG/patches/dsh-subagent-fork-in-process-seed-diagnostic.patch" || {
  echo "dsh-subagent-fork-in-process patch FAILED (code moved?)"
  exit 1
}
grep -q "seeded with the parent's completed turns up to the last" "$TOOL" 2>/dev/null || patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-fork-wording.patch" || {
  echo "dsh-tool-subagent wording patch FAILED (code moved?)"
  exit 1
}
node --check "$FORK" || exit 1
node --check "$TOOL" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
