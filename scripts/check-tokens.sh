#!/bin/sh
# check-tokens.sh - element-first token gate (Stage 3, v1.10.0).
# Asserts motion durations/easings exist in tokens.json, scans sources for
# raw hex colors outside tokens, and confirms prefers-reduced-motion
# fallbacks accompany animations. Loud skips, never silent green.
# Usage: sh scripts/check-tokens.sh [target-dir] (defaults to PWD)
set -eu
TARGET_DIR="${1:-${PWD}}"
cd "$TARGET_DIR"
FAIL=0
warn() { printf 'warn: %s\n' "$1"; }
fail() {
  printf 'fail: %s\n' "$1"
  FAIL=1
}
say() { printf '%s\n' "$1"; }
TOKENS=""
if [ -f tokens.json ]; then
  TOKENS="tokens.json"
elif [ -f tokens/tokens.json ]; then
  TOKENS="tokens/tokens.json"
fi
HAS_SRC=0
# Canonical UI-source predicate (identical in scripts/verify.sh - keep in sync):
# marker features ui/design, or tsx/jsx/ts/html/css sources outside vendored dirs.
if find . \( -name node_modules -o -name .git -o -name .venv -o -name _archive -o -name vendor -o -name dist -o -name build -o -name .ui-artifacts \) -prune -o \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.html' -o -name '*.css' \) -print 2>/dev/null | grep -q .; then HAS_SRC=1; fi
if [ -z "$TOKENS" ]; then
  if [ "$HAS_SRC" -eq 1 ]; then
    warn "token gate: UI sources exist but no tokens.json (Stage 3 incomplete)"
  else say "skip: token gate (no tokens.json, no UI sources)"; fi
  exit 0
fi
say "token gate: $TOKENS"
for key in fast normal slow; do
  if grep -q "\"$key\"" "$TOKENS" 2>/dev/null; then :; else fail "tokens.json missing motion duration \"$key\""; fi
done
if grep -Eq "cubic-bezier|spring\(" "$TOKENS" 2>/dev/null; then :; else fail "tokens.json missing motion easings (cubic-bezier/spring)"; fi
HEX_HITS=""
HEX_HITS=$(grep -rInE --include='*.css' --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.html' --exclude='tokens.json' --exclude='tokens.css' --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv --exclude-dir=_archive --exclude-dir=.ui-artifacts --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build -E '#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b' . 2>/dev/null || true)
if [ -n "$HEX_HITS" ]; then
  printf '%s\n' "$HEX_HITS" | head -n 20 | sed 's/^/  raw-hex: /'
  fail "raw hex colors outside tokens.json/tokens.css (move them into tokens)"
else say "token gate: no raw hex outside tokens"; fi
ANIM=0
if grep -rInE --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv --exclude-dir=_archive --exclude-dir=.ui-artifacts --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build -E 'transition|animation|@keyframes|framer-motion|view-transition-name' --include='*.css' --include='*.tsx' --include='*.jsx' --include='*.ts' . 2>/dev/null | grep -q .; then ANIM=1; fi
if [ "$ANIM" -eq 1 ]; then
  if grep -rIn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv --exclude-dir=_archive --exclude-dir=.ui-artifacts --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build 'prefers-reduced-motion' --include='*.css' --include='*.tsx' --include='*.jsx' --include='*.ts' . 2>/dev/null | grep -q .; then
    say "token gate: prefers-reduced-motion fallback present"
  else warn "token gate: animations exist without prefers-reduced-motion fallback"; fi
else say "skip: reduced-motion check (no animations)"; fi
if [ "$FAIL" -ne 0 ]; then
  say "check-tokens: FAILED"
  exit 1
fi
say "check-tokens: OK"
