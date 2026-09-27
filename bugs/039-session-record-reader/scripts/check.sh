#!/bin/bash
# Exit 0 = the bug-039 deliverable is present, parses and behaves.
# There is no harness patch (bug-020 precedent: the fix is a repo-side reader
# for the installed store). The check asserts the executable script, its
# syntax, the documented store in README.md, and the two-frame self-test.
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/dsh-records.mjs"
SELFTEST="$HERE/records-selftest.sh"
README="$HERE/../README.md"
ok=0

[ -x "$SCRIPT" ] || {
  echo "missing: executable $SCRIPT"
  ok=1
}
if [ -x "$SCRIPT" ]; then
  node --check "$SCRIPT" >/dev/null 2>&1 || {
    echo "dsh-records.mjs does not parse under node --check"
    ok=1
  }
fi
[ -x "$SELFTEST" ] || {
  echo "missing: executable $SELFTEST"
  ok=1
}

# The README must document the store path, the multi-frame caveat and the
# record schema (a reader nobody can find is the bug being fixed).
for marker in 'session.v3.jsonl.zstd' 'zstd -dc' 'subagent/steer-boundary'; do
  grep -qF "$marker" "$README" 2>/dev/null || {
    echo "missing: $marker in README.md"
    ok=1
  }
done

if [ "$ok" -eq 0 ]; then
  "$SELFTEST" >/dev/null 2>&1 || {
    echo "records-selftest.sh FAILED"
    "$SELFTEST" 2>&1 | grep '^FAIL' || true
    ok=1
  }
fi

if [ "$ok" -eq 0 ]; then echo "bug-039 deliverable PRESENT"; else echo "bug-039 deliverable MISSING"; fi
exit "$ok"
