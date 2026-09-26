#!/bin/bash
# Re-apply the bug-025 patch to the installed bundle. Idempotent: no-ops when present.
# The dsh-tool-bash patch applies to pristine 0.1.5-rc.2 sources directly.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-bash/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patch..."

patch -N -s "$TOOL" "$BUG/patches/dsh-tool-bash-read-only-pytest-addopts.patch" || {
  echo "dsh-tool-bash read-only pytest-addopts patch FAILED (code moved?)"
  exit 1
}

node --check "$TOOL" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
