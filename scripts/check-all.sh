#!/bin/bash
# Run every bug check. Exit 0 only if all fixes are present.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for d in "$ROOT"/bugs/*/; do
  name="$(basename "$d")"
  if [ -x "$d/scripts/check.sh" ]; then
    if "$d/scripts/check.sh"; then
      echo "[$name] fix PRESENT"
    else
      echo "[$name] fix MISSING"
      fail=1
    fi
  else
    echo "[$name] no check.sh -- SKIPPED"
    fail=1
  fi
done
exit "$fail"
