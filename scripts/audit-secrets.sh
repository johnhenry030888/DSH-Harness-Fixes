#!/bin/sh
# audit-secrets.sh - fail on high-confidence secret shapes in TRACKED files.
# DB URLs with passwords WARN only (the postgres run.sh default is intentional
# and documented; tool output redacts it). Binary/lock/dataset paths skipped.
# Usage: sh scripts/audit-secrets.sh [--staged] (default: all tracked files).
set -eu
# shellcheck disable=SC1007
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"
if [ "${1:-}" = "--staged" ]; then
  FILES=$(git diff --cached --name-only --diff-filter=ACM || true)
else
  FILES=$(git ls-files)
fi
FAIL=0
WARN=0
GREP_P="-E"
if printf "a" | grep -P "a" >/dev/null 2>&1; then GREP_P="-P"; fi
check() {
  desc="$1"
  shift
  hits=$(printf "%s\n" "$FILES" | grep -v -E "\.(lock|png|db|db-wal|db-shm|mp3|wav|m4a)$" | grep -v -E "^(_archive/|.*node_modules/|.*/\.venv/|ui/server/knowledge/)" | xargs grep $GREP_P -l "$1" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    printf "HIT %s:\n%s\n" "$desc" "$hits"
    FAIL=1
  fi
}
warn() {
  desc="$1"
  shift
  hits=$(printf "%s\n" "$FILES" | grep -v -E "\.(lock|png|db|db-wal|db-shm)$" | grep -v -E "^(_archive/|.*node_modules/|.*/\.venv/)" | xargs grep $GREP_P -l "$1" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    printf "WARN %s (allowed, review):\n%s\n" "$desc" "$hits"
    WARN=1
  fi
}
check "github token" "ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"
check "openai/anthropic key" "sk-(ant|proj)-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}"
check "aws key" "AKIA[0-9A-Z]{16}"
check "slack token" "xox[bpas]-[A-Za-z0-9-]{10,}"
check "private key" "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"
check "generic password assignment" "(?i)(password|passwd|secret)\s*[:=]\s*[\"\x27][^\"\x27]{8,}[\"\x27]"
warn "db url with password" "://[^/:@\s]+:[^@\s]+@[^\s]+:[0-9]+/"
if [ "$FAIL" -ne 0 ]; then
  echo "audit-secrets: FAILED"
  exit 1
fi
[ "$WARN" -ne 0 ] && echo "audit-secrets: OK (with warnings above)" || echo "audit-secrets: OK"
