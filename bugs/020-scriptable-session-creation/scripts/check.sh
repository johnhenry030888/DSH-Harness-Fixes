#!/bin/bash
# Exit 0 = the bug-020 deliverable is present and its host surfaces exist.
# There is no harness patch: the fix is a documented client of the installed
# local API. This check verifies the helper plus the three host contracts it
# depends on, so a dsh update that moves them fails loudly here.
#
# The marker needles are literal `grep -F` patterns copied from the installed
# bundle's source text, where `${…}` placeholders are part of the needle; no
# shell expansion is intended.
# shellcheck disable=SC2016
BASE="${DSH_AGENT_BASE:-/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai}"
WEB="$BASE/dsh-web-app/lib/index.js"
CONN="$BASE/dsh-client-connection/lib/index.js"
SESS="$BASE/dsh-api-session-controller/lib/typert.host.js"
HERE="$(cd "$(dirname "$0")" && pwd)"
HELPER="$HERE/dsh-local-session.mjs"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$(dirname "$2")"))"
    ok=1
  }
}

[ -x "$HELPER" ] || {
  echo "missing: executable $HELPER"
  ok=1
}
if [ -x "$HELPER" ]; then
  node --check "$HELPER" >/dev/null 2>&1 || {
    echo "helper does not parse under node --check"
    ok=1
  }
fi

# Host contracts the helper drives.
marker 'dsh web: ${authenticatedUrl}' "$WEB"
marker 'authorizeIndex(request, response)' "$CONN"
marker '@deepseek-ai/dsh-api-session-controller#session/create' "$SESS"

if [ "$ok" -eq 0 ]; then echo "bug-020 deliverable PRESENT"; else echo "bug-020 deliverable MISSING"; fi
exit "$ok"
