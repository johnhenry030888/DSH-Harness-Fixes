#!/bin/bash
# Re-apply the bug-013 patches to the installed bundle. Idempotent: no-ops when present.
# Stacks on bug 007 (dsh-subagent) and bug 008 (dsh-subagent-fork-in-process), so
# those are re-applied first when their markers are missing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
FORK="$BASE/dsh-subagent-fork-in-process/lib/index.js"
DRIVER="$BASE/dsh-subagent-in-process-driver/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function optionalCount(" "$SUB" 2>/dev/null; then
  if ! grep -q "function restrictChildTools(" "$SUB" 2>/dev/null; then
    "$HERE/../007-toolfilter-unknown-name-outage/scripts/reapply.sh" || {
      echo "bug 007 must be applied before bug 013's dsh-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-seed-count-descriptor.patch" || {
    echo "dsh-subagent seed-count patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "inherits \${inheritedEventCount} completed events" "$FORK" 2>/dev/null; then
  if ! grep -q "reportSeed(parent, inheritedEventCount)" "$FORK" 2>/dev/null; then
    "$HERE/../008-fork-empty-seed-diagnostic/scripts/reapply.sh" || {
      echo "bug 008 must be applied before bug 013's fork patch"
      exit 1
    }
  fi
  patch -N -s "$FORK" "$BUG/patches/dsh-subagent-fork-in-process-seed-announcement.patch" || {
    echo "dsh-subagent-fork-in-process seed-announcement patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "attachDescriptorAppend(childCtx, {" "$DRIVER" 2>/dev/null; then
  patch -N -s "$DRIVER" "$BUG/patches/dsh-subagent-in-process-driver-seed-count.patch" || {
    echo "dsh-subagent-in-process-driver seed-count patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$SUB" "$FORK" "$DRIVER"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
