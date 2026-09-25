#!/bin/bash
# Re-apply the bug-009 patches to the installed bundle. Idempotent: no-ops when present.
# The dsh-tool-subagent route patch stacks on bug 008 (and thus bug 007), so those
# are re-applied first when their markers are missing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
LLM="$BASE/dsh-llm/lib/index.js"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

if ! grep -q "seeded with the parent's completed turns up to the last" "$TOOL" 2>/dev/null; then
  "$HERE/../008-fork-empty-seed-diagnostic/scripts/reapply.sh" || {
    echo "bug 008 must be applied before bug 009's route patch"
    exit 1
  }
fi

echo "fix missing -- applying patches..."
grep -q "does not serve a model with id" "$TOOL" 2>/dev/null || patch -N -s "$TOOL" "$BUG/patches/dsh-tool-subagent-route-diagnostics.patch" || {
  echo "dsh-tool-subagent route patch FAILED (code moved?)"
  exit 1
}
grep -q "function describeReasoningEfforts(" "$LLM" 2>/dev/null || patch -N -s "$LLM" "$BUG/patches/dsh-llm-effort-ladder.patch" || {
  echo "dsh-llm effort ladder patch FAILED (code moved?)"
  exit 1
}
node --check "$TOOL" || exit 1
node --check "$LLM" || exit 1
"$HERE/check.sh"
echo "re-applied OK -- restart the DSH host to load it"
