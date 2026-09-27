#!/bin/bash
# Live probe for bug 033 — a delegation deadline the runtime enforces.
#
# It boots the shipped headless profile in a **scratch harness home** (the real
# `~/.dsh` is read, never written; everything lives under `$SCRATCH`, default
# `/tmp/orch-drill-033`) and runs two variants through `dsh --patch`:
#
#   variant A (per call)  — the row config carries boxSeconds 30 and the
#     prompt passes `box_seconds: 15`; the box must hit at 15 s, so the
#     per-call option overrides the row default.
#   variant B (row)       — the row config carries boxSeconds 15 and the prompt
#     passes no box option; the row default must hit at 15 s.
#
# For each variant the probe asserts: the tool result reports the box hit with
# the elapsed seconds and a partial output, the wall clock is ~15 s (not 120),
# and the child's transcript carries a durable `subagent/box` record.
#
# Exit 0 = both variants matched the fix. Requires `dsh` on PATH and a route.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-033}"
HOME_DIR="$SCRATCH/home"
TIMEOUT="${PROBE_TIMEOUT:-300}"
fail=0

command -v dsh >/dev/null 2>&1 || {
  echo "probe: dsh is not on PATH"
  exit 1
}
[ -f "$REAL_HOME/settings.yaml" ] || {
  echo "probe: real harness home $REAL_HOME has no settings.yaml"
  exit 1
}

rm -rf "$SCRATCH"
mkdir -p "$HOME_DIR/sessions" "$HOME_DIR/attachments"
cp "$REAL_HOME/settings.yaml" "$HOME_DIR/settings.yaml"
for link in .credentials.yaml .anonymous-user-id storages profiles; do
  [ -e "$REAL_HOME/$link" ] || continue
  ln -s "$REAL_HOME/$link" "$HOME_DIR/$link"
done

write_patch() {
  cat >"$SCRATCH/box-$1.yml" <<YAML
# Targeted overlay on the headless profile's delegation row (variant: $1).
- id: tool-subagent
  config:
    provider: spawn
    toolName: subagent
    backgroundMode: one-shot
    boxSeconds: $2
YAML
}

run_variant() {
  local name="$1" row_seconds="$2" prompt="$3" expected="$4"
  rm -rf "$HOME_DIR/sessions"
  mkdir -p "$HOME_DIR/sessions"
  write_patch "$name" "$row_seconds"
  echo "variant $name — row boxSeconds=$row_seconds, expected hit at ${expected}s"
  local start_ms end_ms elapsed_ms out rc
  start_ms="$(date +%s%3N)"
  out="$(DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless --patch "$SCRATCH/box-$name.yml" "$prompt" 2>&1)"
  rc=$?
  end_ms="$(date +%s%3N)"
  elapsed_ms=$((end_ms - start_ms))
  printf '%s\n' "$out" | grep -E "hit its|partial output" | head -2 | sed 's/^/    | /'
  if printf '%s' "$out" | grep -q "hit its ${expected} s box and was interrupted after"; then
    echo "  PASS  the tool result reports the ${expected} s box hit"
  else
    echo "  FAIL  no '${expected} s box' report (exit $rc)"
    fail=1
  fi
  if printf '%s' "$out" | grep -q "partial output follows"; then
    echo "  PASS  the result carries the partial-output contract"
  else
    echo "  FAIL  the result omits the partial-output contract"
    fail=1
  fi
  if [ "$elapsed_ms" -ge 14000 ] && [ "$elapsed_ms" -le 90000 ]; then
    echo "  PASS  the call returned in ${elapsed_ms} ms (box, not the 120 s sleep)"
  else
    echo "  FAIL  the call took ${elapsed_ms} ms"
    fail=1
  fi
  if python3 - "$HOME_DIR/sessions" "$expected" <<'PY'; then
import glob, json, os, subprocess, sys
root, expected = sys.argv[1], int(sys.argv[2])
boxes = []
for path in glob.glob(os.path.join(root, "**", "session.v3.jsonl.zstd"), recursive=True):
    text = subprocess.run(["zstd", "-dc", path], capture_output=True).stdout.decode("utf8", "replace")
    for line in text.splitlines():
        try:
            record = json.loads(line)
        except Exception:
            continue
        if record.get("type") == "subagent/box":
            boxes.append(record["data"])
print(f"    subagent/box records: {boxes}")
ok = any(b.get("hit") is True and b.get("boxSeconds") == expected and b.get("elapsedSeconds", 0) >= expected for b in boxes)
sys.exit(0 if ok else 1)
PY
    echo "  PASS  the child transcript carries the durable subagent/box record"
  else
    echo "  FAIL  no matching subagent/box record in the child transcript"
    fail=1
  fi
  echo
}

BASE_PROMPT='Call the subagent tool exactly once. Use description "box probe", prompt "Run the bash command: sleep 120 (pass timeout_ms 120000). Then reply DONE." and run_in_background false.'
run_variant per-call 30 "$BASE_PROMPT Pass box_seconds 15. After the tool returns, repeat its result text verbatim, then reply BOX-PROBE-DONE" 15
run_variant row 15 "$BASE_PROMPT Do NOT pass any box_seconds argument. After the tool returns, repeat its result text verbatim, then reply BOX-PROBE-DONE" 15

if [ "$fail" -eq 0 ]; then
  echo "bug-033 live probe: PASS (both variants)"
else
  echo "bug-033 live probe: FAIL"
fi
echo "scratch home kept for inspection: $SCRATCH"
exit "$fail"
