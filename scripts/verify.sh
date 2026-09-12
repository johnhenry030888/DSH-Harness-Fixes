#!/bin/sh
# verify.sh — one-command Zero-Debt Gate for agent loops.
# Loud skips: every skipped gate prints WHY (never silent green).
# Usage: ./scripts/verify.sh [target-dir]  (defaults to current directory)
set -eu
TARGET_DIR="${1:-${PWD}}"
cd "$TARGET_DIR"
FAIL=0
say() { printf '%s\n' "$1"; }
warn() { printf 'warn: %s\n' "$1"; }
fail() {
  printf 'fail: %s\n' "$1"
  FAIL=1
}
has_py=0
has_js=0
if [ -f pyproject.toml ]; then has_py=1; else
  if find . -path ./node_modules -prune -o -path ./.git -prune -o -name '*.py' -print 2>/dev/null | grep -q .; then has_py=1; fi
fi
if [ -f package.json ]; then has_js=1; else
  if find . -path ./node_modules -prune -o -path ./.git -prune -o \( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \) -print 2>/dev/null | grep -q .; then has_js=1; fi
fi
[ -f AGENTS.md ] || fail "AGENTS.md missing"
[ -f README.md ] || fail "README.md missing"
[ -f STATE.md ] || warn "STATE.md missing (long-horizon bookmark)"
[ -f mise.toml ] || warn "mise.toml missing (toolchain not pinned)"
if [ "$has_py" -eq 1 ]; then
  if command -v ruff >/dev/null 2>&1; then
    ruff check . || fail "ruff check failed"
    ruff format --check . || fail "ruff format --check failed"
  else warn "ruff not found — python lint gate skipped"; fi
else say "skip: python lint gate (no .py files)"; fi
if [ "$has_js" -eq 1 ]; then
  if command -v biome >/dev/null 2>&1; then
    biome check . || fail "biome check failed"
  else warn "biome not found — js lint gate skipped"; fi
else say "skip: js lint gate (no JS/TS files)"; fi
if [ -f tsconfig.json ]; then
  if command -v tsc >/dev/null 2>&1; then
    tsc --noEmit || fail "tsc --noEmit failed"
  else warn "tsc not found — type gate skipped"; fi
else say "skip: type gate (no tsconfig.json)"; fi
if [ -f package.json ]; then
  if command -v npm >/dev/null 2>&1; then npm test --if-present --silent || fail "npm test failed"; else warn "npm not found — node gate skipped"; fi
else say "skip: node gate (no package.json)"; fi
if [ -f pyproject.toml ]; then
  if command -v pytest >/dev/null 2>&1; then
    pytest -q || fail "pytest failed"
  elif command -v python3 >/dev/null 2>&1 && [ -f tests/test_smoke.py ]; then
    python3 tests/test_smoke.py || fail "test_smoke.py failed"
  else warn "no python runner — python gate skipped"; fi
else say "skip: python gate (no pyproject.toml)"; fi
if [ -f Cargo.toml ]; then
  if command -v cargo >/dev/null 2>&1; then cargo test --quiet || fail "cargo test failed"; else warn "cargo not found — rust gate skipped"; fi
else say "skip: rust gate (no Cargo.toml)"; fi
if [ -f go.mod ]; then
  if command -v go >/dev/null 2>&1; then go test ./... || fail "go test failed"; else warn "go not found — go gate skipped"; fi
else say "skip: go gate (no go.mod)"; fi
if [ -f scripts/audit-secrets.sh ]; then
  sh scripts/audit-secrets.sh || fail "audit-secrets.sh failed"
else warn "scripts/audit-secrets.sh missing — secret gate skipped"; fi
if [ -d .git ]; then git status --short || fail "git status failed"; else warn "not a git repo"; fi
# --- A-to-Z stage gates (v1.10.0): artifact presence on UI projects ---
is_ui=0
if [ -f .scaffold.json ]; then
  if grep -q '"ui"' .scaffold.json 2>/dev/null || grep -q '"design"' .scaffold.json 2>/dev/null; then is_ui=1; fi
fi
if [ "$is_ui" -eq 0 ]; then
  # Canonical UI-source predicate (identical in scripts/check-tokens.sh - keep in sync).
  if find . \( -name node_modules -o -name .git -o -name .venv -o -name _archive -o -name vendor -o -name dist -o -name build -o -name .ui-artifacts \) -prune -o \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.html' -o -name '*.css' \) -print 2>/dev/null | grep -q .; then is_ui=1; fi
fi
if [ "$is_ui" -eq 0 ]; then
  say "skip: A-to-Z stage gates (non-UI project)"
else
  [ -f docs/stages.md ] || warn "stage framework missing (docs/stages.md)"
  [ -f docs/domain.md ] || warn "Stage 1 incomplete (docs/domain.md missing)"
  [ -f docs/app-map.md ] || warn "Stage 2 incomplete (docs/app-map.md missing)"
  if [ -f docs/app-map.md ]; then
    if [ -f scripts/validate_app_map.py ] && command -v python3 >/dev/null 2>&1; then
      python3 scripts/validate_app_map.py docs/app-map.md || fail "validate_app_map.py failed"
    else warn "app-map validator skipped (scripts/validate_app_map.py or python3 missing)"; fi
  fi
  if [ -f scripts/check-tokens.sh ]; then
    sh scripts/check-tokens.sh || fail "check-tokens.sh failed"
  else warn "scripts/check-tokens.sh missing - token gate skipped"; fi
  [ -f docs/components.md ] || warn "Stage 3 incomplete (docs/components.md missing)"
  has_impl=0
  # Canonical UI-source predicate (identical in scripts/check-tokens.sh - keep in sync).
  if find . \( -name node_modules -o -name .git -o -name .venv -o -name _archive -o -name vendor -o -name dist -o -name build -o -name .ui-artifacts \) -prune -o \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' -o -name '*.html' -o -name '*.css' \) -print 2>/dev/null | grep -q .; then has_impl=1; fi
  if [ "$has_impl" -eq 1 ]; then
    [ -f docs/domain.md ] || fail "Stage 4/5 code exists without Stage 1 baseline (docs/domain.md)"
    [ -f docs/app-map.md ] || fail "Stage 4/5 code exists without Stage 2 baseline (docs/app-map.md)"
    if [ ! -f tokens.json ] && [ ! -f tokens/tokens.json ] && [ ! -f tokens.css ]; then fail "Stage 4/5 code exists without Stage 3 baseline (tokens.json/tokens.css)"; fi
  else
    say "stage gates: baselines checked, no Stage 4/5 impl yet"
  fi
fi
if [ "$FAIL" -ne 0 ]; then
  say "verify: FAILED"
  exit 1
fi
say "verify: OK"
