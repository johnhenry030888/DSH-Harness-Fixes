#!/bin/bash
# Re-apply the bug-037 patches to the installed bundle. Idempotent: no-ops when
# present. The patches stack on 006 (worker-thread toolFilter), 028
# (worker/tool-workflow failure codes) and 035 (the worker host's
# `resolveChildEffort` + the `effortFields` record half), so the reapply chain
# runs those first — each is a no-op when already present.
#
# The `grep -F` needles below are literal patterns copied from the bundle's
# source text; no shell expansion is intended.
# shellcheck disable=SC2016
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BUG="$HERE/.."
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
WORKER="$BASE/dsh-workflow-worker-thread/lib/worker.cjs"
WT="$BASE/dsh-workflow-worker-thread/lib/index.js"
TOOL="$BASE/dsh-tool-workflow/lib/index.js"
WFT="$BASE/dsh-workflow/lib/types/types.d.ts"
TOOLT="$BASE/dsh-tool-workflow/lib/types/types.d.ts"
WTT="$BASE/dsh-workflow-worker-thread/lib/types/types.d.ts"

if "$HERE/check.sh" >/dev/null 2>&1; then
  echo "already present -- nothing to do"
  exit 0
fi

echo "fix missing -- applying patches..."

"$HERE/../../006-workflow-worker-tool-filter/scripts/reapply.sh" || {
  echo "bug 006 must be applied before bug 037's worker-thread patch"
  exit 1
}
"$HERE/../../028-workflow-agent-failure-code/scripts/reapply.sh" || {
  echo "bug 028 must be applied before bug 037's worker/tool-workflow patches"
  exit 1
}
"$HERE/../../035-workflow-resolved-effort/scripts/reapply.sh" || {
  echo "bug 035 must be applied before bug 037 (resolveChildEffort + effortFields)"
  exit 1
}

if ! grep -qF '...opts.effort !== void 0 ? { agentOptions: { reasoningEffort: opts.effort } } : {}' "$WORKER" 2>/dev/null; then
  patch -N -s "$WORKER" "$BUG/patches/dsh-workflow-worker-thread-effort-option.patch" || {
    echo "worker.cjs effort-option patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -qF 'request.agentOptions?.reasoningEffort !== void 0 ? { agentOptions: {' "$WT" 2>/dev/null; then
  patch -N -s "$WT" "$BUG/patches/dsh-workflow-worker-thread-effort-forward.patch" || {
    echo "workflow-worker-thread effort-forward patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -qF '...agent.requestedEffort === void 0 ? {} : { requestedEffort: agent.requestedEffort },' "$TOOL" 2>/dev/null; then
  patch -N -s "$TOOL" "$BUG/patches/dsh-tool-workflow-requested-effort.patch" || {
    echo "dsh-tool-workflow requested-effort patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -qF 'requestedEffort?: string;' "$WFT" 2>/dev/null; then
  patch -N -s "$WFT" "$BUG/patches/dsh-workflow-requested-effort-type.patch" || {
    echo "dsh-workflow requested-effort type patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -qF 'readonly requestedEffort?: string;' "$TOOLT" 2>/dev/null; then
  patch -N -s "$TOOLT" "$BUG/patches/dsh-tool-workflow-requested-effort-types.patch" || {
    echo "dsh-tool-workflow requested-effort types patch FAILED (code moved?)"
    exit 1
  }
fi

if ! grep -qF 'agentOptions?: { reasoningEffort?: string };' "$WTT" 2>/dev/null; then
  patch -N -s "$WTT" "$BUG/patches/dsh-workflow-worker-thread-child-request-type.patch" || {
    echo "dsh-workflow-worker-thread child-request type patch FAILED (code moved?)"
    exit 1
  }
fi

for f in "$WORKER" "$WT" "$TOOL"; do node --check "$f" || exit 1; done
"$HERE/check.sh" || exit 1
echo "re-applied OK -- restart the DSH host to load it"
