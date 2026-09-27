#!/bin/bash
# Run every bug check. Exit 0 only if all fixes are present.
# The final line is the single authoritative total a drill or ledger quotes:
#   TOTAL: <present> fixes present, <missing> missing
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
present=0
missing=0
for d in "$ROOT"/bugs/*/; do
  name="$(basename "$d")"
  if [ -x "$d/scripts/check.sh" ]; then
    if "$d/scripts/check.sh"; then
      echo "[$name] fix PRESENT"
      present=$((present + 1))
    else
      echo "[$name] fix MISSING"
      missing=$((missing + 1))
      fail=1
    fi
  else
    echo "[$name] no check.sh -- SKIPPED"
    missing=$((missing + 1))
    fail=1
  fi
done
echo "TOTAL: $present fixes present, $missing missing"
exit "$fail"
