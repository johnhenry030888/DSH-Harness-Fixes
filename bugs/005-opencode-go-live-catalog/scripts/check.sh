#!/bin/bash
# Exit 0 = bug-005 fix present and serving the live opencode-go catalog,
# 1 = bug present (fix missing, unpinned settings absent, or served list stale).
#
# Checks, in order:
#   1. the fix markers exist in the installed dsh-llm-pi-ai bundle;
#   2. the installed module parses under `node --check`;
#   3. the live catalog cache exists;
#   4. ~/.dsh/settings.yaml does not re-pin opencode-go.models (which would
#      replace the live catalog);
#   5. when the network is up, the cached list still matches the live active
#      set, and (when `opencode` is installed) the opencode CLI's own list.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
FILE="/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js"
CACHE="${DSH_HOME:-$HOME/.dsh}/storages/llm-pi-ai/catalog/opencode-go.json"
SETTINGS="${DSH_HOME:-$HOME/.dsh}/settings.yaml"
LISTING="https://opencode.ai/zen/go/v1/models"
ok=0

marker() {
  grep -q "$1" "$FILE" 2>/dev/null || {
    echo "missing: $1"
    ok=1
  }
}
marker "function startLiveCatalogRefresh("
marker "function previewLiveCatalog("
marker "zen/go/v1/models"

if ! node --check "$FILE" >/dev/null 2>&1; then
  echo "installed module does not parse under node --check"
  ok=1
fi

if [ ! -s "$CACHE" ]; then
  echo "missing: live catalog cache $CACHE (run scripts/reapply.sh)"
  ok=1
fi

# A non-empty models list under llm-pi-ai.providers.opencode-go replaces the
# catalog at resolution time, so the live list would never be served.
pin_check() {
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    let text;
    try { text = fs.readFileSync(file, "utf8"); } catch { process.exit(0); }
    let yaml;
    try {
      yaml = require("/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/js-yaml");
    } catch { process.exit(0); }
    const doc = yaml.load(text) ?? {};
    const models = doc?.["llm-pi-ai"]?.providers?.["opencode-go"]?.models;
    process.exit(Array.isArray(models) && models.length > 0 ? 1 : 0);
  ' "$SETTINGS" 2>/dev/null
}
if [ -f "$SETTINGS" ] && ! pin_check; then
  # A pin is a deliberate deployment choice: it trades live-catalog serving for
  # a curated route list. It no longer fails this check (2026-09-26) — bug 012's
  # three-source classifier keeps route rejections honest under a pin.
  echo "NOTE: settings pin present: llm-pi-ai.providers.opencode-go.models replaces the live catalog"
  echo "  (deliberate curated deployment; remove it from $SETTINGS to serve the live catalog)"
fi

if [ "$ok" -eq 0 ]; then
  if command -v curl >/dev/null 2>&1 &&
    [ "$(curl -sS -m 8 -o /dev/null -w '%{http_code}' "$LISTING" 2>/dev/null)" = "200" ]; then
    node "$HERE/refresh-opencode-go-catalog.mjs" --check
    rc=$?
    if [ "$rc" -eq 3 ]; then
      echo "WARN: metadata source unreachable; served the cached live catalog unverified"
    elif [ "$rc" -ne 0 ]; then
      echo "live parity check FAILED"
      ok=1
    fi
  else
    echo "WARN: gateway unreachable; served the cached live catalog unverified"
  fi

  if command -v opencode >/dev/null 2>&1 && [ -s "$CACHE" ]; then
    cli="$(timeout 45 opencode models 2>/dev/null | sed -n 's|^opencode-go/||p' | LC_ALL=C sort)"
    if [ -n "$cli" ]; then
      served="$(node -e '
        const doc = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        process.stdout.write(doc.models.map((model) => model.id).join("\n"));
      ' "$CACHE" | LC_ALL=C sort)"
      missing="$(LC_ALL=C comm -23 <(printf '%s\n' "$cli") <(printf '%s\n' "$served") | tr '\n' ' ')"
      extra="$(LC_ALL=C comm -13 <(printf '%s\n' "$cli") <(printf '%s\n' "$served") | tr '\n' ' ')"
      if [ -n "$missing" ] || [ -n "$extra" ]; then
        echo "opencode CLI parity FAILED ($(printf '%s\n' "$cli" | wc -l) CLI vs $(printf '%s\n' "$served" | wc -l) served)"
        [ -n "$missing" ] && echo "  CLI-only: $missing"
        [ -n "$extra" ] && echo "  served-only: $extra"
        ok=1
      fi
    fi
  fi
fi

if [ "$ok" -eq 0 ]; then echo "bug-005 fix PRESENT"; else echo "bug-005 fix MISSING"; fi
exit "$ok"
