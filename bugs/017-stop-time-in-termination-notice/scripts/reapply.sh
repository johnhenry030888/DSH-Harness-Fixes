#!/bin/bash
# Re-apply the bug-017 patches to the installed bundle. Idempotent: no-ops when present.
# The runtime patch stacks on bug 019 (which itself chains 018 -> 013 -> 007) on
# dsh-subagent/lib/index.js; the three type patches apply to pristine .d.ts files.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
TYPES="$BASE/dsh-subagent/lib/types/types.d.ts"
LIFECYCLE="$BASE/dsh-subagent/lib/types/lifecycle.d.ts"
SOURCE="$BASE/dsh-subagent/lib/types/continuation-messages.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "const lastActivityTime = own.at(-1)?.time;" "$SUB" 2>/dev/null; then
  if ! grep -q "readOnly: descriptor.readOnly" "$SUB" 2>/dev/null; then
    "$HERE/../019-child-write-scope/scripts/reapply.sh" || {
      echo "bug 019 must be applied before bug 017's dsh-subagent patch"
      exit 1
    }
  fi
  patch -N -s "$SUB" "$BUG/patches/subagent-stop-time.patch" || {
    echo "dsh-subagent stop-time patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "readonly stopTime?: number;" "$TYPES" 2>/dev/null; then
  patch -N -s "$TYPES" "$BUG/patches/subagent-run-end-info-types.patch" || {
    echo "SubagentRunEndInfo type patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "readonly stopTime?: number;" "$LIFECYCLE" 2>/dev/null; then
  patch -N -s "$LIFECYCLE" "$BUG/patches/subagent-activation-terminal-types.patch" || {
    echo "ActivationTerminal type patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "readonly stopTime?: number;" "$SOURCE" 2>/dev/null; then
  patch -N -s "$SOURCE" "$BUG/patches/subagent-settled-source-types.patch" || {
    echo "SubagentSettledMessageSource type patch FAILED (code moved?)"
    exit 1
  }
fi

node --check "$SUB" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
