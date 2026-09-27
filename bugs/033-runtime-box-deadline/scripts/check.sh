#!/bin/bash
# Exit 0 = bug-033 fix present in the installed bundle, 1 = missing.
# The sources hold literal template-literal text in their needles; no shell
# expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SUB="$BASE/dsh-subagent/lib/index.js"
SUB_TYPES="$BASE/dsh-subagent/lib/types/types.d.ts"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The service owns a validated box and arms it on both creation paths.
marker 'function assertBoxSeconds(boxSeconds)' "$SUB"
marker 'function armOneShotBox(run, boxSeconds, logger)' "$SUB"
marker 'armOneShotBox(await provider.start(resolved), request.boxSeconds, this.ctx.logger)' "$SUB"
marker 'armBox(parent, childId, boxSeconds)' "$SUB"
marker 'if (request.boxSeconds !== void 0) this.armBox(parent, childId, request.boxSeconds);' "$SUB"
marker 'activation.handle.agent.session.append("subagent/box", record);' "$SUB"
marker 'hit its ${box.boxSeconds} s box and was interrupted after ${box.elapsedSeconds} s' "$SUB"
marker 'const box = own.findLast((event) => event.type === "subagent/box")?.data;' "$SUB"
marker 'readonly boxSeconds?: number;' "$SUB_TYPES"
# The tool surface accepts a row default and a per-call override.
marker 'boxSeconds: z.natural().min(5)' "$TOOL"
marker 'box_seconds: {' "$TOOL"
marker 'const boxSeconds = args.box_seconds ?? config.boxSeconds;' "$TOOL"
marker 'boxSeconds' "$TOOL"
# The foreground result reports the box hit with the partial output.
marker 'function boxStopError(run, result)' "$TOOL"
marker 'hit its ${String(box.boxSeconds)} s box and was interrupted after ${String(box.elapsedSeconds)} s; partial output follows:' "$TOOL"

if [ "$ok" -eq 0 ]; then
  for f in "$SUB" "$TOOL"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-033 fix PRESENT"; else echo "bug-033 fix MISSING"; fi
exit "$ok"
