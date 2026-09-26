#!/bin/bash
# Re-apply the bug-022 patches to the installed bundle. Idempotent: no-ops when present.
# dsh-agent-presets carries no earlier local patches; both patches apply to
# pristine 0.1.5-rc.2 sources directly.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
PRESETS="$BASE/dsh-agent-presets/lib/index.js"
TYPES="$BASE/dsh-agent-presets/lib/types/session.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

if ! grep -q "function setSessionAgentPreset(" "$PRESETS" 2>/dev/null; then
  patch -N -s "$PRESETS" "$BUG/patches/agent-presets-mount-path.patch" || {
    echo "dsh-agent-presets mount-path patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -q "mountPath: 'direct' | 'switch';" "$TYPES" 2>/dev/null; then
  patch -N -s "$TYPES" "$BUG/patches/agent-presets-session-types.patch" || {
    echo "agent-preset/selected type patch FAILED (code moved?)"
    exit 1
  }
fi

node --check "$PRESETS" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
