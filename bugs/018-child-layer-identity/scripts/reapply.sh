#!/bin/bash
# Re-apply the bug-018 patches to the installed bundle. Idempotent: no-ops when present.
# The dsh-subagent patch stacks on bug 013; the system-prompt patch stacks on bug 010.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
SP="$BASE/dsh-system-prompt/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "subagent:layer" "$SUB" 2>/dev/null; then
  if ! grep -q "This layer inherited" "$SUB" 2>/dev/null; then
    "$HERE/../013-fork-seed-announcement/scripts/reapply.sh" || {
      echo "bug 013 must be applied before bug 018's dsh-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/dsh-subagent-layer-banner-and-descriptor-filter.patch" || {
    echo "dsh-subagent layer-banner patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "SUBAGENT_LAYER: 118" "$SP" 2>/dev/null; then
  if ! grep -q "AGENT_ROUTE: 105" "$SP" 2>/dev/null; then
    "$HERE/../010-control-surface-ergonomics/scripts/reapply.sh" || {
      echo "bug 010 must be applied before bug 018's system-prompt patch"
      exit 1
    }
  fi
  patch -N -s "$SP" "$BUG/patches/dsh-system-prompt-layer-order.patch" || {
    echo "dsh-system-prompt layer-order patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$SUB" "$SP"; do node --check "$f" || exit 1; done
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
