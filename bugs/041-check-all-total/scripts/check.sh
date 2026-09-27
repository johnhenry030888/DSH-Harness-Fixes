#!/bin/bash
# Exit 0 = scripts/check-all.sh prints the one authoritative TOTAL line and
# tallies a deliberately broken check correctly in a temp copy (bug 041). The
# real suite is never mutated: the broken case runs against a copied tree.
# The tally marker contains literal `$present`/`$missing` shell text copied
# from check-all.sh; no expansion is intended.
# shellcheck disable=SC2016
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
CHECK_ALL="$ROOT/scripts/check-all.sh"
ok=0

marker() {
  grep -qF "$1" "$2" 2>/dev/null || {
    echo "missing: $1 (in $(basename "$2"))"
    ok=1
  }
}

[ -x "$CHECK_ALL" ] || {
  echo "missing: executable $CHECK_ALL"
  ok=1
}

# The final line and its counters.
marker 'TOTAL: $present fixes present, $missing missing' "$CHECK_ALL"
marker 'present=$((present + 1))' "$CHECK_ALL"
marker 'missing=$((missing + 1))' "$CHECK_ALL"
marker 'exit "$fail"' "$CHECK_ALL"

if [ "$ok" -eq 0 ]; then
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-all-selftest.XXXXXX")"
  trap 'rm -rf "$TMP"' EXIT
  mkdir -p "$TMP/scripts" "$TMP/bugs"
  cp "$CHECK_ALL" "$TMP/scripts/check-all.sh"
  cp -R "$ROOT/bugs/." "$TMP/bugs/"
  count=0
  broken=""
  for d in "$TMP"/bugs/*/; do
    count=$((count + 1))
    if [ -z "$broken" ]; then broken="$(basename "$d")"; fi
    printf '#!/bin/bash\nexit 0\n' >"$d/scripts/check.sh"
    chmod +x "$d/scripts/check.sh"
  done
  printf '#!/bin/bash\nexit 1\n' >"$TMP/bugs/$broken/scripts/check.sh"
  chmod +x "$TMP/bugs/$broken/scripts/check.sh"

  out_ok="$TMP/all-ok.out"
  printf '#!/bin/bash\nexit 0\n' >"$TMP/bugs/$broken/scripts/check.sh"
  chmod +x "$TMP/bugs/$broken/scripts/check.sh"
  if "$TMP/scripts/check-all.sh" >"$out_ok" 2>&1; then
    tail -1 "$out_ok" | grep -qxF "TOTAL: $count fixes present, 0 missing" || {
      echo "unexpected all-ok total: $(tail -1 "$out_ok")"
      ok=1
    }
  else
    echo "temp all-ok run exited non-zero"
    ok=1
  fi

  printf '#!/bin/bash\nexit 1\n' >"$TMP/bugs/$broken/scripts/check.sh"
  chmod +x "$TMP/bugs/$broken/scripts/check.sh"
  out_bad="$TMP/one-bad.out"
  if "$TMP/scripts/check-all.sh" >"$out_bad" 2>&1; then
    echo "temp one-bad run exited 0"
    ok=1
  else
    tail -1 "$out_bad" | grep -qxF "TOTAL: $((count - 1)) fixes present, 1 missing" || {
      echo "unexpected one-bad total: $(tail -1 "$out_bad")"
      ok=1
    }
    grep -q "fix MISSING" "$out_bad" || {
      echo "one-bad run did not mark a fix MISSING"
      ok=1
    }
  fi
fi

if [ "$ok" -eq 0 ]; then echo "bug-041 fix PRESENT"; else echo "bug-041 fix MISSING"; fi
exit "$ok"
