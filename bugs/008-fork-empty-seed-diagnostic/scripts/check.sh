#!/bin/bash
# Exit 0 = bug-008 fix present in the installed bundle, 1 = missing.
BASE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
FORK="$BASE/dsh-subagent-fork-in-process/lib/index.js"
TOOL="$BASE/dsh-tool-subagent/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# Fork provider: the seed diagnostic.
marker "reportSeed(parent, inheritedEventCount)" "$FORK"
marker "inherits 0 events" "$FORK"
marker "new ForkInProcessProvider(config.providerName, ctx.logger)" "$FORK"

# Tool wording: the completed-turn contract.
marker "seeded with the parent's completed turns up to the last" "$TOOL"
marker "gives the child NO prior conversation" "$TOOL"

if [ "$ok" -eq 0 ]; then
  node --check "$FORK" >/dev/null 2>&1 || {
    echo "installed dsh-subagent-fork-in-process does not parse under node --check"
    ok=1
  }
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-subagent does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-008 fix PRESENT"; else echo "bug-008 fix MISSING"; fi
exit "$ok"
