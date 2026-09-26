#!/bin/bash
# Exit 0 = bug-021 fix present in the installed bundle, 1 = missing.
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
SANDBOX="$BASE/dsh-sandbox/lib/index.js"
LOCAL="$BASE/dsh-sandbox-local/lib/index.js"
ok=0

marker() {
  grep -q "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

# The seam owns the temp-root derivation every confined mode may write.
marker "function tempWriteRoots()" "$SANDBOX"
marker "...tempWriteRoots()" "$SANDBOX"
marker "tempWriteRoots, validateEscalationArgs" "$SANDBOX"
# bwrap mounts the private tmpfs in every confined mode.
marker 'const CONFINED_TEMP_DIR = "/tmp"' "$LOCAL"
marker 'CONFINED_TEMP_DIR,' "$LOCAL"
if grep -q 'args.push("--tmpfs", "/tmp");' "$LOCAL" 2>/dev/null; then
  echo "missing: bwrap still mounts the tmpfs only for workspace-write"
  ok=1
fi
# Landlock and Seatbelt grant the temp roots under read-only too.
marker '"/dev/null", ...tempWriteRoots()' "$LOCAL"
marker 'policy.mode === "read-only" ? tempWriteRoots() : writableRoots(policy)' "$LOCAL"

if [ "$ok" -eq 0 ]; then
  for f in "$SANDBOX" "$LOCAL"; do
    node --check "$f" >/dev/null 2>&1 || {
      echo "installed $(basename "$(dirname "$f")") does not parse under node --check"
      ok=1
    }
  done
fi

if [ "$ok" -eq 0 ]; then echo "bug-021 fix PRESENT"; else echo "bug-021 fix MISSING"; fi
exit "$ok"
