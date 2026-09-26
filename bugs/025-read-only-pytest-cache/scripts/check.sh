#!/bin/bash
# Exit 0 = bug-025 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
TOOL="$BASE/dsh-tool-bash/lib/index.js"
ok=0

marker() {
  grep -F -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")")/$(basename "$2"))"
    ok=1
  }
}

# Read-only bash calls export the cache-suppressing PYTEST_ADDOPTS value.
marker "function readOnlyPytestAddopts(ambient)" "$TOOL"
marker 'const flag = "-p no:cacheprovider";' "$TOOL"
# The template literal below is matched verbatim, not expanded.
# shellcheck disable=SC2016
marker 'return ambient.includes(flag) ? ambient : `${ambient} ${flag}`;' "$TOOL"
marker '...policy?.mode === "read-only" ? { env: { PYTEST_ADDOPTS: readOnlyPytestAddopts(process.env.PYTEST_ADDOPTS) } } : {},' "$TOOL"
# The tool description documents the resulting command.
marker "this tool sets \`PYTEST_ADDOPTS\` to include \`-p no:cacheprovider\`" "$TOOL"
marker "bashDescription(backgroundEnabled, escalationModes, defaultMode !== void 0)" "$TOOL"

if [ "$ok" -eq 0 ]; then
  node --check "$TOOL" >/dev/null 2>&1 || {
    echo "installed dsh-tool-bash does not parse under node --check"
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-025 fix PRESENT"; else echo "bug-025 fix MISSING"; fi
exit "$ok"
